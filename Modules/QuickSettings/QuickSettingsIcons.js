// Pure Material Symbol name mappings shared by the bar pill and the panel.
.pragma library

function volumeIcon(volume, muted) {
    if (muted || volume <= 0) {
        return "volume_off";
    }
    if (volume < 0.33) {
        return "volume_mute";
    }
    if (volume < 0.66) {
        return "volume_down";
    }
    return "volume_up";
}

// Single source of truth for the battery_alert / error-color / show-percent
// threshold used by the pill.
function batteryCritical(percent, charging) {
    return !charging && percent <= 5;
}

// GNOME-style level+mode icon (GNOME uses 10% steps; Material Symbols only
// ships these charging steps, so snap to the closest one below). `charged` is
// the FULLY_CHARGED state; charging_full is reserved for it and for 100%.
function batteryIcon(percent, charging, charged) {
    if (charged || (charging && percent >= 100)) {
        return "battery_charging_full";
    }
    if (charging) {
        var steps = [90, 80, 60, 50, 30, 20];
        for (var i = 0; i < steps.length; i++) {
            if (percent >= steps[i]) {
                return "battery_charging_" + steps[i];
            }
        }
        return "battery_charging_20";
    }
    if (batteryCritical(percent, charging)) {
        return "battery_alert";
    }
    // Like GNOME: the solid full icon is reserved for exactly 100%; 92-99 uses
    // battery_6_bar (a hair below full) so "nearly full" reads distinct from full.
    if (percent >= 100) {
        return "battery_full";
    }
    var bars = Math.min(6, Math.round(percent / 100 * 6));
    return "battery_" + Math.max(0, bars) + "_bar";
}

// Wheel normalization shared by the slider rows and the tile pager: prefer
// angleDelta (a mouse notch is 120), else pixelDelta * 8 (Qt's pixel ~
// angle/8 convention for touchpads). Callers keep `acc` between events and
// act once per accumulated 120-unit notch, mirroring the web prototype's
// per-wheel-event steps; a direction reversal resets the accumulator so
// touchpad end-of-swipe jitter cannot bounce the value back.
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

// NetworkManager reports 0-100; tolerate an already-normalized 0-1 value.
function wifiSignalIcon(strength) {
    var normalized = strength > 1 ? strength / 100 : strength;
    if (normalized > 0.8) {
        return "signal_wifi_4_bar";
    }
    if (normalized > 0.55) {
        return "network_wifi_3_bar";
    }
    if (normalized > 0.3) {
        return "network_wifi_2_bar";
    }
    if (normalized > 0.05) {
        return "network_wifi_1_bar";
    }
    return "signal_wifi_0_bar";
}
