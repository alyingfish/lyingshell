pragma Singleton

import QtQml

QtObject {
    readonly property bool isLoaded: true

    readonly property QtObject options: QtObject {
        readonly property QtObject appearance: QtObject {
            property string mode: "light"
        }
    }
}
