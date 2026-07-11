pragma Singleton

import QtQml

// Test stand-in for Services/Toast.qml: records the last message so tests
// can assert feedback fired without a window.
QtObject {
    property string text: ""
    property bool active: false
    property bool shown: false
    property int showCount: 0

    function show(message) {
        text = message;
        active = true;
        shown = true;
        showCount++;
    }
}
