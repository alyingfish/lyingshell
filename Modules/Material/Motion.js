.pragma library

// M3 Expressive motion-scheme springs. QmlMaterial ships only the classic
// MD3 easing set (standard/emphasized QEasingCurves, no springs), so the
// plus kit carries the expressive scheme: official dampingRatio/stiffness
// pairs from androidx ExpressiveMotionTokens.kt, projected for QML as a
// settle `duration` (|y-1| envelope < 1%) plus an Easing.BezierSpline
// `curve` fitted to the exact unit-mass spring step response (max fit
// error ~1%; QtQuick SpringAnimation cannot reach M3 stiffness, its
// useful spring constant caps at 5 vs omega^2 of 380..3800).
//
// Spatial springs move geometry (position/size/corners; only these may
// overshoot), effects springs run color/opacity (critically damped, never
// overshoot). Usage:
//
//     Behavior on radius {
//         NumberAnimation {
//             duration: Motion.spatialFast.duration
//             easing.type: Easing.BezierSpline
//             easing.bezierCurve: Motion.spatialFast.curve
//         }
//     }
//
// Values are generated + verified by tests/test_motion_tokens.py.
// ponytail: expressive scheme only; add StandardMotionTokens when a
// surface needs the calmer standard springs.

var spatialFast = {
    "damping": 0.6,
    "stiffness": 800,
    "duration": 285,
    "curve": [0.0556, 0.0, 0.1111, 0.2722, 0.1667, 0.4917, 0.2222, 0.7113, 0.2778, 0.8891, 0.3333, 0.9829, 0.3889, 1.0767, 0.4444, 1.0982, 0.5, 1.0944, 0.5556, 1.0905, 0.6111, 1.0641, 0.6667, 1.0437, 0.7222, 1.0233, 0.7778, 1.0077, 0.8333, 0.9998, 0.8889, 0.9919, 0.9444, 1.0, 1.0, 1.0]
};

var spatialDefault = {
    "damping": 0.8,
    "stiffness": 380,
    "duration": 328,
    "curve": [0.0556, 0.0, 0.1111, 0.1681, 0.1667, 0.3188, 0.2222, 0.4694, 0.2778, 0.6126, 0.3333, 0.7157, 0.3889, 0.8187, 0.4444, 0.8862, 0.5, 0.9293, 0.5556, 0.9724, 0.6111, 0.9925, 0.6667, 1.0033, 0.7222, 1.0141, 0.7778, 1.0156, 0.8333, 1.0151, 0.8889, 1.0146, 0.9444, 1.0, 1.0, 1.0]
};

var spatialSlow = {
    "damping": 0.8,
    "stiffness": 200,
    "duration": 452,
    "curve": [0.0556, 0.0, 0.1111, 0.1681, 0.1667, 0.3188, 0.2222, 0.4694, 0.2778, 0.6126, 0.3333, 0.7157, 0.3889, 0.8187, 0.4444, 0.8862, 0.5, 0.9293, 0.5556, 0.9724, 0.6111, 0.9925, 0.6667, 1.0033, 0.7222, 1.0141, 0.7778, 1.0156, 0.8333, 1.0151, 0.8889, 1.0146, 0.9444, 1.0, 1.0, 1.0]
};

var effectsFast = {
    "damping": 1.0,
    "stiffness": 3800,
    "duration": 108,
    "curve": [0.0556, 0.0, 0.1111, 0.1684, 0.1667, 0.3033, 0.2222, 0.4383, 0.2778, 0.5593, 0.3333, 0.6485, 0.3889, 0.7378, 0.4444, 0.7994, 0.5, 0.8437, 0.5556, 0.888, 0.6111, 0.9155, 0.6667, 0.9351, 0.7222, 0.9546, 0.7778, 0.9661, 0.8333, 0.9741, 0.8889, 0.9822, 0.9444, 1.0, 1.0, 1.0]
};

var effectsDefault = {
    "damping": 1.0,
    "stiffness": 1600,
    "duration": 166,
    "curve": [0.0556, 0.0, 0.1111, 0.1684, 0.1667, 0.3033, 0.2222, 0.4383, 0.2778, 0.5593, 0.3333, 0.6485, 0.3889, 0.7378, 0.4444, 0.7994, 0.5, 0.8437, 0.5556, 0.888, 0.6111, 0.9155, 0.6667, 0.9351, 0.7222, 0.9546, 0.7778, 0.9661, 0.8333, 0.9741, 0.8889, 0.9822, 0.9444, 1.0, 1.0, 1.0]
};

var effectsSlow = {
    "damping": 1.0,
    "stiffness": 800,
    "duration": 235,
    "curve": [0.0556, 0.0, 0.1111, 0.1684, 0.1667, 0.3033, 0.2222, 0.4383, 0.2778, 0.5593, 0.3333, 0.6485, 0.3889, 0.7378, 0.4444, 0.7994, 0.5, 0.8437, 0.5556, 0.888, 0.6111, 0.9155, 0.6667, 0.9351, 0.7222, 0.9546, 0.7778, 0.9661, 0.8333, 0.9741, 0.8889, 0.9822, 0.9444, 1.0, 1.0, 1.0]
};
