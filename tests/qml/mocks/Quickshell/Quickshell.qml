pragma Singleton

import QtQml

// Test stand-in for the Quickshell singleton under plain qml6.
QtObject {
    property string clipboardText: ""

    function env(name) {
        return "";
    }

    function execDetached(cmd) {
    }
}
