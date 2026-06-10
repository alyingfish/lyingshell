.pragma library

.import "Jsonc.js" as Jsonc
.import "SettingsSchema.js" as Schema

function parseDefaults(text) {
    return Schema.validate(Jsonc.parse(text), true);
}

function parseRuntime(text) {
    return Schema.validate(Jsonc.parse(text), false);
}

function mergeDefaults(defaultSettings, runtimeSettings) {
    return deepMerge(defaultSettings, runtimeSettings);
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
