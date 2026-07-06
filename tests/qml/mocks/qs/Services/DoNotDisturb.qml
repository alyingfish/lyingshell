pragma Singleton

import QtQml

QtObject {
    readonly property bool available: true
    property bool enabled: false
    readonly property bool busy: false

    function refresh() {
    }
    function toggle() {
        enabled = !enabled;
    }
}
