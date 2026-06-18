pragma Singleton

import Quickshell

Singleton {
    id: root

    readonly property bool ready: true
    readonly property string conditionIconName: "sunny"
    readonly property int temperatureCelsius: 24
}
