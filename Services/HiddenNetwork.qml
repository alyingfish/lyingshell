pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Joining a hidden (non-broadcast) SSID over nmcli. Documented gap:
// Quickshell.Networking only exposes networks the scanner can see, and a
// hidden network by definition never appears there — joining one needs a
// profile with 802-11-wireless.hidden, i.e. NetworkManager profile
// management.
Singleton {
    id: root

    property bool busy: false
    // SSID of the join in flight (the Wi-Fi page shows it as connecting).
    property string pendingSsid: ""

    signal succeeded(string ssid)
    signal failed(string ssid)

    function join(ssid: string, psk: string) {
        if (busy || ssid.length === 0) {
            return;
        }
        busy = true;
        pendingSsid = ssid;
        const command = ["nmcli", "device", "wifi", "connect", ssid, "hidden", "yes"];
        if (psk.length > 0) {
            command.push("password", psk);
        }
        joinProcess.command = command;
        joinProcess.running = true;
    }

    Process {
        id: joinProcess

        stdout: StdioCollector {}

        onExited: exitCode => {
            const ssid = root.pendingSsid;
            root.busy = false;
            root.pendingSsid = "";
            // nmcli leaves a half-configured profile behind on failure, which
            // would ghost-list the SSID as a known network; drop it.
            if (exitCode !== 0) {
                cleanupProcess.command = ["nmcli", "connection", "delete", ssid];
                cleanupProcess.running = true;
                root.failed(ssid);
            } else {
                root.succeeded(ssid);
            }
        }
    }

    Process {
        id: cleanupProcess
    }
}
