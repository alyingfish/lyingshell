pragma Singleton

import QtQml

// Test stand-in for the Quickshell singleton under plain qml6.
QtObject {
    property string clipboardText: ""

    // The connected outputs, as far as a test cares: objects with a `name`.
    // Empty by default; harnesses that walk the lock flow assign their own.
    property var screens: []

    // Repo root, so shader URLs built the way the product builds them
    // (Quickshell.shellDir + "/assets/...") resolve under the mock tree too.
    readonly property string shellDir: Qt.resolvedUrl("../../../..").toString().replace(/^file:\/\//, "").replace(/\/$/, "")

    function env(name) {
        return "";
    }

    function execDetached(cmd) {
    }
}
