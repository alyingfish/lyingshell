pragma Singleton

import QtQml

QtObject {
    property bool enabled: false
    readonly property bool active: enabled

    function toggle() {
        enabled = !enabled;
    }
}
