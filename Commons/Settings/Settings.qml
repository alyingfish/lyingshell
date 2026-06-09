pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isLoaded: false
    property bool directoriesReady: false
    property bool creatingRuntimeFile: false
    property string errorMessage: ""
    property string language: "en"
    property var settings: ({})
    property var defaultSettings: ({})

    readonly property QtObject bar: barSettings
    readonly property QtObject theme: themeSettings
    readonly property bool hasError: errorMessage.length > 0
    readonly property string homeDir: String(Quickshell.env("HOME") || "")
    readonly property string configDir: homeDir + "/.config/lyingshell"
    readonly property string settingsPath: configDir + "/settings.jsonc"
    readonly property string defaultSettingsPath: Quickshell.shellDir + "/Commons/Settings/default-settings.jsonc"

    signal settingsLoaded()
    signal settingsReloaded()
    signal settingsSaved()

    Component.onCompleted: initialize()

    QtObject {
        id: barSettings

        property real height: 34
    }

    QtObject {
        id: themeSettings

        property string mode: "system"
        property string accentColor: "#80cbc4"
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
        command: ["notify-send", "Lying Shell settings error", root.errorMessage]
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
            root.loadRuntimeSettings();
        }

        onSaved: {
            root.settingsSaved();
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

        try {
            defaultSettings = validateSettings(parseJsonc(defaultSettingsFile.text()), true);
        } catch (error) {
            errorMessage = "Failed to load default settings: " + errorMessageText(error);
            return;
        }

        createConfigDir.running = true;
    }

    function loadRuntimeSettings() {
        try {
            var parsed = validateSettings(parseJsonc(runtimeSettingsFile.text()), false);
            applySettings(deepMerge(defaultSettings, parsed));
        } catch (error) {
            ensureLoadedWithDefaults();
            handleRuntimeSettingsError("Failed to load settings: " + errorMessageText(error));
            return;
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
        barSettings.height = nextSettings.bar.height;
        themeSettings.mode = nextSettings.theme.mode;
        themeSettings.accentColor = nextSettings.theme.accentColor;
        errorMessage = "";
    }

    function createRuntimeSettingsFile() {
        creatingRuntimeFile = true;
        runtimeSettingsFile.setText(defaultSettingsFile.text());
    }

    function ensureLoadedWithDefaults() {
        if (isLoaded) {
            return;
        }

        applySettings(defaultSettings);
        isLoaded = true;
        settingsLoaded();
    }

    function handleRuntimeSettingsError(message) {
        errorMessage = message;
        console.warn("[Settings] " + message);

        if (settingsErrorNotifier.running) {
            settingsErrorNotifier.running = false;
        }

        settingsErrorNotifier.command = ["notify-send", "Lying Shell settings error", message];
        settingsErrorNotifier.running = true;
    }

    function parseJsonc(text) {
        return JSON.parse(stripJsonComments(text));
    }

    function stripJsonComments(text) {
        var result = "";
        var inString = false;
        var escaping = false;
        var inLineComment = false;
        var inBlockComment = false;

        for (var index = 0; index < text.length; index++) {
            var character = text[index];
            var nextCharacter = index + 1 < text.length ? text[index + 1] : "";

            if (inLineComment) {
                if (character === "\n" || character === "\r") {
                    inLineComment = false;
                    result += character;
                } else {
                    result += " ";
                }
                continue;
            }

            if (inBlockComment) {
                if (character === "*" && nextCharacter === "/") {
                    result += "  ";
                    index += 1;
                    inBlockComment = false;
                } else if (character === "\n" || character === "\r") {
                    result += character;
                } else {
                    result += " ";
                }
                continue;
            }

            if (inString) {
                result += character;
                if (escaping) {
                    escaping = false;
                } else if (character === "\\") {
                    escaping = true;
                } else if (character === "\"") {
                    inString = false;
                }
                continue;
            }

            if (character === "\"") {
                inString = true;
                result += character;
                continue;
            }

            if (character === "/" && nextCharacter === "/") {
                result += "  ";
                index += 1;
                inLineComment = true;
                continue;
            }

            if (character === "/" && nextCharacter === "*") {
                result += "  ";
                index += 1;
                inBlockComment = true;
                continue;
            }

            result += character;
        }

        if (inBlockComment) {
            throw new Error("unterminated block comment");
        }

        return result;
    }

    function validateSettings(raw, requireAllFields) {
        var schema = settingsSchema();
        return validateObject("settings", raw, schema, requireAllFields);
    }

    function settingsSchema() {
        return {
            "language": {
                "type": "string",
                "allowed": ["en", "zh-CN"]
            },
            "bar": {
                "type": "object",
                "properties": {
                    "height": {
                        "type": "number",
                        "minExclusive": 0
                    }
                }
            },
            "theme": {
                "type": "object",
                "properties": {
                    "mode": {
                        "type": "string",
                        "allowed": ["system", "light", "dark"]
                    },
                    "accentColor": {
                        "type": "string",
                        "pattern": /^#[0-9a-fA-F]{6}$/
                    }
                }
            }
        };
    }

    function validateObject(path, raw, schema, requireAllFields) {
        if (!isObject(raw)) {
            throw new Error(path + " must be an object");
        }

        for (var rawKey in raw) {
            if (schema[rawKey] === undefined) {
                throw new Error("unknown setting: " + path + "." + rawKey);
            }
        }

        var result = ({});
        for (var key in schema) {
            var definition = schema[key];
            if (raw[key] === undefined) {
                if (requireAllFields) {
                    throw new Error("missing required setting: " + path + "." + key);
                }

                continue;
            }

            if (definition.type === "object") {
                result[key] = validateObject(path + "." + key, raw[key], definition.properties, requireAllFields);
            } else {
                result[key] = validateScalar(path + "." + key, raw[key], definition);
            }
        }

        return result;
    }

    function validateScalar(path, value, definition) {
        if (definition.type === "string" && typeof value !== "string") {
            throw new Error(path + " must be a string");
        }

        if (definition.type === "number" && (typeof value !== "number" || !isFinite(value))) {
            throw new Error(path + " must be a finite number");
        }

        if (definition.allowed !== undefined && definition.allowed.indexOf(value) === -1) {
            throw new Error(path + " must be one of: " + definition.allowed.join(", "));
        }

        if (definition.minExclusive !== undefined && value <= definition.minExclusive) {
            throw new Error(path + " must be greater than " + definition.minExclusive);
        }

        if (definition.pattern !== undefined && !definition.pattern.test(value)) {
            throw new Error(path + " has invalid format");
        }

        return value;
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

    function errorMessageText(error) {
        if (error && error.message !== undefined) {
            return String(error.message);
        }

        return String(error);
    }
}
