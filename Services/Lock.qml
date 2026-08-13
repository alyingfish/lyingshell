pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.Commons.Settings
import qs.Commons.Theme

import "../Modules/Lock/LockMotion.js" as LockMotion

// The lock screen's state, for the whole session.
//
// One state machine (the prototype's stage/auth.js) shared by every output's
// surface: the surfaces are a view, this is the model. Four states on `phase`:
//
//   glance   wallpaper, two-tone clock, glance line. The photo is shown as
//            shot — no scrim, no gradient, no shadow on the ink.
//   ask      the clock shrinks to a crown, the identity column rises, the
//            blur and the scrim fade in.
//   pending  the controls go dead and the unlock arrow becomes the loading
//            indicator while PAM works.
//   hello    the success pose is held still while the sweep runs.
//
// `succeeded` is deliberately NOT a phase: the room stays in `pending` while
// the avatar alone plays its success step, and only then enters `hello`, which
// is the exit itself.
//
// SAFETY: `locked` is what drives WlSessionLock. It must never go false before
// PAM has reported Success, and the shell must not die while it is true — a
// conformant compositor leaves the session locked and inoperable if it does.
//
// RENDERING SAFETY: while the session is locked, niri draws nothing but the
// lock surfaces and sends per-frame callbacks only to them; every other
// window falls back to a ~1Hz fallback timer (Niri::send_frame_callbacks and
// send_frame_callbacks_on_fallback_timer). A window that needs per-frame
// updates then stalls its render thread on buffers the compositor will not
// release promptly, and the stall can wedge the whole shell — which is
// exactly how the old unlock sweep froze the lock screen. So nothing here
// may require an undrawn window to render while `locked` is true: the entry
// circle animates on the lock surfaces themselves — the one kind of window
// the locked compositor draws — and the captures finish before the lock is
// requested, inside bar windows that park while locked. The one exception is
// the exit cover's very first frame: a new layer surface created while
// locked is still configured and mapped by niri (it is merely never drawn),
// and a fresh window's swapchain can always produce that one frame without
// waiting on the compositor — which is what lets the covers be buffered
// under the lock before it drops. Every wait below is bounded by a timer;
// paint and still deliveries only ever end a wait early or hold a bounded
// gate, so a rendering failure degrades the gesture, never the lock.
Singleton {
    id: root

    // ---- lifecycle -------------------------------------------------------

    // Drives WlSessionLock.locked. Nothing else may write it.
    property bool locked: false
    // Mirrored from WlSessionLock: the compositor has confirmed every output
    // is covered. niri sends it only after each output has PRESENTED a
    // locked frame, so it doubles as "my first frames are on screen".
    property bool secure: false

    // The entry pipeline, one stage at a time:
    //
    //   ""         idle; no captures run.
    //   "capture"  pre-lock: each output's bar window grabs one frozen
    //              wlr-screencopy frame of its desktop offscreen
    //              (Modules/Lock/LockStillCapture.qml — no windows are
    //              raised). The bar's own overlays (quick-settings panel,
    //              tray popover) cut shut on this stage, and each capture
    //              waits one committed host frame so the copy can never
    //              carry the panel. The sweep CLOCK is already running: the
    //              lead-in timer covers the ~102ms the prototype's curve
    //              spends beyond the screen corners, so the pipeline hides
    //              inside travel nobody could see anyway.
    //   "arming"   the lock is requested (the moment every output answered,
    //              or captureBail fired). Waiting on the gates: `secure`,
    //              the lead-in, and every delivered still's first painted
    //              frame — all bounded by entryBail.
    //   "sweep"    the circle shrinks into the avatar's spot, on the lock
    //              surfaces themselves. deskHole snaps (invisibly — the
    //              hold point still covers every corner) to where the
    //              prototype's curve would be and replays its exact tail.
    property string entryStage: ""

    // The exit pipeline:
    //
    //   ""          idle; no exit windows exist.
    //   "snapshot"  each lock surface grabs its frozen hello pose into an
    //               image — one offscreen render of a surface the compositor
    //               is actively drawing, so it cannot stall.
    //   "cover"     fresh Overlay windows hold those stills at full cover
    //               and buffer them UNDER the lock: their first frames
    //               commit on the same Wayland connection that will carry
    //               the release, so the compositor swaps the lock surface
    //               for the covers with no gap. The release is gated on
    //               every cover's first presented frame — bounded by
    //               coverBail, whose bail tears the covers down and cuts.
    //   "open"      the lock is released and the circle grows over the live
    //               desktop; the covers are dropped when it lands.
    property string exitStage: ""

    readonly property bool sweepActive: entryStage !== "" || exitStage !== ""

    // ---- the state machine -----------------------------------------------

    readonly property string phaseGlance: "glance"
    readonly property string phaseAsk: "ask"
    readonly property string phasePending: "pending"
    readonly property string phaseHello: "hello"

    property string phase: root.phaseGlance
    // The avatar's own success step: the scallop morphs to a circle, the
    // turning stops, the check pops in. 520ms before the sweep.
    property bool succeeded: false

    // Whose session this guards. The lock already knows — picking an account
    // is the greeter's job, and the greeter is out of scope.
    readonly property string userName: String(Quickshell.env("USER") || "")
    readonly property string displayName: {
        var configured = Settings.options.lock.fullName;
        return configured && configured.length > 0 ? configured : root.userName;
    }
    // GNOME stores the selected portrait in AccountsService. Keep the path in
    // the session model so every lock surface shares one lookup and one value.
    // An empty result is intentional: LockAvatar then keeps its tonal initial.
    property string accountAvatar: ""

    function busctlData(output) {
        try {
            var data = JSON.parse(output).data;
            return Array.isArray(data) ? String(data[0] || "") : String(data || "");
        } catch (error) {
            return "";
        }
    }

    Process {
        id: accountLookup

        running: root.userName.length > 0
        command: ["busctl", "--system", "--no-pager", "--json=short", "call",
            "org.freedesktop.Accounts", "/org/freedesktop/Accounts",
            "org.freedesktop.Accounts", "FindUserByName", "s", root.userName]
        stdout: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                return;
            }
            var accountPath = root.busctlData(stdout.text);
            if (!accountPath.startsWith("/org/freedesktop/Accounts/User")) {
                return;
            }
            avatarLookup.command = ["busctl", "--system", "--no-pager", "--json=short", "get-property",
                "org.freedesktop.Accounts", accountPath,
                "org.freedesktop.Accounts.User", "IconFile"];
            avatarLookup.running = true;
        }
    }

    Process {
        id: avatarLookup

        stdout: StdioCollector {}

        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                root.accountAvatar = root.busctlData(stdout.text);
            }
        }
    }

    property string password: ""
    property bool capsLock: false
    // The refusal is a state of the field, not only a colour on it.
    property bool refused: false
    property bool reveal: false

    // Bumped on every refusal so the field and the avatar can replay their
    // shake even when two wrong attempts land in a row.
    property int shakeGeneration: 0

    // ---- the desktop circle ----------------------------------------------
    // 1 = the desktop owns the whole screen, 0 = the lock scene does. The
    // radius each surface draws is this times its own overshooting full
    // radius. One Behavior animates every move; each phase of the gesture
    // sets the duration and curve it needs before writing the target, and
    // snapDeskHole() jumps without animating (only ever to a value that
    // covers every screen the same as the one it replaces, so a snap can
    // never show).
    property real deskHole: 1

    property int sweepPhaseMs: LockMotion.sweepMs
    property var sweepPhaseCurve: LockMotion.sweepCurve
    property bool deskHoleSnap: false

    readonly property bool reducedMotion: Settings.options.appearance.reducedMotion
    readonly property int sweepDuration: reducedMotion ? 0 : LockMotion.sweepMs
    readonly property int entryTailDuration: reducedMotion ? 0 : LockMotion.entryTailMs
    // The avatar's success step still plays under reduced motion: it is a
    // morph in place, not travel, and it is the only thing that says the
    // password landed.
    readonly property int successHoldDuration: LockMotion.successHoldMs

    Behavior on deskHole {
        enabled: !root.reducedMotion && !root.deskHoleSnap

        NumberAnimation {
            duration: root.sweepPhaseMs
            easing.type: Easing.Bezier
            easing.bezierCurve: root.sweepPhaseCurve
        }
    }

    function snapDeskHole(value) {
        deskHoleSnap = true;
        deskHole = value;
        deskHoleSnap = false;
    }

    // ---- entry -------------------------------------------------------------

    function lock() {
        // A tap that lands while the unlock circle is still opening is a
        // re-lock, not a lost tap: cut the tail of the exit and start over.
        if (!locked && exitStage === "open") {
            finishUnlock();
        }
        if (locked || sweepActive) {
            return;
        }
        reset();
        LockTheme.active = true;
        if (reducedMotion || Quickshell.screens.length === 0) {
            snapDeskHole(0);
            takeLock();
            return;
        }
        // The scene the circle uncovers is already at rest: nothing in front
        // of or behind the circle animates on its own.
        snapDeskHole(1);
        desktopStills = {};
        entryStillsDelivered = 0;
        entryStillsPainted = 0;
        leadInElapsed = false;
        entryStage = "capture";
        // The sweep clock starts NOW: the lead-in is the part of the curve
        // the viewer cannot see, and the capture pipeline runs inside it.
        leadIn.restart();
        // The lock is requested the moment every output has delivered its
        // still; the cap keeps a lost capture from ever delaying it.
        captureBail.restart();
    }

    Timer {
        id: leadIn
        interval: LockMotion.entryLeadInMs
        onTriggered: {
            root.leadInElapsed = true;
            root.tryEntrySweep();
        }
    }

    property bool leadInElapsed: false

    // The frozen desktop, one grab per output, keyed by screen name — what
    // the entry circle shows shrinking over the scene. Captured BEFORE the
    // lock is requested: a screencopy taken while locked captures the lock
    // screen, not the desktop. The grab results are QObjects; holding them
    // here is what keeps the images alive until the circle lands. Failed
    // grabs are counted but never stored: their outputs degrade to a plain
    // cut and must not hold the painted gate.
    property var desktopStills: ({})
    property int entryStillsDelivered: 0
    property int entryStillsPainted: 0

    function deliverDesktopStill(name, grab) {
        // Late deliveries — after the bail, after the lock — change nothing.
        if (entryStage !== "capture" || locked) {
            return;
        }
        entryStillsDelivered++;
        if (grab !== null) {
            var held = {};
            for (var key in desktopStills) {
                held[key] = desktopStills[key];
            }
            held[name] = grab;
            desktopStills = held;
        }
        if (entryStillsDelivered >= Quickshell.screens.length) {
            takeLock();
        }
    }

    Timer {
        id: captureBail
        interval: LockMotion.captureBailMs
        onTriggered: root.takeLock()
    }

    function takeLock() {
        if (locked) {
            return;
        }
        captureBail.stop();
        // The desktop's windows (bar, wallpaper) park the moment `locked`
        // goes up. The reduced-motion path never staged an entry and needs
        // no gates; the sweep path arms them, bounded by entryBail.
        if (entryStage === "capture") {
            entryStage = "arming";
            entryBail.restart();
        }
        locked = true;
    }

    // ---- the arming gates. The sweep begins when ALL of them pass:
    //   secure               the compositor confirmed coverage, which on niri
    //                        means every output PRESENTED a locked frame;
    //   leadInElapsed        the prototype's own off-screen travel is spent;
    //   stills painted       every output holding a still reported the frame
    //                        that actually carries it, so the circle never
    //                        moves over a cover that has not drawn.
    // entryBail bounds the whole stage: a gate that never passes costs one
    // bounded wait, then the sweep runs over whatever is actually up.

    onSecureChanged: if (secure && locked) {
        tryEntrySweep();
    }

    // Called by each lock surface's entry cover on its first presented frame.
    function entryStillPainted() {
        entryStillsPainted++;
        tryEntrySweep();
    }

    function tryEntrySweep() {
        if (entryStage !== "arming" || !secure || !leadInElapsed) {
            return;
        }
        if (entryStillsPainted < Object.keys(desktopStills).length) {
            return;
        }
        beginEntrySweep();
    }

    Timer {
        id: entryBail
        interval: LockMotion.entryBailMs
        onTriggered: root.beginEntrySweep()
    }

    // Retire the gates and let the circle shrink into the avatar's spot — on
    // the lock surfaces themselves, the one kind of window the locked
    // compositor draws. The snap to the hold point cannot show: both 1 and
    // the hold point cover every screen corner whole.
    function beginEntrySweep() {
        if (entryStage !== "arming") {
            return;
        }
        entryBail.stop();
        entryStage = "sweep";
        snapDeskHole(LockMotion.entryHoldPoint);
        sweepPhaseMs = LockMotion.entryTailMs;
        sweepPhaseCurve = LockMotion.entryTailCurve;
        deskHole = 0;
        entryLandTimer.restart();
    }

    Timer {
        id: entryLandTimer
        interval: root.entryTailDuration
        onTriggered: root.finishEntry()
    }

    function finishEntry() {
        leadIn.stop();
        captureBail.stop();
        entryBail.stop();
        entryLandTimer.stop();
        entryStage = "";
        desktopStills = {};
        entryStillsDelivered = 0;
        entryStillsPainted = 0;
        leadInElapsed = false;
        sweepPhaseMs = LockMotion.sweepMs;
        sweepPhaseCurve = LockMotion.sweepCurve;
    }

    // ---- exit --------------------------------------------------------------

    // PAM said yes. The avatar goes first, alone.
    function beginUnlock() {
        if (phase !== root.phasePending) {
            return;
        }
        refused = false;
        succeeded = true;
        successHold.restart();
    }

    Timer {
        id: successHold
        interval: root.successHoldDuration
        onTriggered: root.runUnlockSweep()
    }

    function runUnlockSweep() {
        // hello is the exit itself: the room holds its approach pose while the
        // circle opens the desktop over it.
        phase = root.phaseHello;
        if (reducedMotion) {
            releaseLock();
            finishUnlock();
            return;
        }
        // A stale entry can only exist here if a gate never passed; drop its
        // stage — and the desktop stills — before the exit pair is raised.
        finishEntry();
        sweepSnapshots = {};
        exitSnapshotsDelivered = 0;
        coverFramesPainted = 0;
        if (Quickshell.screens.length === 0) {
            exitStage = "cover";
            releaseAndOpen();
            return;
        }
        exitStage = "snapshot";
        // Each lock surface grabs its frozen pose into an image — one
        // offscreen render of a surface the compositor is actively drawing,
        // so it cannot stall — and the exit covers hold that still under the
        // growing circle. The bail keeps a lost grab from gating the unlock.
        snapshotBail.restart();
        sweepSnapshotWanted();
    }

    // The frozen hello pose, one grab per output, keyed by screen name. The
    // grab results are QObjects; holding them here is what keeps the images
    // alive until the sweep lands. Failed grabs are counted, never stored:
    // their covers raise empty and their outputs degrade to a plain cut.
    signal sweepSnapshotWanted()
    property var sweepSnapshots: ({})
    property int exitSnapshotsDelivered: 0
    property int coverFramesPainted: 0

    function deliverSweepSnapshot(name, grab) {
        if (phase !== root.phaseHello || exitStage !== "snapshot") {
            return;
        }
        exitSnapshotsDelivered++;
        if (grab !== null) {
            var held = {};
            for (var key in sweepSnapshots) {
                held[key] = sweepSnapshots[key];
            }
            held[name] = grab;
            sweepSnapshots = held;
        }
        if (exitSnapshotsDelivered >= Quickshell.screens.length) {
            beginExitCovers();
        }
    }

    Timer {
        id: snapshotBail
        interval: LockMotion.snapshotBailMs
        onTriggered: root.beginExitCovers()
    }

    // Raise one cover per output (LockScreen.qml's Variants keys on "cover")
    // and start the paint gate: the release follows the covers, not a clock.
    function beginExitCovers() {
        if (phase !== root.phaseHello || exitStage !== "snapshot") {
            return;
        }
        snapshotBail.stop();
        exitStage = "cover";
        coverBail.restart();
    }

    // Called by each exit cover on its first presented frame: the cover is
    // committed on the compositor's side, buffered below the lock surface.
    // Once every output has one, the lock can drop and the covers are what
    // the compositor reveals in its place — one Wayland connection, so the
    // commits are ordered before the release request.
    function sweepSurfacePainted() {
        coverFramesPainted++;
        if (exitStage === "cover" && coverFramesPainted >= Quickshell.screens.length) {
            releaseAndOpen();
        }
    }

    // The safety net, not the schedule: it fires only when a cover could not
    // produce a first frame at all. Tearing the covers down BEFORE the
    // release is what makes the failure a clean cut — a cover left up would
    // map late and flash the lock scene over the live desktop.
    Timer {
        id: coverBail
        interval: LockMotion.coverBailMs
        onTriggered: root.abortExitCovers()
    }

    function abortExitCovers() {
        if (exitStage !== "cover") {
            return;
        }
        console.warn("[Lock] exit covers missed their deadline; unlocking with a cut");
        exitStage = "";
        releaseLock();
        finishUnlock();
    }

    function releaseAndOpen() {
        if (exitStage !== "cover" || !locked) {
            return;
        }
        coverBail.stop();
        exitStage = "open";
        releaseLock();
        sweepPhaseMs = LockMotion.sweepMs;
        sweepPhaseCurve = LockMotion.sweepCurve;
        deskHole = 1;
        unlockLandTimer.restart();
    }

    Timer {
        id: unlockLandTimer
        interval: root.sweepDuration
        onTriggered: root.finishUnlock()
    }

    function releaseLock() {
        locked = false;
    }

    function finishUnlock() {
        snapshotBail.stop();
        coverBail.stop();
        unlockLandTimer.stop();
        exitStage = "";
        sweepSnapshots = {};
        exitSnapshotsDelivered = 0;
        coverFramesPainted = 0;
        desktopStills = {};
        snapDeskHole(1);
        reset();
        // The desktop's own seed comes back only now: the scene the circle
        // sweeps over has to stay frozen, and re-tinting it mid-sweep is the
        // one thing `hello` forbids.
        LockTheme.active = false;
    }

    function reset() {
        phase = root.phaseGlance;
        succeeded = false;
        password = "";
        refused = false;
        reveal = false;
        // Abort only a session that is actually running: PAM warns on a
        // stray abort, and reset() is called on every return to glance.
        if (pam.active) {
            pam.abort();
        }
    }

    // ---- approach --------------------------------------------------------

    function wake(seed) {
        if (phase !== root.phaseGlance) {
            return;
        }
        // Take the character and move focus in the same event, never on a
        // timer: delaying either one loses the keys that follow it.
        password = seed || "";
        refused = false;
        phase = root.phaseAsk;
    }

    // Escape unwinds one layer at a time. The panel's own layers go first —
    // the surface asks it before us — so by the time this runs the prompt is
    // the outermost thing left.
    function back() {
        if (phase !== root.phaseAsk) {
            return false;
        }
        reset();
        return true;
    }

    function setPassword(value) {
        password = value;
        if (refused) {
            refused = false;
        }
    }

    // ---- authentication --------------------------------------------------

    // Point at a service under /etc/pam.d by setting lock.pamConfig; the
    // shipped default is self-contained (assets/pam.d/lyingshell), so a stock
    // machine needs no root-owned file to unlock.
    readonly property string configuredPam: Settings.options.lock.pamConfig
    readonly property bool usingSystemPam: configuredPam.length > 0

    property string authError: ""

    function submit() {
        if (phase !== root.phaseAsk) {
            return;
        }
        phase = root.phasePending;
        authError = "";
        if (!pam.start()) {
            failed("start");
        }
    }

    function failed(reason) {
        // A refusal returns from pending without moving the field.
        phase = root.phaseAsk;
        succeeded = false;
        refused = true;
        authError = reason || "";
        shakeGeneration++;
    }

    PamContext {
        id: pam

        config: root.usingSystemPam ? root.configuredPam : "lyingshell"
        configDirectory: root.usingSystemPam ? "/etc/pam.d" : Quickshell.shellDir + "/assets/pam.d"

        onResponseRequiredChanged: {
            if (!responseRequired) {
                return;
            }
            respond(root.password);
        }

        onCompleted: function (result) {
            if (result === PamResult.Success) {
                root.beginUnlock();
                return;
            }
            root.failed(PamResult.toString(result));
        }

        onError: function (err) {
            console.warn("[Lock] pam error:", PamError.toString(err));
        }
    }

    // `qs ipc call lock lock` — the niri bind and any script use this; the
    // quick-settings power menu calls Session.lock(), which routes here too.
    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.locked;
        }

        function state(): string {
            return root.locked ? root.phase : "unlocked";
        }
    }
}
