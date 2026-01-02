pragma Singleton

import Qt.labs.platform
import QtQuick
import Quickshell

Singleton {
    /**
     * Trims the File protocol off the input string
     * @param {string} str
     * @returns {string}
     */
    function trimFileProtocol(str) {
        return str.startsWith("file://") ? str.slice(7) : str;
    }

    // XDG Dirs, with "file://"
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]
    readonly property string state: StandardPaths.standardLocations(StandardPaths.StateLocation)[0]
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0]
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]

    // Other dirs used by the shell, without "file://"
    property string shellConfigDir: Directory.trimFileProtocol(`${config}/lyingshell/`)
    property string shellThemeDir: Directory.trimFileProtocol(`${shellConfigDir}/themes/`)

    // Cleanup on init
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${shellConfigDir}`]);
        Quickshell.execDetached(["mkdir", "-p", `${shellThemeDir}`]);
    }
}
