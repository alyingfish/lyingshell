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
        property bool trusted: true
        property bool pairing: false
        property real battery: 0
        property bool batteryAvailable: false
        property int state: connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected

        function connect() {
            connected = true;
        }
        function disconnect() {
            connected = false;
        }
        function pair() {
            paired = true;
            bonded = true;
            trusted = true;
            connected = true;
        }
        function cancelPair() {
            pairing = false;
        }
        function forget() {
            paired = false;
            bonded = false;
            trusted = false;
            connected = false;
        }
    }

    readonly property list<QtObject> allDevices: [
        MockDevice { name: "Pixel Buds Pro"; icon: "audio-headset"; connected: true; battery: 0.85; batteryAvailable: true },
        MockDevice { name: "MX Master 3S"; icon: "input-mouse"; connected: true; battery: 0.7; batteryAvailable: true },
        MockDevice { name: "MX Keys"; icon: "input-keyboard" },
        MockDevice { name: "Pixel 9 Pro"; icon: "phone" },
        MockDevice { name: "JBL Flip 6"; icon: "audio-card"; paired: false; bonded: false; trusted: false },
        MockDevice { name: "Galaxy S24"; icon: "phone"; paired: false; bonded: false; trusted: false }
    ]

    readonly property QtObject defaultAdapter: QtObject {
        property bool enabled: true
        property string name: "ROG-Zephyrus"
        property bool discovering: false
        property bool discoverable: false
        property int state: enabled ? BluetoothAdapterState.Enabled : BluetoothAdapterState.Disabled
        readonly property QtObject devices: QtObject {
            readonly property var values: root.allDevices
        }
    }

    readonly property QtObject devices: QtObject {
        readonly property var values: root.allDevices
    }
}
