import QtQml

// Mirrors Quickshell.Networking/ConnectionFailReason.
QtObject {
    enum Kind {
        Unknown = 0,
        WifiNetworkLost = 1,
        WifiClientDisconnected = 2,
        WifiClientFailed = 3,
        NoSecrets = 4,
        WifiAuthTimeout = 5
    }
}
