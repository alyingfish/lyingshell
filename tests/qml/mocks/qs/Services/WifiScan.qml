pragma Singleton

import QtQml

// Test stand-in for the Wi-Fi rescan service: records the call, spawns nothing.
QtObject {
    id: root

    property int rescanCount: 0

    function rescan() {
        rescanCount += 1;
    }
}
