pragma Singleton

import QtQml

// Test stand-in for Quickshell.Bluetooth (web-prototype demo devices).
QtObject {
    id: root

    component MockDevice: QtObject {
        property string name
        property string address: "00:11:22:33:44:55"
        property string icon: ""
        property bool connected: false
        property bool paired: true
        property bool bonded: true

        function connect() {
            connected = true;
        }
        function disconnect() {
            connected = false;
        }
    }

    readonly property list<QtObject> allDevices: [
        MockDevice { name: "Pixel Buds Pro"; icon: "audio-headset"; connected: true },
        MockDevice { name: "MX Master 3S"; icon: "input-mouse"; connected: true },
        MockDevice { name: "MX Keys"; icon: "input-keyboard" },
        MockDevice { name: "Pixel 9 Pro"; icon: "phone" }
    ]

    readonly property QtObject defaultAdapter: QtObject {
        property bool enabled: true
        readonly property QtObject devices: QtObject {
            readonly property var values: root.allDevices
        }
    }

    readonly property QtObject devices: QtObject {
        readonly property var values: root.allDevices
    }
}
