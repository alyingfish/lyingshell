pragma Singleton

import Quickshell

Singleton {
    id: root

    readonly property bool ready: true
    readonly property string conditionIconName: "light_mode"
    readonly property int temperatureCelsius: 24
}
