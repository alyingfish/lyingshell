#!/usr/bin/env python3
"""Validate the settings registry and public API contract."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SETTINGS_DIR = ROOT / "Commons" / "Settings"
SETTINGS_QML = SETTINGS_DIR / "Settings.qml"
SETTINGS_SCHEMA = SETTINGS_DIR / "SettingsSchema.js"
REMOVED_SETTINGS_FILES = [
    SETTINGS_DIR / "Jsonc.js",
    SETTINGS_DIR / "SettingsStore.js",
    SETTINGS_DIR / "SettingsErrorNotifier.qml",
    SETTINGS_DIR / "default-settings.jsonc",
]

NODE_SETTINGS_SCRIPT = r"""
const fs = require("fs");
const vm = require("vm");

function loadSource(path) {
    return fs.readFileSync(path, "utf8")
        .split(/\r?\n/)
        .filter(line => !/^\s*\.(pragma|import)\b/.test(line))
        .join("\n");
}

const schemaPath = process.argv[2];
const command = process.argv[3];
const schema = {
    Array: Array,
    Error: Error,
    JSON: JSON,
    Object: Object,
    RegExp: RegExp,
    String: String,
    isFinite: isFinite
};

vm.createContext(schema);
vm.runInContext(loadSource(schemaPath), schema, { filename: schemaPath });

if (command === "snapshot") {
    console.log(JSON.stringify({
        defaults: schema.defaultSettings(),
        template: schema.defaultSettingsText(),
        generatedDefaults: schema.validate(schema.parseJsonc(schema.defaultSettingsText()), true)
    }));
} else if (command === "runtime") {
    console.log(JSON.stringify(schema.parseRuntime(process.argv[4])));
} else if (command === "parseJsonc") {
    console.log(JSON.stringify(schema.parseJsonc(process.argv[4])));
} else if (command === "mergeRuntime") {
    const runtime = schema.parseRuntime(process.argv[4]);
    console.log(JSON.stringify(schema.mergeDefaults(schema.defaultSettings(), runtime)));
} else {
    throw new Error("unknown command: " + command);
}
"""


def run_settings_js(command: str, *args: str) -> Any:
    result = subprocess.run(
        ["node", "-", str(SETTINGS_SCHEMA), command, *args],
        input=NODE_SETTINGS_SCRIPT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        details = result.stderr.strip() or result.stdout.strip()
        raise ValueError(details)

    return json.loads(result.stdout)


def expect_error(name: str, text: str) -> None:
    try:
        run_settings_js("runtime", text)
    except Exception:
        return
    raise AssertionError(f"{name} unexpectedly passed")


def main() -> None:
    settings_qml = SETTINGS_QML.read_text(encoding="utf-8")
    settings_schema = SETTINGS_SCHEMA.read_text(encoding="utf-8")
    schema_snapshot = run_settings_js("snapshot")

    assert SETTINGS_SCHEMA.exists()
    assert all(not path.exists() for path in REMOVED_SETTINGS_FILES)
    assert "readonly property QtObject options" in settings_qml
    assert 'import "SettingsSchema.js" as SettingsSchema' in settings_qml
    assert "SettingsStore" not in settings_qml
    assert "SettingsErrorNotifier" not in settings_qml
    assert "property var effectiveSettings" not in settings_qml
    assert "property var defaultSettings" not in settings_qml
    assert "signal settingsLoaded" not in settings_qml
    assert "signal settingsReloaded" not in settings_qml
    assert "signal settingsSaved" not in settings_qml

    assert "function parseRuntime(text)" in settings_schema
    assert "function mergeDefaults(defaultSettings, runtimeSettings)" in settings_schema
    assert "function parseJsonc(text)" in settings_schema
    assert "function leafPaths" not in settings_schema
    assert "function applyOptions" not in settings_schema
    assert "function getPath" not in settings_schema
    assert "function setPath" not in settings_schema
    assert "optionsSettings.language = nextSettings.language" in settings_qml
    assert "optionsSettings.theme.accentColor = nextSettings.theme.accentColor" in settings_qml

    default_settings = {
        "language": "en",
        "bar": {"height": 34},
        "theme": {"mode": "system", "accentColor": "#80cbc4"},
    }
    assert schema_snapshot["defaults"] == default_settings
    assert schema_snapshot["generatedDefaults"] == default_settings
    assert schema_snapshot["template"] == (
        "{\n"
        '  "language": "en",\n'
        '  "bar": {\n'
        '    "height": 34\n'
        "  },\n"
        '  "theme": {\n'
        '    "mode": "system",\n'
        '    "accentColor": "#80cbc4"\n'
        "  }\n"
        "}\n"
    )

    partial = run_settings_js("runtime", '{ "bar": { "height": 48 } } // user override\n')
    assert run_settings_js("mergeRuntime", '{ "bar": { "height": 48 } } // user override\n') == {
        "language": "en",
        "bar": {"height": 48},
        "theme": {"mode": "system", "accentColor": "#80cbc4"},
    }
    assert partial == {"bar": {"height": 48}}
    assert run_settings_js("runtime", '{ "theme": { "accentColor": "#aabbcc" }, "language": "zh-CN" }') == {
        "language": "zh-CN",
        "theme": {"accentColor": "#aabbcc"},
    }
    assert run_settings_js("parseJsonc", '{ "url": "https://example.test/*not-comment*/" }') == {
        "url": "https://example.test/*not-comment*/",
    }
    expect_error("unknown top-level field", '{ "extra": true }')
    expect_error("unknown nested field", '{ "bar": { "height": 34, "gap": 2 } }')
    expect_error("invalid language", '{ "language": "fr" }')
    expect_error("invalid bar height", '{ "bar": { "height": 0 } }')
    expect_error("invalid accent color", '{ "theme": { "accentColor": "teal" } }')
    expect_error("malformed jsonc", '{ "language": "en", }')
    expect_error("unterminated block comment", '{ /* broken ')


if __name__ == "__main__":
    main()
