// Wheel-event normalization shared by slider rows, the tile pager, and any
// hover-wheel surface.
.pragma library

// Prefer angleDelta (a mouse notch is 120), else pixelDelta * 8 (Qt's pixel
// ~ angle/8 convention for touchpads). Callers keep `acc` between events and
// act once per accumulated 120-unit notch; a direction reversal resets the
// accumulator so touchpad end-of-swipe jitter cannot bounce the value back.
function wheelNotches(acc, angle, pixel) {
    var delta = angle !== 0 ? angle : pixel * 8;
    var total = acc || 0;
    if (total !== 0 && (delta > 0) !== (total > 0)) {
        total = 0;
    }
    total += delta;
    var steps = total > 0 ? Math.floor(total / 120) : Math.ceil(total / 120);
    return {
        "steps": steps,
        "acc": total - steps * 120
    };
}
