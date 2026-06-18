pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "SettingsSchema.js" as SettingsSchema

Singleton {
    id: root

    property bool isLoaded: false
    property bool directoriesReady: false
    property bool creatingRuntimeFile: false
    property string errorMessage: ""

    readonly property QtObject options: optionsSettings
    readonly property bool hasError: errorMessage.length > 0
    readonly property string homeDir: String(Quickshell.env("HOME") || "")
    readonly property string configDir: homeDir + "/.config/lyingshell"
    readonly property string settingsPath: configDir + "/settings.jsonc"

    Component.onCompleted: initialize()

    QtObject {
        id: optionsSettings

        property string language: "en"
        readonly property QtObject bar: QtObject {
            property real height: 34
        }
        readonly property QtObject theme: QtObject {
            property string mode: "system"
            property string accentColor: "#80cbc4"
        }
    }

    Timer {
        id: externalReloadTimer
        interval: 160
        repeat: false

        onTriggered: {
            if (runtimeSettingsFile.path.length > 0) {
                runtimeSettingsFile.reload();
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
            root.loadRuntimeSettings();
        }

        onSaved: {
            if (root.creatingRuntimeFile) {
                root.creatingRuntimeFile = false;
                reload();
            }
        }

        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                root.createRuntimeSettingsFile();
                return;
            }

            root.ensureLoadedWithDefaults();
            root.handleRuntimeSettingsError("Failed to load settings: " + FileViewError.toString(error));
        }

        onSaveFailed: function(error) {
            root.creatingRuntimeFile = false;
            root.ensureLoadedWithDefaults();
            root.handleRuntimeSettingsError("Failed to create settings file: " + FileViewError.toString(error));
        }
    }

    function initialize() {
        if (homeDir.length === 0) {
            errorMessage = "HOME is not set";
            return;
        }
        createConfigDir.running = true;
    }

    function loadRuntimeSettings() {
        try {
            var defaults = SettingsSchema.defaultSettings();
            var parsed = SettingsSchema.parseRuntime(runtimeSettingsFile.text());
            applySettings(SettingsSchema.mergeDefaults(defaults, parsed));
        } catch (error) {
            ensureLoadedWithDefaults();
            handleRuntimeSettingsError("Failed to load settings: " + SettingsSchema.errorMessageText(error));
            return;
        }

        if (!isLoaded) {
            isLoaded = true;
        }
    }

    function applySettings(nextSettings) {
        optionsSettings.language = nextSettings.language;
        optionsSettings.bar.height = nextSettings.bar.height;
        optionsSettings.theme.mode = nextSettings.theme.mode;
        optionsSettings.theme.accentColor = nextSettings.theme.accentColor;
        errorMessage = "";
    }

    function createRuntimeSettingsFile() {
        creatingRuntimeFile = true;
        runtimeSettingsFile.setText(SettingsSchema.defaultSettingsText());
    }

    function ensureLoadedWithDefaults() {
        if (isLoaded) {
            return;
        }

        try {
            applySettings(SettingsSchema.defaultSettings());
            isLoaded = true;
        } catch (error) {
            errorMessage = "Failed to load default settings: " + SettingsSchema.errorMessageText(error);
        }
    }

    function handleRuntimeSettingsError(message) {
        errorMessage = message;
        console.warn("[Settings] " + message);
        settingsErrorNotifier.notify(message);
    }
}
