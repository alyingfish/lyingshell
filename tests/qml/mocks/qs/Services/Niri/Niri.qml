pragma Singleton

import QtQml

QtObject {
    signal colorPicked(string hex)

    property string lastPickedColor: ""

    function pickColor() {
        // Deliver the reply asynchronously like the real socket round-trip:
        // the panel closes for the aim before the result arrives.
        Qt.callLater(() => {
            lastPickedColor = "#8150ff";
            colorPicked("#8150ff");
        });
        return true;
    }

    function takeScreenshot() {
        return true;
    }

    function quitSession() {
        return true;
    }
}
