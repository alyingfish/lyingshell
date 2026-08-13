pragma Singleton

import QtQml

QtObject {
    readonly property bool isLoaded: true
    readonly property string homeDir: "/tmp"

    readonly property QtObject options: QtObject {
        readonly property QtObject appearance: QtObject {
            property string mode: "light"
            property bool reducedMotion: false
        }
        readonly property QtObject lock: QtObject {
            property string wallpaper: ""
            property bool wallpaperZoom: true
            property string fullName: ""
            property bool focusedOutputOnly: true
            property string pamConfig: ""
        }
        readonly property QtObject bar: QtObject {
            readonly property QtObject shape: QtObject {
                readonly property QtObject floating: QtObject {
                    property int margin: 8
                    property int radius: 16
                    property int height: 32
                }
            }
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
