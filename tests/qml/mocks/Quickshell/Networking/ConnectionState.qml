import QtQml

// Mirrors Quickshell.Networking/ConnectionState.
QtObject {
    enum Kind {
        Unknown = 0,
        Connecting = 1,
        Connected = 2,
        Disconnecting = 3,
        Disconnected = 4
    }
}
