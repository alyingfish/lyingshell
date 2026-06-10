.pragma library

function schema() {
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

function validate(raw, requireAllFields) {
    return validateObject("settings", raw, schema(), requireAllFields);
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

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}
