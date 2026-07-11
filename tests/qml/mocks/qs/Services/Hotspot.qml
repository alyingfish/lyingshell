pragma Singleton

import QtQml

// Test stand-in for Services/Hotspot.qml (nmcli-backed AP mode): inactive
// station mode by default; tests flip `active` directly.
QtObject {
    readonly property string profileName: "Hotspot"
    property bool available: true
    property bool active: false
    property bool busy: false
    property string ssid: "ROG-Zephyrus Hotspot"
    property string password: "sunset-parade-42"
    property string security: "WPA2"
    property string band: "5 GHz"

    signal failed

    function start() {
        active = true;
    }

    function stop() {
        active = false;
    }

    function toggle() {
        active = !active;
    }

    function refreshDetails() {
    }
}
