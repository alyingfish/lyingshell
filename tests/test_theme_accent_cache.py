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
    # blockLoading alone does NOT make it synchronous — it only makes
    # text()/data() block — so the load is forced with an explicit text() call
    # at startup. Without it the adapter is still empty in Component.onCompleted
    # and the cached accent lands a tick or more later, after the first
    # apply/push: default seed on the first frames, and a full matugen regen of
    # every app theme in the wrong color before the right one follows.
    assert "XDG_CACHE_HOME" in theme
    assert '"/wallpaper-accent.json"' in theme
    assert "blockLoading: true" in theme
    completed = handler_body(theme, "Component.onCompleted")
    assert "accentCache.text();" in completed

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

    # The imperative appliers read the fresh-value helpers, NEVER the derived
    # properties. A property derived from another lags inside a change handler
    # for one of its own dependencies, because QML evaluates bindings lazily: in
    # onRequestedAccentColorChanged, requestedAccentColor already holds the new
    # color while effectiveAccentColor still holds the previous one. apply()
    # reading the property therefore seeded the process with the PREVIOUS accent
    # while pushAccentColor() sent the new one to every external app — shell on
    # #6750A4, kitty/GTK/niri on the wallpaper color, until the next mode flip.
    apply_fn = handler_body(theme, "function apply()")
    assert "MD.Token.color.accentColor = effectiveAccentNow();" in apply_fn
    assert "modeNow()" in apply_fn
    assert "effectiveAccentColor" not in apply_fn
    assert "effectiveMode" not in apply_fn
    push_fn = handler_body(theme, "function pushAccentColor")
    assert "accentPush.run(requestedAccentNow(), modeNow(), matugenDir);" in push_fn
    assert "requestedAccentColor" not in push_fn

    # The helpers themselves read only source properties (the cache adapter, the
    # settings adapter, accentOverride), which is what makes them current; the
    # bindings above delegate to them, so there is one rule and one source.
    assert "readonly property string effectiveMode: modeNow()" in theme
    assert "readonly property string wallpaperAccent: wallpaperAccentNow()" in theme
    assert "readonly property string requestedAccentColor: requestedAccentNow()" in theme
    assert "readonly property string effectiveAccentColor: effectiveAccentNow()" in theme
    mode_fn = handler_body(theme, "function modeNow")
    assert "Settings.options.appearance.mode" in mode_fn
    wallpaper_fn = handler_body(theme, "function wallpaperAccentNow")
    assert "accentCacheData.dark" in wallpaper_fn
    assert "accentCacheData.light" in wallpaper_fn
    requested_fn = handler_body(theme, "function requestedAccentNow")
    assert "wallpaperAccentNow()" in requested_fn
    assert "Settings.options.appearance.useWallpaperColor" in requested_fn
    assert "Settings.options.appearance.accentColor" in requested_fn
    effective_fn = handler_body(theme, "function effectiveAccentNow")
    assert "accentOverride.length > 0 ? accentOverride : requestedAccentNow()" in effective_fn

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
