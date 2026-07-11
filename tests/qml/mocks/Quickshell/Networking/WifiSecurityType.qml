import QtQml

// Mirrors Quickshell.Networking/WifiSecurityType.
QtObject {
    enum Kind {
        Open = 0,
        WpaPsk = 1,
        Wpa2Psk = 2,
        Sae = 3,
        WpaEap = 4,
        Wpa2Eap = 5,
        StaticWep = 6,
        DynamicWep = 7,
        Leap = 8,
        Owe = 9,
        Wpa3SuiteB192 = 10,
        Unknown = 11
    }
}
