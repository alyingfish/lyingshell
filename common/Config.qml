pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string configPath: "~/.config/lyingshell/config.json"
    property alias options: optionsJsonAdapter

    enum BarStyle {
        Hidden,
        Float,
        Hug,
        Rectangle
    }

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
                property int regularStyle: Config.BarStyle.Float
                property int maximizeStyle: Config.BarStyle.Hug
                property int height: 30
                property int margin: 10
                property int radius: 15
            }
        }
    }
}
