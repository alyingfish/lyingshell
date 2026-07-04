#!/usr/bin/env python3
"""Quick-settings contract test: files, Bar wiring, service boundaries,
MD3/token usage, i18n token parity, and the pure icon-mapping helpers."""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QS_DIR = ROOT / "Modules" / "QuickSettings"
BAR_QML = ROOT / "Modules" / "Bar" / "Bar.qml"
SETTINGS_QML = ROOT / "Commons" / "Settings" / "Settings.qml"
LOCALES = ROOT / "Commons" / "I18n" / "locales"

SERVICES = [
    "Audio.qml",
    "Brightness.qml",
    "NightLight.qml",
    "Airplane.qml",
    "DoNotDisturb.qml",
    "PowerMode.qml",
    "Session.qml",
]

QS_FILES = [
    QS_DIR / "QuickSettings.qml",
    QS_DIR / "QuickSettingsPanel.qml",
    QS_DIR / "QuickSettingsIcons.js",
    QS_DIR / "Widgets" / "QuickToggle.qml",
    QS_DIR / "Widgets" / "QuickMenuToggle.qml",
    QS_DIR / "Widgets" / "QuickSlider.qml",
    ROOT / "Modules" / "Material" / "SliderHandle.qml",
]

NODE_SCRIPT = r"""
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(process.argv[2], "utf8")
    .split(/\r?\n/)
    .filter(line => !/^\s*\.(pragma|import)\b/.test(line))
    .join("\n");
const context = { Math, String, Number };
vm.createContext(context);
vm.runInContext(source, context);

function assert(cond, msg) { if (!cond) throw new Error(msg); }

assert(context.volumeIcon(0.5, true) === "volume_off", "muted icon");
assert(context.volumeIcon(0, false) === "volume_off", "zero volume icon");
assert(context.volumeIcon(0.2, false) === "volume_mute", "low volume icon");
assert(context.volumeIcon(0.5, false) === "volume_down", "mid volume icon");
assert(context.volumeIcon(0.9, false) === "volume_up", "high volume icon");

assert(context.batteryIcon(100, false) === "battery_full", "full only at exactly 100");
assert(context.batteryIcon(99, false) === "battery_6_bar", "99% is near-full, not full");
assert(context.batteryIcon(92, false) === "battery_6_bar", "top band is 6_bar");
assert(context.batteryIcon(50, false) === "battery_3_bar", "half battery");
assert(context.batteryIcon(6, false) === "battery_0_bar", "low battery keeps level");
assert(context.batteryCritical(5, false) && !context.batteryCritical(6, false), "critical threshold");
assert(!context.batteryCritical(5, true), "charging is never critical");
assert(context.batteryIcon(5, false) === "battery_alert", "critical battery alerts");
assert(context.batteryIcon(2, false) === "battery_alert", "empty battery alerts");
assert(context.batteryIcon(100, false, true) === "battery_charging_full", "charged uses charging-full");
assert(context.batteryIcon(80, false, true) === "battery_charging_full", "charged wins over level");
assert(context.batteryIcon(100, true) === "battery_charging_full", "charging at 100 is charging-full");
assert(context.batteryIcon(99, true) === "battery_charging_90", "95-99 charging uses charging_90");
assert(context.batteryIcon(90, true) === "battery_charging_90", "charging 90 step");
assert(context.batteryIcon(55, true) === "battery_charging_50", "charging snaps down");
assert(context.batteryIcon(10, true) === "battery_charging_20", "charging floor step");

assert(context.wifiSignalIcon(90) === "signal_wifi_4_bar", "strong signal 0-100");
assert(context.wifiSignalIcon(0.9) === "signal_wifi_4_bar", "strong signal 0-1");
assert(context.wifiSignalIcon(60) === "network_wifi_3_bar", "good signal");
assert(context.wifiSignalIcon(40) === "network_wifi_2_bar", "fair signal");
assert(context.wifiSignalIcon(10) === "network_wifi_1_bar", "weak signal");
assert(context.wifiSignalIcon(0) === "signal_wifi_0_bar", "no signal");

// Wheel accumulator: one step per 120 angle units (a mouse notch), pixel
// deltas scaled by Qt's ~8x convention, direction reversal resets.
let w = context.wheelNotches(0, 120, 0);
assert(w.steps === 1 && w.acc === 0, "mouse notch up = one step");
w = context.wheelNotches(0, -120, 0);
assert(w.steps === -1 && w.acc === 0, "mouse notch down = one step down");
w = context.wheelNotches(0, 40, 0);
assert(w.steps === 0 && w.acc === 40, "small deltas accumulate");
w = context.wheelNotches(80, 40, 0);
assert(w.steps === 1 && w.acc === 0, "accumulated notch fires");
w = context.wheelNotches(80, -40, 0);
assert(w.steps === 0 && w.acc === -40, "direction reversal resets the accumulator");
w = context.wheelNotches(0, 0, 15);
assert(w.steps === 1 && w.acc === 0, "touchpad pixels scale to notches");
w = context.wheelNotches(0, 240, 0);
assert(w.steps === 2, "fast scrolls step more than once");

process.stdout.write("ok");
"""


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def leaf_string_keys(bundle: dict, prefix: str = "") -> set[str]:
    keys: set[str] = set()
    for key, value in bundle.items():
        token = f"{prefix}{key}"
        if isinstance(value, dict):
            keys |= leaf_string_keys(value, token + ".")
        else:
            keys.add(token)
    return keys


