pragma Singleton

import QtQml

QtObject {
    readonly property bool available: true
    property bool enabled: false

    function refresh() {
    }
    function toggle() {
        enabled = !enabled;
    }
}
