.pragma library

// The lock screen's own timings, in one place so the state machine and the
// surfaces can never disagree about them. Everything here is the prototype's
// (src/lock/index.js, stage/auth.js, styles/stage.css); the springs the parts
// move on come from Material/Motion.js like the rest of the shell.

// The sweep: ~900ms on a curve that overshoots, so the visible travel finishes
// early on the curve's fast half. cubic-bezier(.3,1.06,.35,1) as a QML
// BezierSpline — the trailing 1,1 is the segment's own end point.
var sweepMs = 900;
var sweepCurve = [0.3, 1.06, 0.35, 1.0, 1.0, 1.0];

// The avatar goes first, alone: the scallop morphs to a circle, the turning
// stops, the check pops. Only then does the circle open the desktop.
var successHoldMs = 520;

// Long enough for a freshly raised surface to map and paint one frame before
// the circle moves over it. Three frames at 60Hz.
var handoffMs = 48;

// The approach backdrop — the blur and the auth wash — and the glance line
// leaving with them. MD3's standard easing at the prototype's own duration.
var approachMs = 620;

// The avatar's morph to a solid circle, and the check's pop.
var avatarMorphMs = 520;
var checkPopMs = 550;

// One full turn of the scallop. Slow enough to read as drift, not spin.
var scallopTurnMs = 90000;

// The prototype's clip-path percentage resolved against sqrt(w^2+h^2)/sqrt(2),
// which is what makes the circle overshoot the screen corners rather than just
// touching them. Keep the geometry: the sweep is timed against it.
function fullRadius(width, height) {
    return 1.42 * Math.hypot(width, height) / Math.SQRT2;
}
