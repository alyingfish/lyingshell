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

    # --- BarSurface: geometry + path generators ---------------------------
    assert "function rectPath(" in surface
    assert "function hugPath(" in surface
    assert "function surfacePath(" in surface
    # Concave fillets use SVG sweep-flag 0; convex corners use sweep-flag 1.
    assert "0 0 0 " in surface
    assert "0 0 1 " in surface
    # hug renders only while the reversed radius is non-trivial.
    assert "animReversed > 0.01" in surface

    # --- BarSurface: MD3 tokens for motion, elevation, color --------------
    assert "MD.Token.duration." in surface
    assert "MD.Token.easing." in surface
    assert "MD.Token.elevation.level2" in surface
    assert "MD.Token.elevation.level0" in surface
    assert "MD.Token.color.surface_container" in surface
    assert "MD.Elevation" in surface
    assert "MD.Util.corners(" in surface
    # Opacity is fill-alpha, not item opacity.
    assert "Qt.rgba(" in surface
    assert "fillColor:" in surface

    # --- BarSurface: animated scalars all have Behaviors ------------------
    for scalar in ("animMargin", "animTopRadius", "animBottomRadius",
                   "animReversed", "animOpacity", "animElevation", "revealOffset"):
        assert "property real " + scalar in surface, scalar
        assert "Behavior on " + scalar in surface, scalar

    # Shadow buffer keeps the elevation/hug overhang from being clipped.
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
