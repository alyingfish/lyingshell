pragma Singleton

import Quickshell
import QtQuick
import qs.common

Singleton {
    id: root

    readonly property string time: {
       Qt.formatDateTime(clock.date, Config.options.bar.clock.timeFormat)
    }

    readonly property var precisionMap: {
        "Seconds": SystemClock.Seconds,
        "Minutes": SystemClock.Minutes,
        "Hours":   SystemClock.Hours
    }

    SystemClock {
        id: clock
        // precision: SystemClock.Seconds
        precision: precisionMap[Config.options.bar.clock.precision] || SystemClock.Seconds
    }
}
