pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property alias colors: adapter

    FileView {
        path: Directory.shellThemeDir + Config.options.theme + ".json"
        watchChanges: true
        onFileChanged: reload()
        blockLoading: true

        adapter: JsonAdapter {
            id: adapter

            property JsonObject bar: JsonObject {
                property color background: "#000000"
            }
        }
    }
}
