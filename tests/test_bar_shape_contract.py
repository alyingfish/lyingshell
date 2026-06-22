#!/usr/bin/env python3
"""Validate the Bar shape surface contract (floating/soft-attach/full-width/hug/hidden)."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BAR = ROOT / "Modules" / "Bar" / "Bar.qml"
SURFACE = ROOT / "Modules" / "Bar" / "BarSurface.qml"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> None:
    bar = read(BAR)
    surface = read(SURFACE)

    assert SURFACE.exists()

    # --- BarSurface: shape resolution -------------------------------------
    assert "import QtQuick.Shapes" in surface
    assert "import Qcm.Material as MD" in surface
    assert "Settings.options.bar.currentShape" in surface
    assert "readonly property var shapeOptions: Settings.options.bar.shape" in surface
    for name in ('"floating"', '"soft-attach"', '"full-width"', '"hug"', '"hidden"'):
        assert name in surface, name

    # Each shape's leaves are consumed from settings.
    assert "o.floating.cornerRadius" in surface
    assert "o.softAttach.topCornerRadius" in surface
    assert "o.softAttach.bottomCornerRadius" in surface
    assert "o.fullWidth.cornerRadius" in surface
    assert "o.hug.reversedCornerRadius" in surface

    # --- BarSurface: one continuous signed-bottom path generator ----------
    assert "function surfacePath(" in surface
    # Single signed bottom value morphs convex<->concave continuously.
    assert "animBottomRadius - animReversed" in surface
    # Concave wings use SVG sweep-flag 0; convex corners use sweep-flag 1.
    assert "0 0 0 " in surface
    assert "0 0 1 " in surface
    # hidden keeps the last visible shape's geometry while sliding away.
    assert "property string lastVisibleShape" in surface
    assert "if (shape !== \"hidden\") lastVisibleShape = shape" in surface

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

    # --- BarSurface: animated scalars all have Behaviors ------------------
    for scalar in ("animMargin", "animTopRadius", "animBottomRadius",
                   "animReversed", "animOpacity", "shadowElevation", "revealOffset"):
        assert "property real " + scalar in surface, scalar
        assert "Behavior on " + scalar in surface, scalar

    # Shadow buffer keeps the shadow/hug overhang from being clipped.
    assert "shadowBuffer" in surface

    # --- BarSurface: best-effort blur exposure ----------------------------
    assert "readonly property real blurSigma: config.blur" in surface
    assert "readonly property bool blurEnabled: blurSigma > 0" in surface
    assert "o.floating.blur" in surface

    # --- Bar.qml: window wiring -------------------------------------------
    assert "import Quickshell.Wayland" in bar
    assert 'color: "transparent"' in bar
    assert "implicitHeight: barSurface.totalHeight" in bar
    # Hidden collapses the exclusive zone; otherwise reserves margin + height.
    assert "barSurface.isHidden" in bar
    assert "? 0" in bar
    # Input mask + best-effort blur region track the visible surface.
    assert "mask: Region {" in bar
    assert "BackgroundEffect.blurRegion: barSurface.blurEnabled ? blurRegion : null" in bar
    assert "Region {" in bar
    assert "BarSurface {" in bar


if __name__ == "__main__":
    main()
