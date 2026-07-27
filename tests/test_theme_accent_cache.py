#!/usr/bin/env python3
"""Guard the wallpaper-accent cache that prevents the startup color flash.

Structural test (mirrors test_settings_config.py): the flash is avoided by a
cache-driven *binding* (so the color is present on the first frame, not seeded
imperatively after an async settings load) plus a path key (so a warm cache
means no matugen at boot). A refactor that breaks either would reintroduce the
flicker, so pin both to the QML source.
"""

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
THEME_QML = ROOT / "Commons" / "Theme" / "Theme.qml"


def main() -> None:
    theme = THEME_QML.read_text(encoding="utf-8")

    # Cache lives under XDG_CACHE_HOME/.cache, in wallpaper-accent.json, read
    # synchronously so the binding has the color before the first frame.
    assert "XDG_CACHE_HOME" in theme
    assert '"/wallpaper-accent.json"' in theme
    assert "blockLoading: true" in theme

    # Path-keyed, per-mode cache.
    adapter = handler_body(theme, "adapter: JsonAdapter")
    assert 'property string path: ""' in adapter
    assert 'property string light: ""' in adapter
    assert 'property string dark: ""' in adapter

    # wallpaperAccent is a REACTIVE binding on the cache (not imperatively
    # seeded), so it is populated on frame 1 regardless of async settings load.
    assert "readonly property string wallpaperAccent:" in theme
    assert "accentCacheData.dark" in theme
    assert "accentCacheData.light" in theme
    # No imperative writes to wallpaperAccent anywhere (it must stay derived).
    assert "root.wallpaperAccent =" not in theme
    assert "wallpaperAccent = " not in theme

    # Derivation is gated on a stale cache for the current wallpaper, so a warm
    # cache skips matugen at boot but a real wallpaper change still derives. Both
    # modes must be cached to count as warm: gating on only the active mode left
    # the other one empty, so a later mode flip fell back to accentColor.
    needs = handler_body(theme, "function needsDerive")
    assert "useWallpaperColor" in needs
    assert "accentCacheData.path === wp" in needs
    assert "accentCacheData.light.length" in needs
    assert "accentCacheData.dark.length" in needs
    maybe = handler_body(theme, "function maybeExtractFromWallpaper")
    assert "needsDerive()" in maybe

    # One extraction seeds BOTH modes (matugen's JSON carries light and dark for
    # any -m), persisted through the path-keyed writer; no imperative accent write.
    exited = handler_body(theme, "onExited: function")
    assert 'root.parseAccent(stdout.text, "light")' in exited
    assert 'root.parseAccent(stdout.text, "dark")' in exited
    # Keyed to the image the colors came from, not whatever is current on exit.
    assert "cacheAccent(sourcePath, light, dark)" in exited
    cache_fn = handler_body(theme, "function cacheAccent")
    assert "accentCacheData.path = path" in cache_fn
    assert "accentCacheData.light = light" in cache_fn
    assert "accentCacheData.dark = dark" in cache_fn
    assert "writeAdapter()" in cache_fn

    print("PASS")


if __name__ == "__main__":
    main()
