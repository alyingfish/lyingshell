pragma Singleton

import QtQml

QtObject {
    readonly property bool isLoaded: true

    readonly property QtObject options: QtObject {
        readonly property QtObject appearance: QtObject {
            property string mode: "light"
        }
        readonly property QtObject quickSettings: QtObject {
            readonly property QtObject colorPicker: QtObject {
                // Writable: QuickSettingsPanel records picks here and the
                // readout's clear button empties it, exactly like the real
                // JsonAdapter property.
                property var recentColors: []
            }
        }
    }
}
