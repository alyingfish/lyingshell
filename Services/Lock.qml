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

    // The sweep windows exist (see Modules/Lock/LockScreen.qml). They are
    // raised before the lock is taken and dropped after it is released, so
    // both halves of the sweep have a surface to run on.
    property bool sweepActive: false
    // Whether those windows paint the scene. Off while the real lock surfaces
    // own the screen, so the scene is never built twice at once.
    property bool sweepPainting: false

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
        sweepActive = true;
        sweepPainting = true;
        if (reducedMotion) {
            takeLock();
            return;
        }
        // One tick for the sweep windows to map and paint before the circle
        // starts shrinking, or the first frames land on an empty surface.
        sweepArmTimer.restart();
    }

    function takeLock() {
        deskHole = 0;
        locked = true;
        // The sweep surfaces keep painting until the compositor confirms every
        // output is covered (`secure`). Stopping on `locked` alone would drop
        // the scene in the gap before the lock surfaces map, and that gap shows
        // the desktop.
        secureFallback.restart();
    }

    onSecureChanged: if (secure && locked) {
        secureFallback.stop();
        sweepPainting = false;
    }

    // If `secure` never lands the sweep surfaces would paint a second copy of
    // the scene forever. The lock itself is unaffected either way.
    Timer {
        id: secureFallback
        interval: 1000
        onTriggered: if (root.locked) {
            root.sweepPainting = false;
        }
    }

    Timer {
        id: sweepArmTimer
        interval: LockMotion.handoffMs
        onTriggered: {
            root.deskHole = 0;
            lockLandTimer.restart();
        }
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
        // Paint the frozen pose into the sweep windows first — they are below
        // the lock surfaces, so nothing shows yet — then hand over on the next
        // tick, when they have a current buffer for the compositor to reveal.
        sweepPainting = true;
        unlockHandoff.restart();
    }

    Timer {
        id: unlockHandoff
        interval: LockMotion.handoffMs
        onTriggered: {
            root.releaseLock();
            root.deskHole = 1;
            unlockLandTimer.restart();
        }
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
        sweepActive = false;
        sweepPainting = false;
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
