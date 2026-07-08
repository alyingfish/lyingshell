import QtQml

// Mirrors Quickshell.Networking/WifiDeviceMode.
QtObject {
    enum Kind {
        AdHoc = 0,
        Station = 1,
        AccessPoint = 2,
        Mesh = 3,
        Unknown = 4
    }
}
