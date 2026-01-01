pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string configPath: Directory.shellConfigPath
    property alias options: optionsJsonAdapter

    FileView {
        path: root.configPath

        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        JsonAdapter {
            id: optionsJsonAdapter
            property JsonObject bar: JsonObject {
                property string backgroundColor: "gray" // TODO: should move to a theme config
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
            }
        }
    }
}
