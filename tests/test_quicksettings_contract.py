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
QS_BUTTON = ROOT / "Modules" / "Bar" / "Widgets" / "QuickSettingsButton.qml"
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
    QS_BUTTON,
    QS_DIR / "QuickSettingsPopup.qml",
    QS_DIR / "QuickSettingsPanel.qml",
    QS_DIR / "Widgets" / "PanelHeader.qml",
    QS_DIR / "Widgets" / "ToolsRow.qml",
    QS_DIR / "Widgets" / "ToolChip.qml",
    QS_DIR / "Widgets" / "PowerModeRow.qml",
    QS_DIR / "Widgets" / "SessionMenu.qml",
    QS_DIR / "Widgets" / "TilePager.qml",
    QS_DIR / "Widgets" / "PageDots.qml",
    QS_DIR / "Widgets" / "MainPage.qml",
    QS_DIR / "Widgets" / "DetailPage.qml",
    QS_DIR / "Widgets" / "DetailRow.qml",
    QS_DIR / "Widgets" / "DetailRise.qml",
    QS_DIR / "Widgets" / "DetailEmpty.qml",
    QS_DIR / "Widgets" / "WifiDetailPage.qml",
    QS_DIR / "Widgets" / "BluetoothDetailPage.qml",
    QS_DIR / "Widgets" / "SoundDetailPage.qml",
    QS_DIR / "Widgets" / "KbdDetailPage.qml",
    QS_DIR / "Widgets" / "ColorDetailPage.qml",
    QS_DIR / "Widgets" / "QuickToggle.qml",
    QS_DIR / "Widgets" / "QuickMenuToggle.qml",
    QS_DIR / "Widgets" / "QuickSlider.qml",
    QS_DIR / "Widgets" / "ReactiveIconButton.qml",
    ROOT / "Services" / "SystemStatus.qml",
    ROOT / "Commons" / "Icons" / "StatusIcons.js",
    ROOT / "Material" / "Wheel.js",
    ROOT / "Material" / "SliderHandle.qml",
]

