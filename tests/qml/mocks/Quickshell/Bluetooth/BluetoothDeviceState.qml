import QtQml

// Mirrors Quickshell.Bluetooth/BluetoothDeviceState.
QtObject {
    enum Kind {
        Disconnected = 0,
        Connecting = 1,
        Connected = 2,
        Disconnecting = 3
    }
}
