pragma Singleton

import QtQml

// Test stand-in for qs.Commons.I18n: returns the token itself so pointer
// tests can run under plain qml6 without the Quickshell runtime.
QtObject {
    readonly property bool isLoaded: true

    function t(token, values) {
        return token;
    }
}
