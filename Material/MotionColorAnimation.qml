import QtQuick

import "Motion.js" as Motion

// M3 Expressive spring as a drop-in ColorAnimation. Color/opacity runs on
// the critically damped effects springs (never overshoots); defaults to
// effectsDefault.
ColorAnimation {
    property var spring: Motion.effectsDefault

    duration: spring.duration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: spring.curve
}
