import QtQuick

import "Motion.js" as Motion

// A live M3 Expressive spring for state that may be retargeted while moving.
// MotionAnimation is the from-rest Bezier projection used by one-shot
// Behaviors; this component advances the official unit-mass spring itself, so
// an interrupted interaction keeps its velocity and changes direction
// naturally. Geometry callers pass a spatial token; alpha/color-like scalar
// callers pass the corresponding effects token.
Item {
    id: root

    property real target: 0
    property var spring: Motion.spatialDefault
    property bool motionEnabled: true
    // AndroidX Spring.DefaultDisplacementThreshold. Its velocity cutoff is the
    // distance that would take at least one 16ms frame to traverse.
    property real visibilityThreshold: 0.01

    property real value: 0
    property real velocity: 0
    property bool ready: false

    readonly property real velocityThreshold: visibilityThreshold * 1000 / 16
    readonly property bool atRest: Math.abs(value - target) < visibilityThreshold && Math.abs(velocity) < velocityThreshold
    readonly property bool animating: driver.running

    function snap() {
        value = target;
        velocity = 0;
    }

    onTargetChanged: if (ready && !motionEnabled)
        snap()
    onMotionEnabledChanged: if (ready && !motionEnabled)
        snap()

    FrameAnimation {
        id: driver

        running: root.ready && root.motionEnabled && !root.atRest

        onTriggered: {
            var next = Motion.stepSpring(root.value, root.velocity, root.target, root.spring, frameTime);
            root.value = next.value;
            root.velocity = next.velocity;
            if (root.atRest) {
                root.snap();
            }
        }
    }

    Component.onCompleted: {
        snap();
        ready = true;
    }
}
