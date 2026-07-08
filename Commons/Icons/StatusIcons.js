// Pure Material Symbol name mappings for system status (volume, battery,
// brightness, network, bluetooth), shared by the bar's quick-settings
// button and the quick-settings menu.
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

// Web-prototype brightness glyph steps (0 / <34 / <67 / high) on a 0..1
// value; the slider icon is a plain readout, not a button.
function brightnessIcon(percent) {
    if (percent <= 0) {
        return "brightness_empty";
    }
    if (percent < 0.34) {
        return "brightness_low";
    }
    if (percent < 0.67) {
        return "brightness_medium";
    }
    return "brightness_high";
}

// Bluez freedesktop icon name -> Material Symbol for the device list.
function btDeviceIcon(iconName) {
    var name = String(iconName || "");
    if (name.indexOf("headset") >= 0 || name.indexOf("headphone") >= 0 || name.indexOf("audio") >= 0) {
        return "headset_mic";
    }
    if (name.indexOf("mouse") >= 0) {
        return "mouse";
    }
    if (name.indexOf("keyboard") >= 0) {
        return "keyboard";
    }
    if (name.indexOf("phone") >= 0) {
        return "smartphone";
    }
    if (name.indexOf("watch") >= 0) {
        return "watch";
    }
    return "bluetooth";
}

// Output-device glyph from its Pipewire description/name keywords.
function audioSinkIcon(label) {
    var name = String(label || "").toLowerCase();
    if (name.indexOf("headphone") >= 0 || name.indexOf("headset") >= 0 || name.indexOf("bluez") >= 0) {
        return "headset_mic";
    }
    if (name.indexOf("hdmi") >= 0 || name.indexOf("displayport") >= 0 || name.indexOf("display") >= 0) {
        return "monitor";
    }
    return "speaker";
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

// The bar's single network glyph, in priority order. apMode = this machine is
// hosting a hotspot (WifiDevice AccessPoint mode). noInternet = connected but
// NetworkManager reports captive-portal / limited / no-route connectivity.
// activeStrength is null when no wifi network is active.
function networkIcon(wiredConnected, wifiEnabled, apMode, activeStrength, noInternet) {
    if (wiredConnected) {
        return "lan";
    }
    if (!wifiEnabled) {
        return "signal_wifi_off";
    }
    if (apMode) {
        return "wifi_tethering";
    }
    if (activeStrength !== null && activeStrength !== undefined) {
        return noInternet ? "signal_wifi_bad" : wifiSignalIcon(activeStrength);
    }
    // Enabled but not attached to any network (distinct from a connected
    // 0-bar link).
    return "signal_wifi_statusbar_not_connected";
}
