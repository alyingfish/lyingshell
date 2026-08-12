import QtQuick

import "Motion.js" as Motion

// From-rest projection of an M3 Expressive spring for one-shot Behaviors and
// Transitions. Defaults to the fast spatial token (geometry); pass any
// Motion.js token for the calmer/effect variants. Do not use this duration
// curve for pointer/gesture targets that can reverse mid-flight: those need
// Motion.stepSpring() so the spring retains its current velocity.
//
//     Behavior on scale { MotionAnimation {} }
//     Behavior on x { MotionAnimation { spring: Motion.spatialDefault } }
NumberAnimation {
    property var spring: Motion.spatialFast

    duration: spring.duration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: spring.curve
}
