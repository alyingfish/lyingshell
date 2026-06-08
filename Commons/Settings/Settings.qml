pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isLoaded: false
    property bool directoriesReady: false
    property string errorMessage: ""
    property string language: "en"
    property real barHeight: 34
    property string themeMode: "system"
    property string accentColor: "#80cbc4"
    property var settings: ({})
    property var defaultSettings: ({})

    readonly property bool hasError: errorMessage.length > 0
    readonly property string homeDir: String(Quickshell.env("HOME") || "")
    readonly property string configDir: homeDir + "/.config/lyingshell"
    readonly property string settingsPath: configDir + "/settings.json"
    readonly property string defaultSettingsPath: Quickshell.shellDir + "/Commons/Settings/default-settings.json"

    signal settingsLoaded()
    signal settingsReloaded()
    signal settingsSaved()

    Component.onCompleted: initialize()

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
                root.errorMessage = "Failed to create settings directory";
            }

            root.directoriesReady = true;
        }
    }

    FileView {
        id: defaultSettingsFile
        path: root.defaultSettingsPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: runtimeSettingsFile
        path: root.directoriesReady ? root.settingsPath : ""
        printErrors: false
        watchChanges: true

        onFileChanged: externalReloadTimer.restart()

        onLoaded: {
            root.loadRuntimeSettings(false);
        }

        onSaved: {
            root.settingsSaved();
            if (!root.isLoaded) {
                reload();
            }
        }

        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound) {
                root.writeSettings(root.defaultSettings);
                return;
            }

            root.errorMessage = "Failed to load settings";
        }
    }

    function initialize() {
        if (homeDir.length === 0) {
            errorMessage = "HOME is not set";
            return;
        }

        try {
            defaultSettings = normalizeSettings(JSON.parse(defaultSettingsFile.text()));
        } catch (error) {
            errorMessage = "Failed to parse default settings";
            return;
        }

        createConfigDir.running = true;
    }

    function loadRuntimeSettings(writeMerged) {
        var parsed = ({});

        try {
            parsed = JSON.parse(runtimeSettingsFile.text());
        } catch (error) {
            errorMessage = "Failed to parse settings";
            parsed = ({});
            writeMerged = true;
        }

        var merged = normalizeSettings(deepMerge(defaultSettings, parsed));
        applySettings(merged);

        if (writeMerged || needsRepair(parsed, merged)) {
            writeSettings(merged);
        }

        if (!isLoaded) {
            isLoaded = true;
            settingsLoaded();
        } else {
            settingsReloaded();
        }
    }

    function applySettings(nextSettings) {
        settings = nextSettings;
        language = nextSettings.language;
        barHeight = nextSettings.bar.height;
        themeMode = nextSettings.theme.mode;
        accentColor = nextSettings.theme.accentColor;
        errorMessage = "";
    }

    function writeSettings(nextSettings) {
        runtimeSettingsFile.setText(JSON.stringify(nextSettings, null, 2) + "\n");
    }

    function normalizeSettings(raw) {
        var source = isObject(raw) ? raw : ({});
        var bar = isObject(source.bar) ? source.bar : ({});
        var theme = isObject(source.theme) ? source.theme : ({});

        return {
            "language": normalizeLanguage(source.language),
            "bar": {
                "height": normalizeBarHeight(bar.height)
            },
            "theme": {
                "mode": normalizeThemeMode(theme.mode),
                "accentColor": normalizeAccentColor(theme.accentColor)
            }
        };
    }

    function normalizeLanguage(value) {
        if (typeof value !== "string") {
            return "en";
        }

        if (value === "en" || value === "zh-CN") {
            return value;
        }

        return "en";
    }

    function normalizeBarHeight(value) {
        if (typeof value === "number" && isFinite(value) && value > 0) {
            return value;
        }

        return 34;
    }

    function normalizeThemeMode(value) {
        if (value === "light" || value === "dark" || value === "system") {
            return value;
        }

        return "system";
    }

    function normalizeAccentColor(value) {
        if (typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)) {
            return value;
        }

        return "#80cbc4";
    }

    function needsRepair(raw, normalized) {
        if (!isObject(raw) || !isObject(raw.bar) || !isObject(raw.theme)) {
            return true;
        }

        return raw.language !== normalized.language
            || raw.bar.height !== normalized.bar.height
            || raw.theme.mode !== normalized.theme.mode
            || raw.theme.accentColor !== normalized.theme.accentColor;
    }

    function deepMerge(base, override) {
        var result = cloneObject(base);
        if (!isObject(override)) {
            return result;
        }

        for (var key in override) {
            if (isObject(override[key]) && isObject(result[key])) {
                result[key] = deepMerge(result[key], override[key]);
            } else {
                result[key] = override[key];
            }
        }

        return result;
    }

    function cloneObject(value) {
        if (!isObject(value)) {
            return value;
        }

        var result = ({});
        for (var key in value) {
            result[key] = isObject(value[key]) ? cloneObject(value[key]) : value[key];
        }

        return result;
    }

    function isObject(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value);
    }
}
