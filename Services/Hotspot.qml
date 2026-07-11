pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Wi-Fi hotspot (AP mode) over nmcli. Documented gap: Quickshell.Networking
// reports AP mode (WifiDevice.mode == AccessPoint) but exposes no API to
// create or activate an AP-mode connection profile, which needs
// NetworkManager profile management.
//
// KDE interplay model (web prototype radios.js): the hotspot borrows the
// Wi-Fi adapter — starting it forces the radio on and NetworkManager drops
// the current network itself; stopping it lets NM autoconnect restore the
// previous network. Turning the radio off takes the AP down with it (NM).
Singleton {
    id: root

    readonly property string profileName: "Hotspot"
    readonly property var wifiDevice: Networking.devices.values.find(device => device !== null && device.type === DeviceType.Wifi) || null
    readonly property bool available: wifiDevice !== null
    readonly property bool active: wifiDevice !== null && wifiDevice.mode === WifiDeviceMode.AccessPoint
    // A start/stop is in flight (drives the tile's acquiring pulse).
    property bool busy: false

    // Share details for the Wi-Fi detail card, read from the NM profile.
    property string ssid: ""
    property string password: ""
    property string security: ""
    property string band: ""

    signal failed

    onActiveChanged: {
        busy = false;
        if (active) {
            refreshDetails();
        }
    }

    onBusyChanged: busyFailsafe.running = busy

    // nmcli waits for activation, so busy normally clears via the exit
    // handlers or the mode flip; this stops a stuck pulse if NM stalls.
    Timer {
        id: busyFailsafe

        interval: 20000
        onTriggered: root.busy = false
    }

    function start() {
        if (busy || !available) {
            return;
        }
        busy = true;
        // The AP borrows the radio: force it on first (prototype setToggle).
        if (!Networking.wifiEnabled) {
            Networking.wifiEnabled = true;
        }
        upProcess.running = true;
    }

    function stop() {
        if (busy || !available) {
            return;
        }
        busy = true;
        downProcess.running = true;
    }

    function toggle() {
        if (active) {
            stop();
        } else {
            start();
        }
    }

    function refreshDetails() {
        detailsProcess.running = true;
    }

    // Reuse the saved profile when there is one; fall back to creating it.
    Process {
        id: upProcess

        command: ["nmcli", "connection", "up", root.profileName]

        onExited: exitCode => {
            if (exitCode !== 0) {
                createProcess.running = true;
            }
        }
    }

    // First run: let nmcli create the AP profile (it generates a password;
    // the details read below surfaces it on the hotspot card).
    Process {
        id: createProcess

        command: ["nmcli", "device", "wifi", "hotspot", "con-name", root.profileName]

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.busy = false;
                root.failed();
            }
        }
    }

    Process {
        id: downProcess

        command: ["nmcli", "connection", "down", root.profileName]

        onExited: root.busy = false
    }

    Process {
        id: detailsProcess

        command: ["nmcli", "-s", "-t", "-f", "802-11-wireless.ssid,802-11-wireless.band,802-11-wireless-security.psk,802-11-wireless-security.key-mgmt", "connection", "show", root.profileName]

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = {};
                text.split("\n").forEach(line => {
                    const split = line.indexOf(":");
                    if (split > 0) {
                        fields[line.substring(0, split)] = line.substring(split + 1);
                    }
                });
                root.ssid = fields["802-11-wireless.ssid"] || "";
                root.password = fields["802-11-wireless-security.psk"] || "";
                const keyMgmt = fields["802-11-wireless-security.key-mgmt"] || "";
                root.security = keyMgmt === "sae" ? "WPA3" : keyMgmt.length > 0 ? "WPA2" : "";
                const rawBand = fields["802-11-wireless.band"] || "";
                root.band = rawBand === "a" ? "5 GHz" : rawBand === "bg" ? "2.4 GHz" : "";
            }
        }
    }
}
