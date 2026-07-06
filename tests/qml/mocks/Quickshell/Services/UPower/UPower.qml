pragma Singleton

import QtQml

// Battery at the web prototype's 87% with "5h 12m left". Writable so
// tst_powermode_matrix.qml can drop the battery (PC) or clear the time
// estimate; defaults match the other offscreen tests.
QtObject {
    id: upower

    property bool batteryPresent: true
    property real percentage: 0.87
    property int state: 2 // UPowerDeviceState.Discharging
    property int timeToEmpty: 5 * 3600 + 12 * 60
    property int timeToFull: 0

    readonly property QtObject batteryDevice: QtObject {
        readonly property bool ready: true
        readonly property bool isLaptopBattery: true
        readonly property real percentage: upower.percentage
        readonly property int state: upower.state
        readonly property int timeToEmpty: upower.timeToEmpty
        readonly property int timeToFull: upower.timeToFull
    }

    readonly property var displayDevice: batteryPresent ? batteryDevice : null
}
