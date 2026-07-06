pragma Singleton

import QtQml

// Battery at the web prototype's 87% with "5h 12m left".
QtObject {
    readonly property QtObject displayDevice: QtObject {
        readonly property bool ready: true
        readonly property bool isLaptopBattery: true
        readonly property real percentage: 0.87
        readonly property int state: 2
        readonly property int timeToEmpty: 5 * 3600 + 12 * 60
        readonly property int timeToFull: 0
    }
}
