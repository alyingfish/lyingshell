pragma Singleton

import QtQml
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.Commons.I18n

// Completion feedback for user-initiated Wi-Fi / Bluetooth connects and
// pairs (web prototype wifi.js/bt.js): success always raises a toast;
// failure raises one only when the matching detail view is not on screen —
// the page shows the error inline while it is. Lives outside the pages so a
// connect started in the panel still reports after the panel closes
// (GNOME raises a system notification on activation failure).
Singleton {
    id: root

    // Which detail page is on screen ("wifi" | "bluetooth" | ...); written
    // by QuickSettingsPanel.
    property string visibleDetail: ""

    // --- Wi-Fi ---------------------------------------------------------------
    // The network being connected by explicit user action (one at a time).
    property var wifiPending: null
    // The page (when alive) shows this failure inline.
    signal wifiFailed(var network, int reason)

    function watchWifi(network) {
        wifiPending = network;
    }

    Connections {
        target: root.wifiPending

        function onConnectedChanged() {
            const network = root.wifiPending;
            if (network.connected) {
                root.wifiPending = null;
                Toast.show(I18n.t("toast.wifiConnected", {
                    "name": network.name
                }));
                if (Networking.canCheckConnectivity) {
                    Networking.checkConnectivity();
                }
            }
        }

        function onConnectionFailed(reason: int) {
            const network = root.wifiPending;
            root.wifiPending = null;
            root.wifiFailed(network, reason);
            if (root.visibleDetail !== "wifi") {
                Toast.show(I18n.t("toast.wifiFailed", {
                    "name": network.name
                }));
            }
        }
    }

    // Captive portal: NM's connectivity check landing on Portal is the
    // sign-in cue (prototype: "Sign-in required for X" after the check).
    property int _lastConnectivity: Networking.connectivity

    Connections {
        target: Networking

        function onConnectivityChanged() {
            const current = Networking.connectivity;
            if (current === NetworkConnectivity.Portal && root._lastConnectivity !== NetworkConnectivity.Portal) {
                Toast.show(I18n.t("toast.wifiPortal"));
            }
            root._lastConnectivity = current;
        }
    }

    // Hidden-SSID joins run through their own nmcli path, not a watched
    // network object; toast their completion here so it survives the panel.
    Connections {
        target: HiddenNetwork

        function onSucceeded(ssid: string) {
            Toast.show(I18n.t("toast.wifiConnected", {
                "name": ssid
            }));
        }

        function onFailed(ssid: string) {
            Toast.show(I18n.t("toast.wifiFailed", {
                "name": ssid
            }));
        }
    }

    // --- Hotspot ---------------------------------------------------------------
    // Prototype: "Hotspot on — SSID" / "Hotspot off" on every flip, and a
    // failure toast when the AP could not start. The "on" toast waits out a
    // short confirm window: an AP that starts and immediately drops (e.g.
    // NM shared mode failing ip-config without dnsmasq) is a failed start,
    // not an on/off flap.
    Connections {
        target: Hotspot

        function onActiveChanged() {
            if (Hotspot.active) {
                hotspotConfirm.restart();
            } else if (hotspotConfirm.running) {
                hotspotConfirm.stop();
                Toast.show(I18n.t("toast.hotspotFailed"));
            } else {
                Toast.show(I18n.t("toast.hotspotOff"));
            }
        }

        function onFailed() {
            Toast.show(I18n.t("toast.hotspotFailed"));
        }
    }

    Timer {
        id: hotspotConfirm

        interval: 2000
        onTriggered: Toast.show(I18n.t("toast.hotspotOn", {
            "name": Hotspot.ssid.length > 0 ? Hotspot.ssid : Hotspot.profileName
        }))
    }

    // --- Bluetooth -----------------------------------------------------------
    // The device being connected or paired by explicit user action.
    property var btPending: null
    property bool _btWasPairing: false
    property bool _btWasConnecting: false

    signal btFailed(var device)

    function watchBt(device) {
        _btWasPairing = device.pairing;
        _btWasConnecting = device.state === BluetoothDeviceState.Connecting;
        btPending = device;
    }

    Connections {
        target: root.btPending

        function onConnectedChanged() {
            const device = root.btPending;
            if (device.connected) {
                root.btPending = null;
                Toast.show(I18n.t("toast.btConnected", {
                    "name": device.name.length > 0 ? device.name : device.address
                }));
            }
        }

        function onStateChanged() {
            const device = root.btPending;
            if (device.state === BluetoothDeviceState.Connecting) {
                root._btWasConnecting = true;
            } else if (device.state === BluetoothDeviceState.Disconnected && root._btWasConnecting && !device.connected && !device.pairing) {
                root.btPending = null;
                root.btFailed(device);
                if (root.visibleDetail !== "bluetooth") {
                    Toast.show(I18n.t("toast.btConnectFailed", {
                        "name": device.name.length > 0 ? device.name : device.address
                    }));
                }
            }
        }

        function onPairingChanged() {
            const device = root.btPending;
            if (device.pairing) {
                root._btWasPairing = true;
            } else if (root._btWasPairing && !device.paired) {
                // Pairing ended without a bond: the agent flow failed.
                root.btPending = null;
                root.btFailed(device);
                if (root.visibleDetail !== "bluetooth") {
                    Toast.show(I18n.t("toast.btPairFailed", {
                        "name": device.name.length > 0 ? device.name : device.address
                    }));
                }
            }
        }
    }
}
