pragma Singleton

import QtQml

// Test stand-in for qs.Services.Time under plain qml6 (the real one holds a
// Quickshell SystemClock). Frozen, so a visual dump of the lock screen is
// byte-comparable between runs.
QtObject {
    id: root

    property date date: new Date(2026, 7, 12, 21, 41, 0)

    readonly property int weekday: date.getDay()

    function format(formatString) {
        return Qt.formatDateTime(root.date, formatString);
    }
}
