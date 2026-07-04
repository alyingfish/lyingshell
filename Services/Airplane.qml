pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

// Airplane mode over rfkill. Documented gap: Quickshell.Networking exposes
// wifi soft-block only; GNOME's airplane mode blocks every radio, which
// needs rfkill. State refreshes on demand (panel open) and after toggling.
Singleton {
    id: root

    property bool available: false
    // GNOME semantics: airplane mode is "wifi is rfkill-blocked".
    property bool enabled: false
    property bool busy: false

    function refresh() {
        if (!readProcess.running) {
            readProcess.running = true;
        }
    }

    function setEnabled(value: bool) {
        if (busy) {
            return;
        }
        busy = true;
        enabled = value;
        toggleProcess.command = ["rfkill", value ? "block" : "unblock", "all"];
        toggleProcess.running = true;
    }

    function toggle() {
        setEnabled(!enabled);
    }

    Component.onCompleted: refresh()

    Process {
        id: readProcess

        command: ["rfkill", "-J"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    // util-linux names the array "rfkilldevices"; older
                    // releases used an empty-string key.
                    const devices = parsed.rfkilldevices || parsed[""] || [];
                    const wlan = devices.filter(device => device.type === "wlan");
                    root.available = wlan.length > 0;
                    root.enabled = root.available && wlan.every(device => device.soft === "blocked" || device.hard === "blocked");
                } catch (error) {
                    root.available = false;
                }
            }
        }
    }

    Process {
        id: toggleProcess

        onExited: {
            root.busy = false;
            root.refresh();
        }
    }
}
