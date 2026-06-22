pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isLoaded: false
    property bool directoriesReady: false
    property bool creatingRuntimeFile: false
    property bool loadingRuntimeFile: false
    property string errorMessage: ""

    readonly property alias options: settingsAdapter
    readonly property bool hasError: errorMessage.length > 0
    readonly property string homeDir: String(Quickshell.env("HOME") || "")
    readonly property string configDir: homeDir + "/.config/lyingshell"
    readonly property string settingsPath: configDir + "/settings.json"

    Component.onCompleted: initialize()

    Timer {
        id: externalReloadTimer
        interval: 160
        repeat: false

        onTriggered: {
            if (runtimeSettingsFile.path.length > 0) {
                root.reloadRuntimeSettings();
            }
        }
    }

    Process {
        id: createConfigDir
        command: ["mkdir", "-p", root.configDir]

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.ensureLoadedWithDefaults();
                root.handleRuntimeSettingsError("Failed to create settings directory");
                return;
            }

            root.directoriesReady = true;
        }
    }

    Process {
        id: settingsErrorNotifier

        property string notificationTitle: "Lying Shell settings error"

        function notify(message) {
            if (running) {
                running = false;
            }

            command = ["notify-send", notificationTitle, message];
            running = true;
        }

        command: ["notify-send", notificationTitle, ""]
    }

    FileView {
        id: runtimeSettingsFile
        path: root.directoriesReady ? root.settingsPath : ""
        printErrors: false
        watchChanges: true

        onFileChanged: externalReloadTimer.restart()

        onLoaded: {
            root.loadingRuntimeFile = false;
            root.isLoaded = true;
            root.errorMessage = "";
        }

        onSaved: {
            if (root.creatingRuntimeFile) {
                root.creatingRuntimeFile = false;
                root.reloadRuntimeSettings();
            }
        }

        onLoadFailed: function(error) {
            root.loadingRuntimeFile = false;
            if (error === FileViewError.FileNotFound) {
                root.createRuntimeSettingsFile();
                return;
            }

            root.ensureLoadedWithDefaults();
            root.handleRuntimeSettingsError("Failed to load settings: " + FileViewError.toString(error));
        }

        onSaveFailed: function(error) {
            root.creatingRuntimeFile = false;
            root.loadingRuntimeFile = false;
            root.ensureLoadedWithDefaults();
            root.handleRuntimeSettingsError("Failed to create settings file: " + FileViewError.toString(error));
        }

        onAdapterUpdated: {
            if (!root.isLoaded || root.loadingRuntimeFile || root.creatingRuntimeFile) {
                return;
            }

            writeAdapter();
        }

        adapter: JsonAdapter {
            id: settingsAdapter

            property string language: "en"
            property JsonObject bar: JsonObject {
                property real height: 32
                property string currentShape: "floating"
                property JsonObject shape: JsonObject {
                    property JsonObject floating: JsonObject {
                        property int margin: 8
                        property int cornerRadius: 16
                        property real elevation: 3
                        property real opacity: 0.92
                        property real blur: 8.0
                    }
                    property JsonObject softAttach: JsonObject {
                        property int margin: 0
                        property int topCornerRadius: 0
                        property int bottomCornerRadius: 16
                        property real elevation: 3
                        property real opacity: 0.92
                        property real blur: 8.0
                    }
                    property JsonObject fullWidth: JsonObject {
                        property int margin: 0
                        property int cornerRadius: 0
                        property real elevation: 0
                        property real opacity: 1.0
                        property real blur: 0.0
                    }
                    property JsonObject hug: JsonObject {
                        property int margin: 0
                        property int reversedCornerRadius: 16
                        property real elevation: 0
                        property real opacity: 1.0
                        property real blur: 0.0
                    }
                }
                property JsonObject workspaces: JsonObject {
                    property bool reverseScroll: false
                    property bool scrollLoop: true
                    property bool urgentPulse: true
                }
            }
            property JsonObject theme: JsonObject {
                property string mode: "system"
                property string accentColor: "#4F6357"
                property string font: "Noto Sans"
            }
        }
    }

    function initialize() {
        if (homeDir.length === 0) {
            errorMessage = "HOME is not set";
            return;
        }
        createConfigDir.running = true;
    }

    function reloadRuntimeSettings() {
        loadingRuntimeFile = true;
        runtimeSettingsFile.reload();
    }

    function createRuntimeSettingsFile() {
        creatingRuntimeFile = true;
        runtimeSettingsFile.writeAdapter();
    }

    function ensureLoadedWithDefaults() {
        if (isLoaded) {
            return;
        }

        isLoaded = true;
    }

    function handleRuntimeSettingsError(message) {
        errorMessage = message;
        console.warn("[Settings] " + message);
        settingsErrorNotifier.notify(message);
    }
}
