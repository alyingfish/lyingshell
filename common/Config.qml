pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string configPath: "/home/lyingfish/.config/lyingshell/config.json"
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
                property string regularStyle: "float" // options: float, hug, rectangle
                property string maximizeStyle: "hug" // options: float, hug, rectangle
                property string backgroundColor: "white" // options: float, hug, rectangle
                property int height: 30
                property int margin: 10
                property int radius: 15
            }
        }
    }
}
