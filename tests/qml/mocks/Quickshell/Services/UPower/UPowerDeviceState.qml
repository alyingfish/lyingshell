import QtQml

QtObject {
    enum Kind {
        Charging = 1,
        Discharging = 2,
        FullyCharged = 4,
        PendingCharge = 5
    }
}
