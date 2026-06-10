#!/usr/bin/env python3
"""Validate the Settings.qml JSONC schema contract."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SETTINGS = ROOT / "Commons" / "Settings" / "default-settings.jsonc"

SCHEMA: dict[str, Any] = {
    "language": {
        "type": "string",
        "allowed": ["en", "zh-CN"],
    },
    "bar": {
        "type": "object",
        "properties": {
            "height": {
                "type": "number",
                "min_exclusive": 0,
            },
        },
    },
    "theme": {
        "type": "object",
        "properties": {
            "mode": {
                "type": "string",
                "allowed": ["system", "light", "dark"],
            },
            "accentColor": {
                "type": "string",
                "pattern": "hex_color",
            },
        },
    },
}


def strip_json_comments(text: str) -> str:
    result: list[str] = []
    in_string = False
    escaping = False
    in_line_comment = False
    in_block_comment = False
    index = 0

    while index < len(text):
        character = text[index]
        next_character = text[index + 1] if index + 1 < len(text) else ""

        if in_line_comment:
            if character in "\n\r":
                in_line_comment = False
                result.append(character)
            else:
                result.append(" ")
            index += 1
            continue

        if in_block_comment:
            if character == "*" and next_character == "/":
                result.append("  ")
                index += 2
                in_block_comment = False
            else:
                result.append(character if character in "\n\r" else " ")
                index += 1
            continue

        if in_string:
            result.append(character)
            if escaping:
                escaping = False
            elif character == "\\":
                escaping = True
            elif character == '"':
                in_string = False
            index += 1
            continue

        if character == '"':
            in_string = True
            result.append(character)
            index += 1
            continue

        if character == "/" and next_character == "/":
            result.append("  ")
            index += 2
            in_line_comment = True
            continue

        if character == "/" and next_character == "*":
            result.append("  ")
            index += 2
            in_block_comment = True
            continue

        result.append(character)
        index += 1

    if in_block_comment:
        raise ValueError("unterminated block comment")

    return "".join(result)


def parse_jsonc(text: str) -> Any:
    return json.loads(strip_json_comments(text))


def validate_settings(raw: Any, require_all_fields: bool) -> dict[str, Any]:
    return validate_object("settings", raw, SCHEMA, require_all_fields)


def validate_object(
    path: str,
    raw: Any,
    schema: dict[str, Any],
    require_all_fields: bool,
) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise ValueError(f"{path} must be an object")

    for key in raw:
        if key not in schema:
            raise ValueError(f"unknown setting: {path}.{key}")

    result: dict[str, Any] = {}
    for key, definition in schema.items():
        if key not in raw:
            if require_all_fields:
                raise ValueError(f"missing required setting: {path}.{key}")
            continue

        if definition["type"] == "object":
            result[key] = validate_object(
                f"{path}.{key}",
                raw[key],
                definition["properties"],
                require_all_fields,
            )
        else:
            result[key] = validate_scalar(f"{path}.{key}", raw[key], definition)

    return result


def validate_scalar(path: str, value: Any, definition: dict[str, Any]) -> Any:
    if definition["type"] == "string" and not isinstance(value, str):
        raise ValueError(f"{path} must be a string")

    if definition["type"] == "number":
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            raise ValueError(f"{path} must be a finite number")

    if "allowed" in definition and value not in definition["allowed"]:
        raise ValueError(f"{path} must be one of: {', '.join(definition['allowed'])}")

    if "min_exclusive" in definition and value <= definition["min_exclusive"]:
        raise ValueError(f"{path} must be greater than {definition['min_exclusive']}")

    if definition.get("pattern") == "hex_color":
        if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
            raise ValueError(f"{path} has invalid format")
        int(value[1:], 16)

    return value


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    result = {
        key: deep_merge(value, {}) if isinstance(value, dict) else value
        for key, value in base.items()
    }

    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value

    return result


def expect_error(name: str, text: str) -> None:
    try:
        validate_settings(parse_jsonc(text), require_all_fields=False)
    except Exception:
        return
    raise AssertionError(f"{name} unexpectedly passed")


def main() -> None:
    default_settings = validate_settings(
        parse_jsonc(DEFAULT_SETTINGS.read_text(encoding="utf-8")),
        require_all_fields=True,
    )
    assert default_settings == {
        "language": "en",
        "bar": {"height": 34},
        "theme": {"mode": "system", "accentColor": "#80cbc4"},
    }

    partial = validate_settings(
        parse_jsonc('{ "bar": { "height": 48 } } // user override\n'),
        require_all_fields=False,
    )
    assert deep_merge(default_settings, partial)["bar"]["height"] == 48
    assert deep_merge(default_settings, partial)["language"] == "en"
    assert parse_jsonc('{ "url": "https://example.test/*not-comment*/" }') == {
        "url": "https://example.test/*not-comment*/",
    }

    with_comment_markers_in_string = validate_settings(
        parse_jsonc('{ "theme": { "accentColor": "#aabbcc" }, "language": "zh-CN" }'),
        require_all_fields=False,
    )
    assert with_comment_markers_in_string["theme"]["accentColor"] == "#aabbcc"

    expect_error("unknown top-level field", '{ "extra": true }')
    expect_error("unknown nested field", '{ "bar": { "height": 34, "gap": 2 } }')
    expect_error("invalid language", '{ "language": "fr" }')
    expect_error("invalid bar height", '{ "bar": { "height": 0 } }')
    expect_error("invalid accent color", '{ "theme": { "accentColor": "teal" } }')
    expect_error("malformed jsonc", '{ "language": "en", }')
    expect_error("unterminated block comment", '{ /* broken ')


if __name__ == "__main__":
    main()
