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

// The cap on waiting for the exit windows to report their first presented
// frame before the lock is released. The reports normally end the wait
// within a frame or two; the bound only exists so the sweep can never gate
// the unlock.
var sweepHandoffMs = 150;

// The cap on waiting for the pre-lock desktop captures. The capture itself
// is ~3 frames (one wlr-screencopy frame plus one grab per output), behind
// a ~3-frame settle so the bar's overlay cut (the quick-settings panel and
// tray popover snap shut on the entry gesture) has reached the compositor
// before the screencopy renders — a still taken too early carries the open
// panel through the whole entry sweep. A capture that has not answered in
// this long is not coming, and the lock must never wait on it: the output
// it belonged to degrades to a plain cut.
var captureBailMs = 450;

// How long the hello pose waits for its snapshots before sweeping without
// them. A grab is one offscreen render of a surface the compositor is
// actively drawing (a frame or two); if it has not answered in this long the
// graphics stack is in trouble and the unlock must not be gated on it.
var snapshotBailMs = 350;

// The identity column's landmarks, in container units (1cqh = 1% of the
// surface's height). LockScene lays the avatar out with them, and the sweep
// is anchored on where the avatar RESTS — the exit windows hold a still, not
// a scene, so they need the resting point without a scene to measure it.
var authTopCqh = 35.7;
var avatarCqh = 12;
var sweepOriginYCqh = authTopCqh + avatarCqh / 2;

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
