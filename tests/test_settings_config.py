#!/usr/bin/env python3
"""Validate the settings public API contract."""

from __future__ import annotations

from pathlib import Path


def handler_body(source: str, marker: str) -> str:
    """Return the brace-balanced body that follows a ``marker`` in ``source``."""
    start = source.index(marker)
    open_brace = source.index("{", start)
    depth = 0
    for index in range(open_brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[open_brace : index + 1]
    raise AssertionError(f"unbalanced braces after {marker!r}")


ROOT = Path(__file__).resolve().parents[1]
SETTINGS_DIR = ROOT / "Commons" / "Settings"
SETTINGS_QML = SETTINGS_DIR / "Settings.qml"
SETTINGS_SCHEMA = SETTINGS_DIR / "SettingsSchema.js"
REMOVED_SETTINGS_FILES = [
    SETTINGS_DIR / "Jsonc.js",
    SETTINGS_SCHEMA,
    SETTINGS_DIR / "SettingsStore.js",
    SETTINGS_DIR / "SettingsErrorNotifier.qml",
    SETTINGS_DIR / "default-settings.jsonc",
]


def main() -> None:
    settings_qml = SETTINGS_QML.read_text(encoding="utf-8")

    assert all(not path.exists() for path in REMOVED_SETTINGS_FILES)
    assert 'import "SettingsSchema.js" as SettingsSchema' not in settings_qml
    assert "readonly property alias options: settingsAdapter" in settings_qml
    assert 'settingsPath: configDir + "/settings.json"' in settings_qml
    assert "settings.jsonc" not in settings_qml
    assert "JsonAdapter" in settings_qml
    assert "property JsonObject appearance" in settings_qml
    assert "property JsonObject bar" in settings_qml
    assert "property JsonObject quickSettings" in settings_qml
    lock_body = handler_body(settings_qml, "property JsonObject lock")
    assert "property string avatar" not in lock_body
    assert "property bool wallpaperZoom: true" in lock_body
    assert "property JsonObject shape" in settings_qml
    assert "property JsonObject floating" in settings_qml
    assert "property JsonObject softAttach" in settings_qml
    assert "property JsonObject fullWidth" in settings_qml
    assert "property JsonObject hug" in settings_qml
    # autoShape: state -> shape map nested under bar.shape; "" encodes null
    # (no switch on that state).
    shape_body = handler_body(settings_qml, "property JsonObject shape")
    assert "property JsonObject autoShape" in shape_body
    assert 'property string noWindowShape: "floating"' in settings_qml
    assert 'property string hasWindowShape: "fullWidth"' in settings_qml
    assert 'property string floatingWindowShape: "softAttach"' in settings_qml
    assert 'property string maximizedColumnShape: "hug"' in settings_qml
    assert 'property string overviewShape: "hidden"' in settings_qml
    # No lockscreenShape on purpose: the bar must not morph on lock/unlock —
    # while locked it is invisible and parked (Modules/Bar/Bar.qml), and the
    # desktop the unlock sweep reveals should already carry the bar in place.
    assert "lockscreenShape" not in settings_qml
    assert 'property string unfocusedOutputShape: ""' in settings_qml
    # Per-widget settings nest under bar.widgets / quickSettings.widgets.
    bar_widgets = handler_body(settings_qml, "property JsonObject widgets")
    assert "property JsonObject quickSettingsButton" in bar_widgets
    assert "property JsonObject tray" in bar_widgets
    assert "property JsonObject workspaces" in bar_widgets
    # Trailing colon keeps the marker from matching quickSettingsButton above.
    menu_body = handler_body(settings_qml, "property JsonObject quickSettings:")
    assert "property JsonObject nightLight" in menu_body
    # Color-picker recents live under quickSettings, not widgets: they are
    # feature history, not a widget's tunable.
    assert "property JsonObject colorPicker" in menu_body
    assert "property var recentColors: []" in menu_body
    assert "runtimeSettingsFile.writeAdapter()" in settings_qml
    assert "onAdapterUpdated" in settings_qml
    assert "function reloadRuntimeSettings()" in settings_qml
    assert "SettingsStore" not in settings_qml
    assert "SettingsErrorNotifier" not in settings_qml
    assert "property var effectiveSettings" not in settings_qml
    assert "property var defaultSettings" not in settings_qml
    assert "signal settingsLoaded" not in settings_qml
    assert "signal settingsReloaded" not in settings_qml
    assert "signal settingsSaved" not in settings_qml
    assert "parseJsonc" not in settings_qml
    assert "parseRuntime" not in settings_qml
    assert "mergeDefaults" not in settings_qml

    assert 'property string language: "en"' in settings_qml
    # Bar height is per-shape (and int) since the settings-driven shape work.
    assert "property int height: 32" in settings_qml
    assert 'property string currentShape: "autoShape"' in settings_qml
    assert "property int margin: 8" in settings_qml
    assert "property int radius: 16" in settings_qml
    assert "property int radius: 0" in settings_qml
    assert "property real elevation: 3" in settings_qml
    assert "property real elevation: 0" in settings_qml
    assert "property real opacity: 0.92" in settings_qml
    # Per-shape blur is an on/off compositor toggle, not a strength.
    assert "property bool blur: true" in settings_qml
    assert "property real opacity: 1.0" in settings_qml
    assert "property bool blur: false" in settings_qml
    assert "property bool scrollLoop: true" in settings_qml
    assert "property bool urgentPulse: true" in settings_qml
    appearance_body = handler_body(settings_qml, "property JsonObject appearance")
    assert 'property string language: "en"' in appearance_body
    assert 'property string mode: "light"' in appearance_body
    assert 'property string accentColor: "#6750A4"' in appearance_body
    assert 'property string font: "Noto Sans"' in appearance_body
    assert "property bool useWallpaperColor: true" in appearance_body

    # Missing-file branch creates the file (via the async config-dir mkdir,
    # whose onExited writes the defaults); corrupt/IO error branch must not
    # overwrite the bad file, only fall back to in-memory defaults.
    load_failed = handler_body(settings_qml, "onLoadFailed:")
    assert "FileViewError.FileNotFound" in load_failed
    assert "createConfigDir.running = true" in load_failed
    assert "ensureLoadedWithDefaults()" in load_failed
    assert "writeAdapter" not in load_failed
    mkdir_exited = handler_body(settings_qml, "onExited: function(exitCode")
    assert "createRuntimeSettingsFile()" in mkdir_exited
    assert "ensureLoadedWithDefaults()" in mkdir_exited

    save_failed = handler_body(settings_qml, "onSaveFailed:")
    assert "ensureLoadedWithDefaults()" in save_failed
    assert "writeAdapter" not in save_failed


if __name__ == "__main__":
    main()