NODE_SCRIPT = r"""
const fs = require("fs");
const vm = require("vm");

const source = process.argv.slice(2).map(path => fs.readFileSync(path, "utf8"))
    .join("\n")
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

assert(context.brightnessIcon(0) === "brightness_empty", "zero brightness");
assert(context.brightnessIcon(0.2) === "brightness_low", "low brightness");
assert(context.brightnessIcon(0.5) === "brightness_medium", "mid brightness");
assert(context.brightnessIcon(0.9) === "brightness_high", "high brightness");

assert(context.btDeviceIcon("audio-headset") === "headset_mic", "bt headset icon");
assert(context.btDeviceIcon("input-mouse") === "mouse", "bt mouse icon");
assert(context.btDeviceIcon("") === "bluetooth", "bt fallback icon");

assert(context.audioSinkIcon("Navi 31 HDMI Audio") === "monitor", "hdmi sink icon");
assert(context.audioSinkIcon("Built-in Speakers") === "speaker", "speaker sink icon");
assert(context.audioSinkIcon("WH-1000XM4 bluez_output") === "headset_mic", "bt sink icon");

assert(context.audioSinkType("Navi 31 HDMI Audio") === "hdmi", "hdmi sink type");
assert(context.audioSinkType("Built-in Speakers") === "speakers", "speaker sink type");
assert(context.audioSinkType("WH-1000XM4 bluez_output") === "headset", "bt sink type");
assert(context.audioSinkType("USB Headphones Analog") === "headphones", "headphone sink type");

assert(context.audioSourceIcon("Internal Microphone alsa_input") === "mic", "mic source icon");
assert(context.audioSourceIcon("Pixel Buds Pro bluez_input") === "headset_mic", "bt source icon");
assert(context.audioSourceIcon("C920 Webcam Analog") === "videocam", "webcam source icon");

assert(context.audioSourceType("Internal Microphone alsa_input") === "microphone", "mic source type");
assert(context.audioSourceType("Pixel Buds Pro bluez_input") === "headset", "bt source type");
assert(context.audioSourceType("C920 Webcam Analog") === "webcam", "webcam source type");

assert(context.wifiSignalIcon(90) === "signal_wifi_4_bar", "strong signal 0-100");
assert(context.wifiSignalIcon(0.9) === "signal_wifi_4_bar", "strong signal 0-1");
assert(context.wifiSignalIcon(60) === "network_wifi_3_bar", "good signal");
assert(context.wifiSignalIcon(40) === "network_wifi_2_bar", "fair signal");
assert(context.wifiSignalIcon(10) === "network_wifi_1_bar", "weak signal");
assert(context.wifiSignalIcon(0) === "signal_wifi_0_bar", "no signal");

// Connecting sweep: pill feeds connectingBar/4 (0..4) into wifiSignalIcon.
assert(context.wifiSignalIcon(1/4) === "network_wifi_1_bar", "sweep bar 1");
assert(context.wifiSignalIcon(2/4) === "network_wifi_2_bar", "sweep bar 2");
assert(context.wifiSignalIcon(3/4) === "network_wifi_3_bar", "sweep bar 3");
assert(context.wifiSignalIcon(4/4) === "signal_wifi_4_bar", "sweep bar 4");

// networkIcon(wiredConnected, wifiEnabled, apMode, activeStrength, noInternet)
assert(context.networkIcon(true, true, false, 0.9, false) === "lan", "wired wins");
assert(context.networkIcon(false, false, false, 0.9, false) === "signal_wifi_off", "wifi off");
assert(context.networkIcon(false, true, true, null, false) === "wifi_tethering", "hosting hotspot");
assert(context.networkIcon(false, true, false, 0.9, true) === "signal_wifi_bad", "connected no internet");
assert(context.networkIcon(false, true, false, 0.9, false) === "signal_wifi_4_bar", "connected healthy");
assert(context.networkIcon(false, true, false, null, false) === "signal_wifi_statusbar_not_connected", "enabled, no network");

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
    assert "QuickSettingsButton {" in bar, "Bar must instantiate QuickSettingsButton"
    assert "import qs.Modules.Bar.Widgets" in bar
    assert "quickSettingsLoader.item.expanded" in bar, (
        "window expansion must cover the quick-settings panel"
    )
    assert "mask: overlayExpanded ? null : barMask" in bar

    # --- widget contracts ---------------------------------------------------
    toggle = read(QS_DIR / "Widgets" / "QuickToggle.qml")
    assert "MD.Button {" in toggle, "QuickToggle wraps MD.Button, not Rectangle+MouseArea"
    assert "checkable: false" in toggle, "toggle display state is service-owned"
    assert "MD.Enum.BtFilled :" in toggle and "BtFilledTonal" in toggle
    assert 'I18n.t(control.labelKey)' in toggle
    # MD3 expressive selected-state cues beyond color alone (web-prototype
    # tile: full pill at rest, radius 14 + emphasized type selected).
    assert "readonly property real selectedCorner: 14" in toggle, (
        "selected tiles morph to the prototype's 14px corner"
    )
    assert "prominent: control.checked" in toggle, "selected tiles use emphasized type"
    assert "surface_container_high" in toggle, "resting tiles sit on surface-container-high"
    assert "implicitHeight: 44" in toggle, "tiles use the web-prototype 44px height"
    assert "offIconName" in toggle, "wifi/bt tiles cross-fade their off/on glyphs"
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
    # tooltip (the icon button is a toggle: mute).
    assert "SliderHandle {" in slider, "QuickSlider uses the qs.Material handle"
    assert "quickSettings.percentValue" in slider, "value indicator must read as a percentage"
    assert "MD.ToolTip" in slider and "iconTooltipKey" in slider
    assert "dimmed" in slider, "muted sliders fade the track"
    # Web-prototype expressive track: 13px tall (10px in the sound mixer's
    # compact variant), 10px handle gap, stop dot, and a fixed 32px trailing
    # slot so both sliders' right edges align.
    assert "compact ? 10 : 13" in slider, "track uses the prototype 13/10px thickness"
    assert "handleCenter - 10" in slider and "handleCenter + 10" in slider, (
        "active/inactive tracks keep the 10px inset gap around the handle"
    )
    assert 'icon.name: "tune"' in slider, "the output-device button uses the mixer glyph"
    assert "trailingSlot" in slider, "sliders keep the trailing 32px alignment slot"
    # MouseArea.onWheel, not WheelHandler: WheelHandler gets no wheel events
    # on the live compositor (Workspaces proves the MouseArea pattern). Scroll
    # mirrors GNOME (js/ui/slider.js): mouse = fixed notches, touchpad = smooth.
    assert "onWheel" in slider and "pixelDelta" in slider, (
        "hover + wheel adjusts the slider value (touchpad smooth, mouse notched)"
    )
    assert "WheelHandler {" not in slider, "WheelHandler is dead on the live compositor"

    handle = read(ROOT / "Material" / "SliderHandle.qml")
    assert "handlePressed || root.handleHasFocus || root._hoverRevealed" in handle, (
        "value indicator shows instantly on press/drag + keyboard focus"
    )
    assert "HoverHandler" in handle and "hoverDelay" in handle, (
        "and after a hover dwell on the handle itself"
    )
    assert "handleHeight" in handle

    # --- pill: Bar icon rule (16) -------------------------------------------
    qs_root = read(QS_BUTTON)
    assert "import qs.Modules.QuickSettings" in qs_root
    assert "QuickSettingsPopup {" in qs_root
    pill_sizes = re.findall(r"^\s*size: (\d+)", qs_root, re.MULTILINE)
    assert pill_sizes and all(size == "16" for size in pill_sizes), (
        f"pill icons must all be size 16, got {pill_sizes}"
    )
    assert "readonly property bool expanded" in qs_root
    # Battery percent text obeys bar.widgets.quickSettingsButton.showBatteryValue.
    assert "visible: root.showBatteryText" in qs_root
    assert 'showBatteryValue === "always"' in qs_root
    assert "batteryLow" in qs_root

    # --- panel covers the GNOME quick-settings functions --------------------
    # The panel is split across the module; assert against the whole tree.
    panel = "\n".join(read(path) for path in sorted(QS_DIR.rglob("*.qml")))
    for token in [
        "quickSettings.wifi",
        "quickSettings.wired",
        "quickSettings.bluetooth",
        "quickSettings.powerMode",
        "quickSettings.nightLight",
        "quickSettings.darkStyle",
        "quickSettings.airplaneMode",
        "quickSettings.doNotDisturb",
        "quickSettings.keyboardBacklight",
        "quickSettings.session.suspend",
        "quickSettings.session.restart",
        "quickSettings.session.powerOff",
        "quickSettings.session.logOut",
        # Tools row (prototype #rowTools).
        "quickSettings.tools",
        "quickSettings.tool.colorPicker",
        "quickSettings.tool.screenshot",
        # Tooltips on the icon-only header actions (prototype: settings + power).
        "quickSettings.settings",
        "quickSettings.lock",
        "quickSettings.power",
        # Battery-less readout (prototype: power glyph + "AC").
        "quickSettings.acPower",
        # Slider icon-button tooltips.
        "quickSettings.mute",
        "quickSettings.unmute",
        # Detail-list sub lines + off states.
        "quickSettings.wifiConnected",
        "quickSettings.detailOffTitle",
    ]:
        assert token in panel, f"panel missing function for {token}"
    for feature in [
        "Session.lock",
        "Session.openSettings",
        "Niri.pickColor",
        "Niri.takeScreenshot",
    ]:
        assert feature in panel, f"panel missing {feature}"
    for detail in ['"wifi"', '"bluetooth"', '"sound"', '"kbd"', '"color"']:
        assert detail in panel, f"panel missing detail page {detail}"
    # Sound detail: Output / Input device sections + the per-app mixer.
    for token in [
        "quickSettings.soundOutputs",
        "quickSettings.soundInputs",
        "quickSettings.soundApps",
    ]:
        assert token in panel, f"sound detail missing section {token}"
    assert "Audio.playbackStreams" in panel, "the sound detail lists app streams"
    assert "Audio.setStreamVolume" in panel and "Audio.toggleStreamMuted" in panel, (
        "mixer rows drive per-stream volume/mute through the Audio service"
    )
    assert "compact: true" in panel, "mixer rows use the compact slider variant"
    # Power mode lives in the header battery pill + expandable connected
    # group now, not in a detail page or grid tile.
    assert '"power"' not in panel.replace('"power_settings_new"', ""), (
        "the power detail page moved into the power-mode row"
    )
    assert "ConnectedButtonGroup" in panel, "power modes use the M3E connected group"
    assert "battPill" in panel and "pmodeOpen" in panel, (
        "the battery pill expands the power-mode row"
    )
    # The pill stays clickable with no power-profiles daemon so the row can be
    # expanded to read time-left; the profile group + a soft "no power profile"
    # notice swap on PowerMode.available.
    assert "enabled: PowerMode.available" not in panel, (
        "the battery pill must not be hard-gated on the profile daemon"
    )
    assert "visible: PowerMode.available" in panel, (
        "the profile group is hidden when no daemon is running"
    )
    assert "quickSettings.powerProfile.unavailable" in panel, (
        "the power-mode row shows a soft notice when no daemon is running"
    )
    assert "toolsOpen" in panel and "ToolChip" in panel, (
        "the tools button expands the tools row"
    )
    # Detail navigation is an MD.StackView: it owns page visibility/input, so
    # switching views never greys a control. Gating a still-visible view with
    # `enabled` (the disabled-palette flash bug) is forbidden — this locks the
    # fix in so future detail pages can't reintroduce it.
    assert "MD.StackView" in panel, "detail navigation uses a StackView"
    assert "enabled: root.detail" not in panel, (
        "views must not be enabled-gated (greys MD controls mid-transition); "
        "StackView owns visibility"
    )
    assert "DetailPage {" in panel, "detail pages extend the shared DetailPage chrome"
    assert "compactContentHeight" in panel, "detail pages keep the compact main height"
    assert "pageCount" in panel and "pager.page" in panel, "tile grid is paged with dots"
    assert "wheelNotches" in panel and "onWheel" in panel, (
        "wheel/touchpad over the tile area flips pages"
    )
    assert "WheelHandler {" not in panel, "WheelHandler is dead on the live compositor"
    pager = read(QS_DIR / "Widgets" / "TilePager.qml")
    assert "SwipeView {" not in pager, (
        "tile pages slide a spring track, not a strict-range SwipeView: "
        "StrictlyEnforceRange fixup-fights the MD3 rebound overshoot"
    )
    assert "Behavior on x" in pager, "the page track animates its x offset"
    assert "0.38, 1.21, 0.22, 1.0, 1.0, 1.0" in pager and '"duration": 500' in pager, (
        "the track uses the prototype's literal --spring-soft page-turn curve "
        "(cubic-bezier(.38,1.21,.22,1) @ .5s); the MD3 spring tokens overshoot late "
        "and drift 20-60px off the prototype mid-slide"
    )
    assert "VerticalFlickable" in panel, "overlong detail lists scroll inside the card"
    assert 'name: "check"' in panel, "the active detail row shows a trailing check"
    assert "MD.Switch" in panel, "wifi/bt detail headers carry the radio switch"

    # Night light and do-not-disturb are grid tiles (prototype tile set);
    # the brightness slider icon is a plain level readout.
    assert "NightLight.toggle" in panel, "night light tile must toggle the service"
    assert '"wb_twilight"' in panel, "night-light icon must not be a second moon"
    assert 'labelKey: "quickSettings.nightLight"' in panel, "Night Light is a tile"
    assert "DoNotDisturb.toggle" in panel, "Do Not Disturb is a tile"
    assert "brightnessIcon" in panel, "brightness icon is a level readout"

    assert "MD.IconLabel" in panel
    assert "MD.Enum.IBtFilledTonal" in panel, "power button is visually separated"
    # Settings, power: every icon-only header action button.
    assert panel.count("MD.ToolTip") >= 2, "all header icon buttons need tooltips"
    # Prototype #pmenu: rows share the row colour (currentColor); only the
    # shut-down row reads error red (.mi.danger).
    assert "danger" in panel and 'iconName: "power_settings_new"' in panel, (
        "the session menu's shut-down row is the danger action"
    )
    assert "MD.Token.color.error" in panel, "power off must use the error color"

    # --- service boundaries --------------------------------------------------
    audio = read(ROOT / "Services" / "Audio.qml")
    assert "Quickshell.Services.Pipewire" in audio
    assert "Process" not in audio, "Audio must use the Pipewire service, not commands"
    assert "PwObjectTracker" in audio
    # Sound detail data: input devices + per-app playback streams, switched
    # and mixed through the service (pages never touch Pipewire directly).
    assert "sourceDevices" in audio and "preferredDefaultAudioSource" in audio
    assert "playbackStreams" in audio and "AudioOutStream" in audio

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
    for qml in list(QS_DIR.rglob("*.qml")) + [QS_BUTTON] + [ROOT / "Services" / n for n in SERVICES + ["SystemStatus.qml"]]:
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
    for qml in list(QS_DIR.rglob("*.qml")) + [BAR_QML, QS_BUTTON]:
        used |= set(re.findall(r'I18n\.t\("([^"]+)"', read(qml)))
    missing = {token for token in used if token not in en_keys}
    assert not missing, f"tokens used but missing from locales: {missing}"

    # --- icon helper behavior ----------------------------------------------------
    result = subprocess.run(
        ["node", "-", str(ROOT / "Commons" / "Icons" / "StatusIcons.js"), str(ROOT / "Material" / "Wheel.js")],
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