def main() -> None:
    # --- files exist -------------------------------------------------------
    for name in SERVICES:
        assert (ROOT / "Services" / name).exists(), f"missing Services/{name}"
    for path in QS_FILES:
        assert path.exists(), f"missing {path.name}"
    assert (ROOT / "tests" / "e2e" / "QuickSettingsIpcDriver.qml").exists()

    # --- Bar wiring --------------------------------------------------------
    bar = read(BAR_QML)
    assert 'I18n.t("app.name")' not in bar, "pill placeholder must be replaced"
    assert "QuickSettings {" in bar, "Bar must instantiate QuickSettings"
    assert "import qs.Modules.QuickSettings" in bar
    assert "systemTray.expanded || quickSettings.expanded" in bar, (
        "window expansion must cover the quick-settings panel"
    )
    assert "mask: overlayExpanded ? null : barMask" in bar

    # --- widget contracts ---------------------------------------------------
    toggle = read(QS_DIR / "Widgets" / "QuickToggle.qml")
    assert "MD.Button {" in toggle, "QuickToggle wraps MD.Button, not Rectangle+MouseArea"
    assert "checkable: false" in toggle, "toggle display state is service-owned"
    assert "MD.Enum.BtFilled :" in toggle and "BtFilledTonal" in toggle
    assert 'I18n.t(control.labelKey)' in toggle
    # MD3 expressive selected-state cues beyond color alone.
    assert "MD.Token.shape.corner.medium" in toggle, "selected toggles morph to rounded-rect"
    assert "implicitHeight: 44" in toggle, "tiles use the web-prototype 44px height"
    assert "statusText.length > 0 ? control.statusText" in toggle, (
        "runtime status (SSID, ...) replaces the static label, not a second line"
    )
    assert "titleText.truncated" in toggle, (
        "truncated labels (long SSIDs) show the full text in a hover tooltip"
    )

    menu_toggle = read(QS_DIR / "Widgets" / "QuickMenuToggle.qml")
    assert "SplitButtonIndicator" in menu_toggle
    assert "signal expandRequested" in menu_toggle
    assert '"chevron_right"' in menu_toggle, (
        "arrow segments navigate to detail pages, not dropdowns"
    )

    slider = read(QS_DIR / "Widgets" / "QuickSlider.qml")
    assert "MD.Slider {" in slider
    assert "signal moved(" in slider
    # Compact handle wrapper with a percent value indicator, plus an icon
    # tooltip (the icon button is a toggle: mute / night light).
    assert "SliderHandle {" in slider, "QuickSlider uses the qs.Modules.Material handle"
    assert "quickSettings.percentValue" in slider, "value indicator must read as a percentage"
    assert "MD.ToolTip" in slider and "iconTooltipKey" in slider
    assert "dimmed" in slider, "muted sliders fade the track"
    assert "detailArrow.visible ? detailArrow.left : parent.right" in slider, (
        "tracks run to the prototype row inset unless a detail chevron exists"
    )
    # MouseArea.onWheel, not WheelHandler: WheelHandler gets no wheel events
    # on the live compositor (Workspaces proves the MouseArea pattern).
    assert "wheelNotches" in slider and "onWheel" in slider, (
        "hover + wheel adjusts the slider value"
    )
    assert "WheelHandler {" not in slider, "WheelHandler is dead on the live compositor"

    handle = read(ROOT / "Modules" / "Material" / "SliderHandle.qml")
    assert "handlePressed || root.handleHasFocus || root._hoverRevealed" in handle, (
        "value indicator shows instantly on press/drag + keyboard focus"
    )
    assert "HoverHandler" in handle and "hoverDelay" in handle, (
        "and after a hover dwell on the handle itself"
    )
    assert "handleHeight" in handle

    # --- pill: Bar icon rule (16) -------------------------------------------
    qs_root = read(QS_DIR / "QuickSettings.qml")
    pill_sizes = re.findall(r"^\s*size: (\d+)", qs_root, re.MULTILINE)
    assert pill_sizes and all(size == "16" for size in pill_sizes), (
        f"pill icons must all be size 16, got {pill_sizes}"
    )
    assert "readonly property bool expanded" in qs_root
    # Battery percent text obeys bar.quickSettings.showBatteryValue.
    assert "visible: root.showBatteryText" in qs_root
    assert 'showBatteryValue === "always"' in qs_root
    assert "batteryLow" in qs_root

    # --- panel covers the GNOME quick-settings functions --------------------
    panel = read(QS_DIR / "QuickSettingsPanel.qml")
    for token in [
        "quickSettings.wifi",
        "quickSettings.wired",
        "quickSettings.bluetooth",
        "quickSettings.powerMode",
        "quickSettings.nightLight",
        "quickSettings.darkStyle",
        "quickSettings.airplaneMode",
        "quickSettings.keyboardBacklight",
        "quickSettings.session.suspend",
        "quickSettings.session.restart",
        "quickSettings.session.powerOff",
        "quickSettings.session.logOut",
        # Tooltips on the icon-only header actions (prototype: settings + power).
        "quickSettings.settings",
        "quickSettings.lock",
        "quickSettings.power",
        # Battery-less readout (prototype: power glyph + "AC").
        "quickSettings.acPower",
        # Slider icon-button tooltips.
        "quickSettings.mute",
        "quickSettings.unmute",
    ]:
        assert token in panel, f"panel missing function for {token}"
    for feature in ["Session.lock", "Session.openSettings"]:
        assert feature in panel, f"panel missing {feature}"
    for detail in ['"wifi"', '"bluetooth"', '"output"', '"power"', '"kbd"']:
        assert detail in panel, f"panel missing detail page {detail}"
    # Detail pages replace the whole panel (header included) and keep at
    # least the measured main-view height; the paged tile grid keeps the
    # panel height stable and is switched via page dots or wheel/touchpad.
    assert 'visible: root.detail === ""' in panel, "system row hides on detail pages"
    assert "pageCount" in panel and "pager.page" in panel, "tile grid is paged with dots"
    assert "wheelNotches" in panel and "onWheel" in panel, (
        "wheel/touchpad over the tile area flips pages"
    )
    assert "WheelHandler {" not in panel, "WheelHandler is dead on the live compositor"
    assert "mainViewHeight" in panel, "detail pages keep the measured main height"
    assert "VerticalFlickable" in panel, "overlong detail lists scroll inside the card"
    assert "quickSettings.current" in panel, "the active detail row shows a Current badge"

    # Night light lives on the brightness slider icon; the do-not-disturb tile
    # moved out (future notification panel owns it). Neither is a grid tile.
    assert "NightLight.toggle" in panel, "brightness icon must toggle night light"
    assert '"wb_twilight"' in panel, "night-light-on icon must not be a second moon"
    assert 'labelKey: "quickSettings.nightLight"' not in panel, "no Night Light tile"
    assert "quickSettings.doNotDisturb" not in panel, "no Do Not Disturb tile"
    assert "DoNotDisturb." not in panel, "panel no longer drives DoNotDisturb"

    # Battery is a plain readout, not a button; power is the one emphasized
    # icon button and its menu color-codes the session actions.
    assert 'Session.openSettings("power")' not in panel, "battery chip must not be clickable"
    assert "MD.IconLabel" in panel
    assert "MD.Enum.IBtFilledTonal" in panel, "power button is visually separated"
    # Settings, power: every icon-only header action button.
    assert panel.count("MD.ToolTip") >= 2, "all header icon buttons need tooltips"
    assert "leadingIconColor" in panel, "session menu items are color-coded"
    assert "MD.Token.color.error" in panel, "power off must use the error color"

    # --- service boundaries --------------------------------------------------
    audio = read(ROOT / "Services" / "Audio.qml")
    assert "Quickshell.Services.Pipewire" in audio
    assert "Process" not in audio, "Audio must use the Pipewire service, not commands"
    assert "PwObjectTracker" in audio

    for name, marker in [
        ("NightLight.qml", "wlsunset"),
        ("Airplane.qml", "rfkill"),
        ("DoNotDisturb.qml", "makoctl"),
        ("Brightness.qml", "brightnessctl"),
    ]:
        service = read(ROOT / "Services" / name)
        assert marker in service, f"{name} must own {marker}"
        assert "Documented" in service or "documented" in service or "gap" in service, (
            f"{name} must document why a command boundary is allowed"
        )

    power_mode = read(ROOT / "Services" / "PowerMode.qml")
    assert "PowerProfiles" in power_mode and "busctl" in power_mode

    # No product QML calls forbidden CLI tools.
    for qml in list(QS_DIR.rglob("*.qml")) + [ROOT / "Services" / n for n in SERVICES]:
        text = read(qml)
        for banned in ["nmcli", "pactl", "bluetoothctl", '"upower"', "hyprctl", "swaymsg"]:
            assert banned not in text, f"{qml.name} uses forbidden {banned}"

    # No hardcoded visible hex colors in quick-settings QML.
    for qml in QS_DIR.rglob("*.qml"):
        assert not re.search(r'color:\s*"#', read(qml)), f"{qml.name} hardcodes a color"

    # --- settings keys --------------------------------------------------------
    settings = read(SETTINGS_QML)
    assert "property JsonObject nightLight" in settings
    assert "property bool enabled: false" in settings
    assert "property int temperature: 4000" in settings
    assert 'property string showBatteryValue: "whenLow"' in settings

    # --- i18n parity -----------------------------------------------------------
    en = json.loads(read(LOCALES / "en.json"))
    zh = json.loads(read(LOCALES / "zh-CN.json"))
    en_keys = leaf_string_keys(en)
    zh_keys = leaf_string_keys(zh)
    assert en_keys == zh_keys, f"locale key mismatch: {en_keys ^ zh_keys}"

    used = set()
    for qml in list(QS_DIR.rglob("*.qml")) + [BAR_QML]:
        used |= set(re.findall(r'I18n\.t\("([^"]+)"', read(qml)))
    missing = {token for token in used if token not in en_keys}
    assert not missing, f"tokens used but missing from locales: {missing}"

    # --- icon helper behavior ----------------------------------------------------
    result = subprocess.run(
        ["node", "-", str(QS_DIR / "QuickSettingsIcons.js")],
        input=NODE_SCRIPT,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0 and result.stdout == "ok", (
        result.stderr.strip() or result.stdout
    )

    print("OK: quick-settings contract holds")


if __name__ == "__main__":
    main()
