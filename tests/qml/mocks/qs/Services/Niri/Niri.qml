pragma Singleton

import QtQml

QtObject {
    signal colorPicked(string hex)

    property string lastPickedColor: ""

    function pickColor() {
        lastPickedColor = "#8150ff";
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
