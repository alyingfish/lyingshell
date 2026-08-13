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
Singleton {
    id: root

    // ---- lifecycle -------------------------------------------------------

    // Drives WlSessionLock.locked. Nothing else may write it.
    property bool locked: false
    // Mirrored from WlSessionLock: the compositor has confirmed every output
    // is covered. Only then is the session actually secure.
    property bool secure: false

    // Which sweep the windows in Modules/Lock/LockScreen.qml are raised for:
    //
    //   ""       no sweep windows exist.
    //   "enter"  the entry sweep: a live copy of the scene over the desktop,
    //            with the circle shrinking into the avatar's spot.
    //   "exit"   the unlock sweep: a still of the hello pose, pre-buffered
    //            while the lock is still up, with the circle growing back.
    //
    // RENDERING SAFETY: while the session is locked the compositor draws only
    // the lock surfaces, and a surface it does not draw receives no frame
    // callbacks. A window forced to render in that state stalls its render
    // thread on buffers the compositor will never release, and the stall can
    // wedge the whole shell — which is exactly how the old unlock sweep froze
    // the lock screen. So nothing here may require a sweep window to render
    // while `locked` is true. The one exception is the exit window's very
    // first frame: a freshly created window's swapchain can always produce
    // one frame without waiting on the compositor, which is what lets the
    // cover be buffered under the lock before it drops. Every state advance
    // below is bounded by a timer; the windows' first-frame reports only ever
    // end a wait early, so rendering is never load-bearing.
    property string sweepMode: ""
    readonly property bool sweepActive: sweepMode !== ""

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
    // prototype's own curve and duration; the radius each surface draws is
    // this times its own overshooting full radius.
    property real deskHole: 1

    readonly property bool reducedMotion: Settings.options.appearance.reducedMotion
    readonly property int sweepDuration: reducedMotion ? 0 : LockMotion.sweepMs
    // The avatar's success step still plays under reduced motion: it is a
    // morph in place, not travel, and it is the only thing that says the
    // password landed.
    readonly property int successHoldDuration: LockMotion.successHoldMs

    Behavior on deskHole {
        enabled: !root.reducedMotion

        NumberAnimation {
            duration: LockMotion.sweepMs
            easing.type: Easing.Bezier
            easing.bezierCurve: LockMotion.sweepCurve
        }
    }

    // ---- entry / exit ----------------------------------------------------

    function lock() {
        if (locked || sweepActive) {
            return;
        }
        reset();
        LockTheme.active = true;
        // The scene the circle uncovers is already at rest: nothing in front
        // of or behind the circle animates on its own.
        deskHole = 1;
        if (reducedMotion) {
            takeLock();
            return;
        }
        sweepArmed = false;
        sweepSurfaceGoal = Quickshell.screens.length;
        sweepFramesPainted = 0;
        sweepMode = "enter";
        // The circle starts shrinking once every window has put up its first
        // frame, so no travel lands on an unmapped surface; the cap keeps a
        // slow map from stalling the entry.
        sweepArmTimer.restart();
    }

    // Set once the entry circle is moving, so a late first-frame report and
    // the cap firing after it cannot start the shrink twice.
    property bool sweepArmed: false

    function armEnterSweep() {
        if (sweepMode !== "enter" || sweepArmed) {
            return;
        }
        sweepArmed = true;
        sweepArmTimer.stop();
        deskHole = 0;
        lockLandTimer.restart();
    }

    function takeLock() {
        deskHole = 0;
        locked = true;
        // The sweep windows stay mapped until the compositor confirms every
        // output is locked (`secure`), as insurance across compositor
        // timings — niri actually stops drawing overlays the moment the lock
        // request lands, and fills the gap to the lock surface's first commit
        // with its own lock colour. They park the instant `locked` goes up
        // (updatesEnabled), so keeping them renders nothing and costs
        // nothing.
        secureFallback.restart();
    }

    onSecureChanged: if (secure && locked) {
        secureFallback.stop();
        endEnterSweep();
    }

    // If `secure` never lands the parked windows would sit mapped forever.
    // The lock itself is unaffected either way.
    Timer {
        id: secureFallback
        interval: 1000
        onTriggered: root.endEnterSweep()
    }

    function endEnterSweep() {
        if (sweepMode === "enter") {
            sweepMode = "";
        }
    }

    Timer {
        id: sweepArmTimer
        interval: LockMotion.sweepHandoffMs
        onTriggered: root.armEnterSweep()
    }

    Timer {
        id: lockLandTimer
        interval: root.sweepDuration
        onTriggered: root.takeLock()
    }

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
        // A stale entry sweep can only exist here if `secure` never landed;
        // its windows hold the wrong scene, so drop them before the exit pair
        // is raised.
        if (sweepMode === "enter") {
            sweepMode = "";
        }
        sweepSnapshots = {};
        sweepSurfaceGoal = Quickshell.screens.length;
        sweepFramesPainted = 0;
        if (sweepSurfaceGoal === 0) {
            beginExitSweep();
            return;
        }
        // Each lock surface grabs its frozen pose into an image — one
        // offscreen render of a surface the compositor is actively drawing,
        // so it cannot stall — and the exit windows hold that still under the
        // growing circle. The bail timer keeps a lost grab from ever gating
        // the unlock.
        snapshotBail.restart();
        sweepSnapshotWanted();
    }

    // The frozen hello pose, one grab per output, keyed by screen name. The
    // grab results are QObjects; holding them here is what keeps the images
    // alive until the sweep lands.
    signal sweepSnapshotWanted()
    property var sweepSnapshots: ({})
    // One goal serves both waits — snapshots wanted and first frames
    // reported — because both are one-per-output.
    property int sweepSurfaceGoal: 0
    property int sweepFramesPainted: 0

    function deliverSweepSnapshot(name, grab) {
        if (phase !== root.phaseHello || sweepMode === "exit") {
            return;
        }
        var held = {};
        for (var key in sweepSnapshots) {
            held[key] = sweepSnapshots[key];
        }
        held[name] = grab;
        sweepSnapshots = held;
        if (Object.keys(held).length >= sweepSurfaceGoal) {
            beginExitSweep();
        }
    }

    Timer {
        id: snapshotBail
        interval: LockMotion.snapshotBailMs
        onTriggered: root.beginExitSweep()
    }

    function beginExitSweep() {
        if (phase !== root.phaseHello || sweepMode === "exit") {
            return;
        }
        snapshotBail.stop();
        sweepMode = "exit";
        unlockHandoff.restart();
    }

    // Called by each sweep window on its first presented frame. Entry: every
    // output's cover is mapped, so the circle can start shrinking with no
    // travel lost on an unmapped surface. Exit: every cover is committed on
    // the compositor's side, buffered below the lock surface, so the lock can
    // drop and the covers are what the compositor reveals in its place — one
    // Wayland connection, so the commits are ordered before the release
    // request.
    function sweepSurfacePainted() {
        sweepFramesPainted++;
        if (sweepFramesPainted < sweepSurfaceGoal) {
            return;
        }
        if (sweepMode === "enter") {
            armEnterSweep();
        } else if (sweepMode === "exit") {
            releaseAndOpen();
        }
    }

    // The upper bound on the exit wait. Rendering is decoration: if no cover
    // ever reports, the unlock proceeds as a plain cut.
    Timer {
        id: unlockHandoff
        interval: LockMotion.sweepHandoffMs
        onTriggered: root.releaseAndOpen()
    }

    function releaseAndOpen() {
        if (sweepMode !== "exit" || !locked) {
            return;
        }
        unlockHandoff.stop();
        releaseLock();
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
        sweepMode = "";
        sweepSnapshots = {};
        sweepSurfaceGoal = 0;
        sweepFramesPainted = 0;
        deskHole = 1;
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
