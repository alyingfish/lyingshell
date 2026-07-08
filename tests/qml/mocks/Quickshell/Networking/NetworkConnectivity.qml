import QtQml

// Mirrors Quickshell.Networking/NetworkConnectivity (NetworkManager values).
QtObject {
    enum Kind {
        Unknown = 0,
        None = 1,
        Portal = 2,
        Limited = 3,
        Full = 4
    }
}
