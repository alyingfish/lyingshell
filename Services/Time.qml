pragma Singleton

import Quickshell

Singleton {
    id: root

    readonly property int weekday: clock.date.getDay()

    function format(formatString: string): string {
        return Qt.formatDateTime(clock.date, formatString);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
