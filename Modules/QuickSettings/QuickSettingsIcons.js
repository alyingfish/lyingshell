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
    return !charging && percent <= 10;
}

// GNOME-style level+mode icon (GNOME uses 10% steps; Material Symbols only
// ships these charging steps, so snap to the closest one below).
function batteryIcon(percent, charging) {
    if (charging) {
        if (percent >= 95) {
            return "battery_charging_full";
        }
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
    var bars = Math.round(percent / 100 * 6);
    if (bars >= 6) {
        return "battery_full";
    }
    return "battery_" + Math.max(0, bars) + "_bar";
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
