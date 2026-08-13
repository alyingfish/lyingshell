.pragma library

// M3 Expressive motion-scheme springs. QmlMaterial ships only the classic
// MD3 easing set (standard/emphasized QEasingCurves, no springs), so the
// plus kit carries the expressive scheme: official dampingRatio/stiffness
// pairs from androidx ExpressiveMotionTokens.kt. One-shot QML Behaviors use a
// settle `duration` (|y-1| envelope < 1%) plus an Easing.BezierSpline `curve`
// fitted to the exact unit-mass spring step response (max fit error ~1%;
// QtQuick SpringAnimation cannot reach M3 stiffness, its useful spring
// constant caps at 5 vs omega^2 of 380..3800). Interactive motion uses
// stepSpring() below so retargeting retains velocity instead of restarting a
// duration curve from rest.
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
// ponytail: the expressive scheme in full, plus the one standard spatial
// spring a surface has actually asked for; add the rest of
// StandardMotionTokens the same way when something needs them.

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

// StandardMotionTokens' fast spatial spring, not the expressive scheme's. The
// standard scheme damps its spatial springs at ζ 0.9 where expressive damps at
// ζ 0.6-0.8, which is the whole difference between the two: same categories,
// quieter geometry. It is here for rows of small marks that travel as a group —
// a caret and the dots it walks past read as sloppy when each one overshoots
// 9.5% on its own, and the expressive spatial springs cannot be asked for less.
//
// The 1% settle envelope lands at 161ms, which is BEFORE this spring's first
// overshoot (its peak is at 193ms), so the fitted curve is monotone and the
// 0.15% overshoot never appears in it. That is a property of the projection,
// not a smoothing of the token: stepSpring() on these numbers still overshoots.
var standardSpatialFast = {
    "damping": 0.9,
    "stiffness": 1400,
    "duration": 161,
    "curve": [0.0556, 0.0, 0.1111, 0.1474, 0.1667, 0.2796, 0.2222, 0.4118, 0.2778, 0.5395, 0.3333, 0.6362, 0.3889, 0.7329, 0.4444, 0.8023, 0.5, 0.8515, 0.5556, 0.9006, 0.6111, 0.9305, 0.6667, 0.9507, 0.7222, 0.9709, 0.7778, 0.9815, 0.8333, 0.9882, 0.8889, 0.995, 0.9444, 1.0, 1.0, 1.0]
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

// Advance a unit-mass spring by `seconds`, retaining velocity across calls and
// target changes. This is the actual spring behind the M3 tokens above; the
// Bezier projections remain useful for one-shot QML Behaviors, but an
// interactive target must carry velocity when it is interrupted. The closed
// form solution is frame-rate independent and stays stable across a long
// compositor frame, unlike an Euler integrator.
function stepSpring(value, velocity, target, spring, seconds) {
    var dt = Math.max(0, seconds);
    if (dt === 0 || !isFinite(dt)) {
        return {
            "value": value,
            "velocity": velocity
        };
    }

    var zeta = spring.damping;
    var omega = Math.sqrt(spring.stiffness);
    var displacement = value - target;
    var nextDisplacement;
    var nextVelocity;

    if (zeta < 1) {
        var decay = zeta * omega;
        var damped = omega * Math.sqrt(1 - zeta * zeta);
        var phase = damped * dt;
        var envelope = Math.exp(-decay * dt);
        var cosine = Math.cos(phase);
        var sine = Math.sin(phase);

        nextDisplacement = envelope * (displacement * cosine + (velocity + decay * displacement) / damped * sine);
        nextVelocity = envelope * (velocity * cosine - (decay * velocity + omega * omega * displacement) / damped * sine);
    } else if (zeta === 1) {
        var criticalEnvelope = Math.exp(-omega * dt);
        var coefficient = velocity + omega * displacement;

        nextDisplacement = criticalEnvelope * (displacement + coefficient * dt);
        nextVelocity = criticalEnvelope * (velocity - omega * coefficient * dt);
    } else {
        var root = Math.sqrt(zeta * zeta - 1);
        var slowRoot = -omega * (zeta - root);
        var fastRoot = -omega * (zeta + root);
        var slowCoefficient = (velocity - fastRoot * displacement) / (slowRoot - fastRoot);
        var fastCoefficient = displacement - slowCoefficient;
        var slowEnvelope = Math.exp(slowRoot * dt);
        var fastEnvelope = Math.exp(fastRoot * dt);

        nextDisplacement = slowCoefficient * slowEnvelope + fastCoefficient * fastEnvelope;
        nextVelocity = slowRoot * slowCoefficient * slowEnvelope + fastRoot * fastCoefficient * fastEnvelope;
    }

    return {
        "value": target + nextDisplacement,
        "velocity": nextVelocity
    };
}
