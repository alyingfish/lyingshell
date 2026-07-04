pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import qs.Commons.Settings

// Night light via a shell-owned wlsunset process. Documented gap: niri has
// no gamma/night-light IPC and Quickshell has no color-temperature service,
// so the shell owns a wlsunset child while the toggle is on.
// ponytail: manual on/off only (forced night), no sunrise/sunset schedule;
// add scheduling when a settings UI exposes it.
Singleton {
    id: root

    readonly property bool enabled: Settings.isLoaded && Settings.options.nightLight.enabled
    readonly property int temperature: Settings.options.nightLight.temperature
    readonly property bool active: runner.running

    function toggle() {
        Settings.options.nightLight.enabled = !Settings.options.nightLight.enabled;
    }

    onEnabledChanged: _sync()
    Component.onCompleted: _sync()

    function _sync() {
        runner.running = false;
        if (enabled) {
            // A leftover wlsunset (crashed shell, manual launch) holds the
            // gamma control and would make the new child exit silently.
            killStale.running = true;
        }
    }

    Process {
        id: killStale

        command: ["pkill", "-x", "wlsunset"]

        onExited: {
            if (root.enabled) {
                runner.running = true;
            }
        }
    }

    Process {
        id: runner

        // Sunset at 00:00 / sunrise at 23:59 keeps night mode on all day:
        // the toggle, not the clock, decides.
        command: ["wlsunset", "-t", String(root.temperature), "-T", "6500", "-S", "23:59", "-s", "00:00", "-d", "1"]
    }
}
