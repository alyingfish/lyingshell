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

// The entry sweep, split in two at the moment the circle's edge first shows.
//
// The circle starts beyond every screen corner (fullRadius overshoots), so
// the sweep's opening ~102ms move nothing a viewer can see. The prototype
// spends that lead-in anyway; the port spends it on the capture pipeline
// instead — the sweep CLOCK starts on the tap, the stills and the lock race
// it, and when both are ready the circle continues from where the prototype's
// own curve would have it. The constants are the exact de Casteljau split of
// sweepCurve at s=0.14 (tests/test_motion_tokens is not the checker here —
// scripts cannot rerun the derivation — so the numbers carry it):
//
//   split point: x=0.1136 (102ms of 900), y=0.3826 (deskHole 0.6174)
//   tail: the same curve from that point on, renormalized. Replaying
//   holdPoint -> 0 over entryTailMs on entryTailCurve reproduces the
//   original sweep's tail to machine precision.
//
// entryHoldPoint must cover every screen whole: the farthest-corner radius is
// 0.52-0.57 of fullRadius across landscape and portrait aspect ratios (the
// avatar's resting centre sits at 41.7cqh), so 0.6174 leaves margin on all of
// them and the snap from 1 to the hold point cannot show.
var entryLeadInMs = 102;
var entryHoldPoint = 0.6174;
var entryTailMs = 798;
var entryTailCurve = [0.2393, 1.0719, 0.3693, 1.0, 1.0, 1.0];

// The avatar goes first, alone: the scallop morphs to a circle, the turning
// stops, the check pops. Only then does the circle open the desktop.
var successHoldMs = 520;

// The deadline on the exit covers' first presented frames. The release is
// gated on every cover reporting — that is what makes the handoff seamless,
// and the reports normally land within a few frames — so this bound exists
// only for a wedged graphics stack: when it fires the covers are torn down
// first and the unlock degrades to a plain cut, never to a late cover
// flashing the lock over the desktop.
var coverBailMs = 800;

// The cap on waiting for the pre-lock desktop captures. The capture itself
// is ~3 frames (one wlr-screencopy frame plus one grab per output) behind a
// one-frame handshake: the host window commits the frame that carries its
// overlay cut, and only then is the copy requested, so the still can never
// carry the open quick-settings panel. A capture that has not answered in
// this long is not coming, and the lock must never wait on it: the output
// it belonged to degrades to a plain cut.
var captureBailMs = 450;

// The handshake's own bound, for a host window that never swaps another
// frame (nothing dirty, updates throttled). One frame normally ends it.
var captureHandshakeBailMs = 50;

// The cap on arming the entry sweep once the lock is requested: the gates —
// the compositor confirming coverage, the lead-in elapsing, every delivered
// still reporting its first painted frame — normally all land within a few
// frames of the lock (niri only confirms AFTER each output presents a locked
// frame). niri's own surface deadline is 1000ms, so this sits just past it;
// when it fires the sweep runs over whatever is actually up.
var entryBailMs = 1200;

// How long the hello pose waits for its snapshots before sweeping without
// them. A grab is one offscreen render of a surface the compositor is
// actively drawing (a frame or two); if it has not answered in this long the
// graphics stack is in trouble and the unlock must not be gated on it. The
// pose holds still while this runs, so the wait is invisible.
var snapshotBailMs = 600;

// The identity column's landmarks, in container units (1cqh = 1% of the
// surface's height). LockScene lays the avatar out with them, and the sweep
// is anchored on where the avatar RESTS — the exit windows hold a still, not
// a scene, so they need the resting point without a scene to measure it.
var authTopCqh = 35.7;
var avatarCqh = 12;
var sweepOriginYCqh = authTopCqh + avatarCqh / 2;

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
