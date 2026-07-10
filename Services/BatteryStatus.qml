pragma Singleton

import QtQml
import Quickshell
import qs.Commons.I18n
import qs.Services

// Human-readable battery status line layered over SystemStatus's normalized
// flags, shared by the quick-settings panel's power-mode row and the bar
// pill's battery tooltip so both read exactly the same. Covers only the
// battery-present case (time estimate / charge state); the no-battery
// power-profile fallback stays with the power-mode row, its only caller.
Singleton {
    id: root

    // Estimate text: "5h 12m" with an hour, else minutes only ("30m", "1m")
    // floored to 1 so a live estimate never renders a dead "0h" or "0h 0m".
    function estimate(seconds, hoursToken, minutesToken) {
        if (seconds >= 3600) {
            return I18n.t(hoursToken, {
                "hours": Math.floor(seconds / 3600),
                "minutes": Math.floor(seconds % 3600 / 60)
            });
        }
        return I18n.t(minutesToken, {
            "minutes": Math.max(1, Math.floor(seconds / 60))
        });
    }

    // The line a laptop battery reads: the live time estimate while charging or
    // discharging (or "Estimating…" until UPower computes one), the plugged-in
    // and full hold states, else the raw percentage. Only meaningful while
    // SystemStatus.hasBattery; the charge flags gate the battery dereferences,
    // so it stays a harmless "0%" with no battery.
    readonly property string line: {
        if (SystemStatus.batteryFull) {
            return I18n.t("quickSettings.batteryFull");
        }
        // Plugged in but held below full (charge limit / hysteresis wait).
        if (SystemStatus.batteryNotCharging) {
            return I18n.t("quickSettings.batteryNotCharging");
        }
        if (SystemStatus.batteryCharging) {
            return SystemStatus.battery.timeToFull > 0 ? estimate(SystemStatus.battery.timeToFull, "quickSettings.timeUntilFull", "quickSettings.minutesUntilFull") : I18n.t("quickSettings.estimating");
        }
        if (SystemStatus.batteryDischarging) {
            return SystemStatus.battery.timeToEmpty > 0 ? estimate(SystemStatus.battery.timeToEmpty, "quickSettings.timeLeft", "quickSettings.minutesLeft") : I18n.t("quickSettings.estimating");
        }
        // Empty / Unknown: no estimate applies, read the raw percentage.
        return I18n.t("quickSettings.batteryPercent", {
            "percent": SystemStatus.batteryPercent
        });
    }
}
