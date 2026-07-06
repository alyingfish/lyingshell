import QtQuick

import "Motion.js" as Motion

// M3 Expressive spring as a drop-in NumberAnimation for Behaviors and
// Transitions. Defaults to the fast spatial spring (geometry); pass any
// Motion.js token for the calmer/effect variants:
//
//     Behavior on scale { MotionAnimation {} }
//     Behavior on x { MotionAnimation { spring: Motion.spatialDefault } }
NumberAnimation {
    property var spring: Motion.spatialFast

    duration: spring.duration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: spring.curve
}
