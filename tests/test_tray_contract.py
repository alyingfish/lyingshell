#!/usr/bin/env python3
"""Validate the system tray widget contract against the UX spec."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SETTINGS_QML = ROOT / "Commons" / "Settings" / "Settings.qml"
SYSTEM_TRAY = ROOT / "Modules" / "Bar" / "Widgets" / "SystemTray.qml"
TRAY_BUTTON = ROOT / "Modules" / "Bar" / "Widgets" / "TrayItemButton.qml"
TRAY_PINNING = ROOT / "Modules" / "Bar" / "Widgets" / "TrayPinning.js"
BAR_QML = ROOT / "Modules" / "Bar" / "Bar.qml"
SHELL_QML = ROOT / "shell.qml"


def main() -> None:
    settings = SETTINGS_QML.read_text(encoding="utf-8")
    tray = SYSTEM_TRAY.read_text(encoding="utf-8")
    button = TRAY_BUTTON.read_text(encoding="utf-8")
    pinning = TRAY_PINNING.read_text(encoding="utf-8")
    bar = BAR_QML.read_text(encoding="utf-8")
    shell = SHELL_QML.read_text(encoding="utf-8")

    # Settings: bar.tray.pinnedRegexes with the spec default, plus the
    # persisted overflow popover order.
    assert "property JsonObject tray" in settings
    assert 'property var pinnedRegexes: ["syncthing"]' in settings
    assert "property var overflowOrder: []" in settings

    # SystemTray: quickshell service + pure pinning logic, no ad-hoc parsing.
    assert "import Quickshell.Services.SystemTray as SysTray" in tray
    assert 'import "TrayPinning.js" as TrayPinning' in tray
    assert "SysTray.SystemTray.items.values" in tray
    assert "TrayPinning.partition(" in tray
    assert "TrayPinning.classifyDrag(" in tray
    assert "TrayPinning.pinAt(" in tray
    assert "TrayPinning.unpin(" in tray
    assert "TrayPinning.orderAfterDrop(" in tray

    # Overflow popover: compact grid, max 4 columns, row-major wrap.
    assert "Math.min(4, root.overflowItems.length)" in tray

    # Windows-11-style drop feedback icons and drag ghost.
    for icon in ('"keep"', '"keep_off"', '"block"'):
        assert icon in tray, f"missing drop icon {icon}"
    assert "ghosted:" in tray

    # Context menus ride QsMenuAnchor, which needs QApplication mode.
    assert "QsMenuAnchor" in tray
    assert "pragma UseQApplication" in shell

    # Single-scene overlay contract with Bar.qml.
    assert "readonly property bool expanded" in tray
    assert "collapsedReserve" in tray
    assert "systemTray.expanded" in bar
    assert "systemTray.collapsedReserve" in bar

    # e2e control surface: no IpcHandler ships in product QML; the test-only
    # driver is env-gated and lives under tests/.
    assert "IpcHandler {" not in tray
    assert "import Quickshell.Io" not in tray
    assert "LYINGSHELL_TRAY_E2E_DRIVER" in tray
    driver = (ROOT / "tests" / "e2e" / "TrayIpcDriver.qml").read_text(encoding="utf-8")
    assert 'target: "tray"' in driver
    assert "serializeState" in driver and "serializeState" in tray

    # TrayItemButton stays Quickshell-free so pointer tests can run offscreen.
    assert "import Quickshell" not in button
    assert "DragHandler" in button
    assert "acceptedButtons: Qt.RightButton" in button
    assert "acceptedButtons: Qt.MiddleButton" in button
    assert "WheelHandler" in button
    # Bar icon size rule.
    assert "icon.width: 16" in button

    # Pure logic library.
    assert pinning.startswith("// Pure pin/partition logic")
    assert ".pragma library" in pinning

    print("OK: tray contract holds")


if __name__ == "__main__":
    main()
