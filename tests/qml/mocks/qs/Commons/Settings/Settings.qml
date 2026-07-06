pragma Singleton

import QtQml

QtObject {
    readonly property bool isLoaded: true

    readonly property QtObject options: QtObject {
        readonly property QtObject theme: QtObject {
            property string mode: "light"
        }
    }
}
