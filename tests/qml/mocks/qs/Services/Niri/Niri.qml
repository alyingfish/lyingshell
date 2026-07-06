pragma Singleton

import QtQml

QtObject {
    signal colorPicked(string hex)

    function pickColor() {
        colorPicked("#8150ff");
        return true;
    }

    function takeScreenshot() {
        return true;
    }

    function quitSession() {
        return true;
    }
}
