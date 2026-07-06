pragma Singleton

import QtQml

QtObject {
    readonly property bool available: true
    property real percent: 0.8
    readonly property bool kbdAvailable: true
    property int kbdLevel: 0
    readonly property int kbdMax: 3

    function refresh() {
    }
    function setPercent(v) {
        percent = v;
    }
    function setKbdLevel(level) {
        kbdLevel = level;
    }
    function toggleKbd() {
        kbdLevel = kbdLevel > 0 ? 0 : kbdMax;
    }
}
