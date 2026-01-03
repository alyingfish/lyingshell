pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property alias options: adapter

    FileView {
        path: Directory.shellConfigDir + "config.json"
        watchChanges: true
        onFileChanged: reload()
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        adapter: JsonAdapter {
            id: adapter

            property string theme: "light" // options: light, dark
            property JsonObject bar: JsonObject {
                property int height: 30
                property JsonObject style: JsonObject {
                    property string noWindowStyle: "float" // options: hidden, float, hug, rectangle
                    property string hasWindowStyle: "hug" // options: hidden, float, hug, rectangle
                    property int floatMargin: 10
                    property int roundRadius: 15
                }
                property JsonObject clock: JsonObject {
                    property string timeFormat: "ddd MMM d hh:mm:ss AP t yyyy" // Qt date/time format string
                    property string precision: "Seconds" // options: Seconds, Minutes, Hours
                }
                property JsonObject systemTray: JsonObject {
                    property int spacing: 2
                    property int iconSize: 16
                    property int buttonSize: 24
                    property int buttonRadius: 4
                    property bool hidePassive: true
                }
            }
        }
    }
}
