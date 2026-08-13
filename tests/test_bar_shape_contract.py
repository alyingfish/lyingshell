#!/usr/bin/env python3
"""Validate the Bar shape surface contract (floating/softAttach/fullWidth/hug/hidden)."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BAR = ROOT / "Modules" / "Bar" / "Bar.qml"
SURFACE = ROOT / "Modules" / "Bar" / "BarSurface.qml"
MOTION = ROOT / "Modules" / "Bar" / "BarMotion.js"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> None:
    bar = read(BAR)
    surface = read(SURFACE)
    motion = read(MOTION)

    assert SURFACE.exists()

    # --- BarSurface: shape resolution -------------------------------------
    assert "import QtQuick.Shapes" in surface
    assert "import Qcm.Material as MD" in surface
    assert "Settings.options.bar.currentShape" in surface
    assert "readonly property var shapeOptions: Settings.options.bar.shape" in surface
    # fullWidth is the unquoted fallback target (shapeOptions.fullWidth); the
    # rest are matched by name in the geometry bindings.
    for name in ('"floating"', '"softAttach"', '"hug"', '"hidden"'):
        assert name in surface, name

    # Uniform settings: the active shape's object is indexed by name (fullWidth
    # fallback) and its leaves consumed directly, no per-shape resolver.
    assert "resolveConfig" not in surface
    assert "shapeOptions[activeShape]" in surface
    assert "shapeOptions.fullWidth" in surface
    for leaf in ("config.margin", "config.radius", "config.opacity",
                 "config.elevation", "config.blur"):
        assert leaf in surface, leaf
    # The single `radius` lands per shape: softAttach/hug square the top,
    # hug squares the bottom and drives the reversed concave wings.
    assert 'activeShape === "softAttach" || activeShape === "hug" ? 0 : config.radius' in surface
    assert 'activeShape === "hug" ? 0 : config.radius' in surface
    assert 'activeShape === "hug" ? config.radius : 0' in surface

    # --- BarSurface: one continuous signed-bottom path generator ----------
    assert "function surfacePath(" in surface
    # Single signed bottom value morphs convex<->concave continuously.
    assert "animBottomRadius - animReversed" in surface
    # Concave wings use SVG sweep-flag 0; convex corners use sweep-flag 1.
    assert "0 0 0 " in surface
    assert "0 0 1 " in surface
    # hidden keeps the last visible shape's geometry while sliding away. The
    # offset is shared with lock-screen bar continuations and clears the whole
    # surface plus its shadow rather than using a viewport-relative guess.
    assert "property string lastVisibleShape" in surface
    assert "if (shape !== \"hidden\") lastVisibleShape = shape" in " ".join(surface.split())
    assert "BarMotion.hiddenOffset(animMargin, barHeight)" in surface
    assert "var shadowBuffer = 24;" in motion
    assert "var hiddenClearance = 8;" in motion

    # --- BarSurface: MD3 tokens + directional drop shadow -----------------
    assert "MD.Token.duration." in surface
    assert "MD.Token.easing." in surface
    assert "MD.Token.color.surface_container" in surface
    assert "MD.Token.color.shadow" in surface
    # MD3 elevation via QmlMaterial's own RRectShadowImpl (Skia ambient + spot
    # model). Every shape feeds the SAME component, differing only in corner
    # radius and the user-configurable per-shape `elevation` (dp). Depth is
    # driven by the animated radii + the animated shadowElevation scalar.
    assert "MD.RRectShadowImpl" in surface
    assert "elevation: root.shadowElevation" in surface
    assert "property real shadowElevation: config.elevation" in surface
    # The shadow fade MUST ride on elevation, not color alpha: RRectShadowImpl
    # drops the color alpha (QColor::rgb()) before rendering, so a color-alpha
    # fade is a no-op. A shape with elevation 0 renders no shadow; `visible`
    # culls only once the depth eases to ~0.
    assert "visible: root.shadowElevation > 0.001" in surface
    assert "MD.Util.corners(" in surface
    # Fill painted once on top of the shadow.
    assert "id: surfaceFill" in surface
    # Opacity is fill-alpha, not item opacity.
    assert "Qt.rgba(" in surface
    assert "fillColor:" in surface

    # --- BarSurface: shape scalars + live visibility spring ---------------
    for scalar in ("animMargin", "animTopRadius", "animBottomRadius",
                   "animReversed", "animOpacity", "shadowElevation"):
        assert "property real " + scalar in surface, scalar
        assert "Behavior on " + scalar in surface, scalar
    # Visibility can reverse as overview changes. It therefore uses the live
    # default-spatial M3E spring, retaining velocity instead of replaying a
    # duration curve from rest.
    assert "readonly property real revealOffset:" in surface
    assert "MotionSpring {" in surface
    assert "spring: Motion.spatialDefault" in surface
    assert "Behavior on revealOffset" not in surface

    # Shadow buffer keeps the shadow/hug overhang from being clipped.
    assert "shadowBuffer" in surface

    # --- BarSurface: best-effort blur exposure ----------------------------
    # Per-shape `blur` is an on/off gate (strength is the compositor's) and is
    # authoritative: translucency alone never turns blur on. Leaving a blurred
    # shape for an opaque one lingers the region so blur exits under the fade
    # instead of popping off at frame 0.
    assert "readonly property bool blurConfigured: config.blur" in surface
    assert "property bool blurLinger: false" in surface
    assert "readonly property bool blurEnabled: (blurConfigured || blurLinger) && animOpacity < 0.999" in surface

    # --- Bar.qml: window wiring -------------------------------------------
    assert "import Quickshell.Wayland" in bar
    assert 'color: "transparent"' in bar
    # Settled-size window, full-screen while a bar overlay (tray popover/drag
    # or quick-settings panel) is active.
    assert "barSurface.config.margin + barSurface.barHeight" in bar
    # Tray and quick settings sit behind Loaders since the startup-latency work,
    # so the overlay contract reads through .item with a collapsed fallback.
    assert "readonly property bool overlayExpanded:" in bar
    assert "systemTrayLoader.item ? systemTrayLoader.item.expanded : false" in bar
    assert "quickSettingsLoader.item ? quickSettingsLoader.item.expanded : false" in bar
    assert "overlayExpanded && root.screen ? root.screen.height" in bar
    assert "systemTrayLoader.item.collapsedReserve" in bar
    # Exclusive zone stays constant across hide/floating to avoid reflow stutter:
    # Bar delegates to BarSurface, which picks the hidden or active shape's zone.
    assert "exclusiveZone: barSurface.exclusiveZone" in bar
    assert (
        "readonly property int exclusiveZone: isHidden ? shapeOptions.hidden.exclusiveZone : config.exclusiveZone"
        in surface
    )
    # Input mask tracks the visible surface; overlay-expanded takes the window.
    assert "mask: overlayExpanded ? null : barMask" in bar
    assert "BackgroundEffect.blurRegion: barSurface.blurEnabled ? blurRegion : null" in bar
    assert "Region {" in bar
    assert "BarSurface {" in bar


if __name__ == "__main__":
    main()
