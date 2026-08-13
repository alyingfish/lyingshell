pragma Singleton

import QtQml
import QtQuick

import "../../../../../Modules/Lock/LockMotion.js" as LockMotion

// Test stand-in for qs.Services.Lock under plain qml6.
//
// Same public surface as the real service, minus the two halves that need a
// compositor and a PAM stack: `locked` never drives a WlSessionLock here, and
// authentication is the prototype's own demo (the password is `foyer`, and it
// takes 900ms to answer, so the pending state is a real asynchronous phase and
// not a frame).
QtObject {
    id: root

    readonly property string phaseGlance: "glance"
    readonly property string phaseAsk: "ask"
    readonly property string phasePending: "pending"
    readonly property string phaseHello: "hello"

    property bool locked: true
    property bool secure: true
    property string sweepMode: ""
    readonly property bool sweepActive: sweepMode !== ""
    // The one animated value the harnesses drive directly. It carries the
    // product's own curve and duration so a recording of the sweep shows what
    // the real service would produce rather than an instant cut.
    property real deskHole: 0

    Behavior on deskHole {
        NumberAnimation {
            duration: LockMotion.sweepMs
            easing.type: Easing.Bezier
            easing.bezierCurve: LockMotion.sweepCurve
        }
    }

    property string phase: root.phaseGlance
    property bool succeeded: false
    property string password: ""
    property bool capsLock: false
    property bool refused: false
    property bool reveal: false
    property int shakeGeneration: 0
    property string authError: ""

    readonly property string userName: "mira"
    property string displayName: "Mira Solis"
    property string accountAvatar: ""

    property Timer authTimer: Timer {
        interval: 900
        onTriggered: {
            if (root.phase !== root.phasePending) {
                return;
            }
            if (root.password === "foyer") {
                root.beginUnlock();
            } else {
                root.failed("Failed");
            }
        }
    }

    property Timer holdTimer: Timer {
        interval: 520
        onTriggered: root.phase = root.phaseHello
    }

    function lock() {
        locked = true;
        reset();
    }

    function wake(seed) {
        if (phase !== phaseGlance) {
            return;
        }
        password = seed || "";
        refused = false;
        phase = phaseAsk;
    }

    function back() {
        if (phase !== phaseAsk) {
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

    function submit() {
        if (phase !== phaseAsk) {
            return;
        }
        phase = phasePending;
        authTimer.restart();
    }

    function beginUnlock() {
        refused = false;
        succeeded = true;
        holdTimer.restart();
    }

    function failed(reason) {
        phase = phaseAsk;
        succeeded = false;
        refused = true;
        authError = reason || "";
        shakeGeneration++;
    }

    function reset() {
        phase = phaseGlance;
        succeeded = false;
        password = "";
        refused = false;
        reveal = false;
    }
}
