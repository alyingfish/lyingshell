.pragma library

function registry() {
    return {
        "language": {
            "type": "string",
            "defaultValue": "en",
            "allowed": ["en", "zh-CN"]
        },
        "bar": {
            "type": "object",
            "properties": {
                "height": {
                    "type": "number",
                    "defaultValue": 34,
                    "minExclusive": 0
                }
            }
        },
        "theme": {
            "type": "object",
            "properties": {
                "mode": {
                    "type": "string",
                    "defaultValue": "system",
                    "allowed": ["system", "light", "dark"]
                },
                "accentColor": {
                    "type": "string",
                    "defaultValue": "#80cbc4",
                    "pattern": /^#[0-9a-fA-F]{6}$/
                }
            }
        }
    };
}

function validate(raw, requireAllFields) {
    return validateObject("settings", raw, registry(), requireAllFields);
}

function parseRuntime(text) {
    return validate(parseJsonc(text), false);
}

function defaultSettings() {
    return validate(defaultSettingsObject(registry()), true);
}

function defaultSettingsText() {
    return JSON.stringify(defaultSettings(), null, 2) + "\n";
}

function mergeDefaults(defaultSettings, runtimeSettings) {
    return deepMerge(defaultSettings, runtimeSettings);
}

function parseJsonc(text) {
    return JSON.parse(stripComments(text));
}

function stripComments(text) {
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

function defaultSettingsObject(objectSchema) {
    var result = ({});
    for (var key in objectSchema) {
        var definition = objectSchema[key];
        result[key] = definition.type === "object"
            ? defaultSettingsObject(definition.properties)
            : definition.defaultValue;
    }

    return result;
}

function validateObject(path, raw, objectSchema, requireAllFields) {
    if (!isObject(raw)) {
        throw new Error(path + " must be an object");
    }

    for (var rawKey in raw) {
        if (objectSchema[rawKey] === undefined) {
            throw new Error("unknown setting: " + path + "." + rawKey);
        }
    }

    var result = ({});
    for (var key in objectSchema) {
        var definition = objectSchema[key];
        if (raw[key] === undefined) {
            if (requireAllFields) {
                throw new Error("missing required setting: " + path + "." + key);
            }

            continue;
        }

        result[key] = definition.type === "object"
            ? validateObject(path + "." + key, raw[key], definition.properties, requireAllFields)
            : validateScalar(path + "." + key, raw[key], definition);
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

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function errorMessageText(error) {
    return error && error.message !== undefined ? String(error.message) : String(error);
}
