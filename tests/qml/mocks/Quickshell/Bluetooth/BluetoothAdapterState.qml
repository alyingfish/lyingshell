import QtQml

// Mirrors Quickshell.Bluetooth/BluetoothAdapterState.
QtObject {
    enum Kind {
        Disabled = 0,
        Enabled = 1,
        Enabling = 2,
        Disabling = 3,
        Blocked = 4
    }
}
