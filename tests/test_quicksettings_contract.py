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

assert(context.batteryIcon(100, false) === "battery_full", "full battery");
assert(context.batteryIcon(50, false) === "battery_3_bar", "half battery");
assert(context.batteryIcon(2, false) === "battery_0_bar", "empty battery");
assert(context.batteryIcon(10, true) === "battery_charging_full", "charging battery");

assert(context.wifiSignalIcon(90) === "signal_wifi_4_bar", "strong signal 0-100");
assert(context.wifiSignalIcon(0.9) === "signal_wifi_4_bar", "strong signal 0-1");
assert(context.wifiSignalIcon(60) === "network_wifi_3_bar", "good signal");
assert(context.wifiSignalIcon(40) === "network_wifi_2_bar", "fair signal");
assert(context.wifiSignalIcon(10) === "network_wifi_1_bar", "weak signal");
assert(context.wifiSignalIcon(0) === "signal_wifi_0_bar", "no signal");

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

    menu_toggle = read(QS_DIR / "Widgets" / "QuickMenuToggle.qml")
    assert "SplitButtonIndicator" in menu_toggle
    assert "signal expandRequested" in menu_toggle

    slider = read(QS_DIR / "Widgets" / "QuickSlider.qml")
    assert "MD.Slider {" in slider
    assert "signal moved(" in slider

    # --- pill: Bar icon rule (16) -------------------------------------------
    qs_root = read(QS_DIR / "QuickSettings.qml")
    pill_sizes = re.findall(r"^\s*size: (\d+)", qs_root, re.MULTILINE)
    assert pill_sizes and all(size == "16" for size in pill_sizes), (
        f"pill icons must all be size 16, got {pill_sizes}"
    )
    assert "readonly property bool expanded" in qs_root

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
        "quickSettings.doNotDisturb",
        "quickSettings.session.suspend",
        "quickSettings.session.restart",
        "quickSettings.session.powerOff",
        "quickSettings.session.logOut",
    ]:
        assert token in panel, f"panel missing function for {token}"
    for feature in ["Session.takeScreenshot", "Session.lock", "Session.openSettings"]:
        assert feature in panel, f"panel missing {feature}"
    for detail in ['"wifi"', '"bluetooth"', '"output"']:
        assert detail in panel, f"panel missing detail page {detail}"

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
