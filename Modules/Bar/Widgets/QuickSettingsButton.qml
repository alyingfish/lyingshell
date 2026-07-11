import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Services
import qs.Modules.QuickSettings
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Quick-settings button (GNOME's system status pill): the bar widget that
// shows privacy / network / battery indicators and opens the quick-settings
// menu. The menu owns its own window-level overlay; Bar.qml expands the
// window to full height while `expanded` is true.
Item {
    id: root

    // Fed by Bar.qml so the menu overlay can track bar geometry.
    property bool barHidden: false
    property rect barSurfaceRect

    property bool panelOpen: false
    // Bar.qml: full-screen window + full input mask while true.
    readonly property bool expanded: menu.expanded

    readonly property color batteryColor: SystemStatus.batteryLow ? MD.Token.color.error : SystemStatus.batteryCharging ? MD.Token.color.tertiary : pillButton.mdState.textColor
    // always | never | whenLow (unknown values fall back to whenLow).
    readonly property string showBatteryValue: Settings.options.bar.widgets.quickSettingsButton.showBatteryValue
    readonly property bool showBatteryText: SystemStatus.hasBattery && (showBatteryValue === "always" || (showBatteryValue !== "never" && SystemStatus.batteryLow))

    // Cap dynamic names (SSID, output-device nickname, BT device) so a long
    // label can't blow the tooltip wide: elide overflow to an ellipsis, the way
    // GNOME's menus and KDE's applet bound their labels.
    readonly property int tipNameMax: 20
    function elideName(text: string): string {
        return text.length > tipNameMax ? text.substring(0, tipNameMax - 1).replace(/\s+$/, "") + "…" : text;
    }

    // Pill tooltips read like Windows 11's quick-settings buttons: a name line
    // over a state line. Network leads with the SSID (or "Wired") when there is
    // one — never a bare "Wi-Fi", since the pill's network glyph already names
    // the radio; radio-only states drop to just the state line.
    readonly property string networkTip: {
        if (SystemStatus.wiredConnected)
            return I18n.t("quickSettings.wired") + "\n" + I18n.t("quickSettings.wifiConnected");
        if (!Networking.wifiEnabled)
            return I18n.t("quickSettings.wifiOff");
        if (SystemStatus.wifiConnecting)
            return I18n.t("quickSettings.wifiConnecting");
        if (SystemStatus.hotspotActive)
            return I18n.t("quickSettings.hotspotActive");
        if (SystemStatus.activeWifiNetwork)
            return root.elideName(SystemStatus.activeWifiNetwork.name) + "\n" + (SystemStatus.wifiNoInternet ? I18n.t("quickSettings.noInternet") : I18n.t("quickSettings.wifiConnected"));
        return I18n.t("quickSettings.wifiNotConnected");
    }

    // Bluetooth: the connected device name(s) over the connection state, never
    // a bare "Bluetooth" — the pill's bluetooth glyph already names the radio.
    // With nothing paired-and-connected it drops to just the state line.
    readonly property string bluetoothTip: {
        var devices = SystemStatus.btConnectedDevices;
        if (devices.length === 0)
            return I18n.t("quickSettings.btNotConnected");
        var names = devices.map(device => device.name.length > 0 ? device.name : device.address);
        if (devices.length === 1)
            return root.elideName(names[0]) + "\n" + I18n.t("quickSettings.btConnected");
        return root.elideName(names.join(", ")) + "\n" + I18n.t("quickSettings.bluetoothConnectedCount", {
            "count": devices.length
        });
    }

    // Volume: a Windows-style output name — the endpoint type plus the device's
    // short nickname (e.g. "Speakers · Built-in Audio") — over its level (or
    // "Muted"). The type comes from the sink's description/name keywords.
    readonly property string volumeTip: {
        var device;
        if (Audio.hasSink) {
            var typeToken = "quickSettings.outputType." + StatusIcons.audioSinkType(Audio.sink.description + " " + Audio.sink.name);
            var type = I18n.t(typeToken);
            var nick = root.elideName(Audio.sink.nickname);
            device = nick.length > 0 ? type + " · " + nick : type;
        } else {
            device = I18n.t("quickSettings.outputDevice");
        }
        var level = Audio.muted ? I18n.t("quickSettings.muted") : I18n.t("quickSettings.volumePercent", {
            "percent": Math.round(Audio.volume * 100)
        });
        return device + "\n" + level;
    }

    // Battery: the same status line the quick-settings power-mode row reads —
    // the live time estimate ("5h 12m left" / "1m until full") when UPower has
    // one, else the charge state — laid out like the volume tooltip over the
    // charge percentage. The Empty/Unknown state reads as the raw percentage, so
    // drop the redundant second line there.
    readonly property string batteryTip: {
        var pct = I18n.t("quickSettings.batteryPercent", {
            "percent": SystemStatus.batteryPercent
        });
        var status = SystemStatus.hasBattery ? BatteryStatus.line : "";
        return status.length > 0 && status !== pct ? status + "\n" + pct : pct;
    }

    // GNOME SystemIndicator rule (web-prototype tray.js): the network icon
    // exists only while there is something to report — a wired link, an
    // active/acquiring wifi connection, or the hotspot. Wi-Fi enabled but
    // idle shows nothing.
    readonly property bool networkIndicatorVisible: SystemStatus.wiredConnected || (Networking.wifiEnabled && (SystemStatus.hotspotActive || SystemStatus.activeWifiNetwork !== null || SystemStatus.wifiConnecting))

    // Each pill indicator names itself on hover (GNOME status-area style). The
    // pill is a single Button, so per-icon HoverHandlers drive per-icon
    // tooltips the whole-button hover can't.
    component StatusIcon: MD.Icon {
        id: statusIcon

        property string tip: ""

        anchors.verticalCenter: parent.verticalCenter
        size: 16

        HoverHandler {
            id: statusHover
        }

        MD.ToolTip {
            // Hang below the bar's bottom edge, matching the bar-tray tooltips —
            // not below the glyph. The 16px icon is centered in the taller (32px)
            // strip, so anchoring to the icon floats the tip up inside the bar and
            // misaligns it with the tray's. The icon's center sits on the bar's
            // center, so the bar bottom is half the bar height below it.
            y: parent.height / 2 + root.barSurfaceRect.height / 2 + 4
            // Drop the bottom popup margin: it hangs into the strip the bar
            // reserves below itself for the tray tooltips, and the default 4px
            // margin would clamp it back up, floating it above the tray's.
            bottomMargin: 0
            text: statusIcon.tip
            // Suppress the hover tooltips once the panel is up — it covers them.
            visible: statusHover.hovered && text.length > 0 && !root.panelOpen
        }
    }

    implicitWidth: pillButton.implicitWidth
    implicitHeight: pillButton.implicitHeight

    onBarHiddenChanged: if (barHidden)
        panelOpen = false
    onPanelOpenChanged: console.info("[QuickSettings] panel " + (panelOpen ? "open" : "closed"))

    // --- e2e surface ------------------------------------------------------
    // Plain functions consumed by the test-only IPC driver
    // (tests/e2e/QuickSettingsIpcDriver.qml). Product ships no IpcHandler;
    // the driver loads only when LYINGSHELL_QS_E2E_DRIVER points at it.

    readonly property string e2eDriverSource: String(Quickshell.env("LYINGSHELL_QS_E2E_DRIVER") || "")

    function serializeState() {
        return JSON.stringify({
            "panelOpen": panelOpen,
            "expanded": expanded,
            "detail": menu.panel.detail,
            "page": menu.panel.page,
            "pageCount": menu.panel.pageCount,
            "audio": {
                "hasSink": Audio.hasSink,
                "volume": Audio.volume,
                "muted": Audio.muted,
                "inputVolume": Audio.inputVolume,
                "inputMuted": Audio.inputMuted,
                "microphoneInUse": Audio.microphoneInUse,
                "sinkCount": Audio.sinkDevices.length
            },
            "brightness": {
                "available": Brightness.available,
                "percent": Brightness.percent,
                "kbdAvailable": Brightness.kbdAvailable,
                "kbdLevel": Brightness.kbdLevel,
                "kbdMax": Brightness.kbdMax
            },
            "network": {
                "hasWifiDevice": SystemStatus.wifiDevice !== null,
                "wifiEnabled": Networking.wifiEnabled,
                "ssid": SystemStatus.activeWifiNetwork ? SystemStatus.activeWifiNetwork.name : ""
            },
            "bluetooth": {
                "available": SystemStatus.btAdapter !== null,
                "enabled": SystemStatus.btEnabled
            },
            "powerMode": {
                "available": PowerMode.available
            },
            "nightLight": {
                "enabled": NightLight.enabled,
                "active": NightLight.active
            },
            "darkStyle": Settings.options.appearance.mode === "dark",
            "airplane": {
                "available": Airplane.available,
                "enabled": Airplane.enabled
            },
            "doNotDisturb": {
                "available": DoNotDisturb.available,
                "enabled": DoNotDisturb.enabled
            },
            "battery": {
                "present": SystemStatus.hasBattery,
                "percent": SystemStatus.batteryPercent,
                "charging": SystemStatus.batteryCharging
            },
            "geometry": {
                "barBottom": menu.barBottom,
                "pill": menu.itemRect(pillButton),
                "card": menu.cardRect
            }
        });
    }

    function setDetail(name: string) {
        menu.panel.detail = name;
    }

    function e2eSetPage(page: int) {
        menu.panel.setPage(page);
    }

    // Wheel-probe targets for the driver's synthetic QWheelEvents.
    readonly property Item e2eTileArea: menu.panel.tileArea
    readonly property Item e2eVolumeRow: menu.panel.volumeRow
    readonly property Item e2ePanel: menu.panel

    function e2eSetVolume(value: real) {
        Audio.setVolume(value);
    }

    function e2eToggleMuted() {
        Audio.toggleMuted();
    }

    function e2eSetBrightness(value: real) {
        Brightness.setPercent(value);
    }

    function e2eToggleNightLight() {
        NightLight.toggle();
    }

    function e2eToggleDarkStyle() {
        Settings.options.appearance.mode = Settings.options.appearance.mode === "dark" ? "light" : "dark";
    }

    function e2eToggleDoNotDisturb() {
        DoNotDisturb.toggle();
    }

    Loader {
        active: root.e2eDriverSource.length > 0
        source: root.e2eDriverSource

        onLoaded: item.view = root
    }

    MD.Button {
        id: pillButton

        // Bar strip metrics: same 24px pill height as the tray buttons, and
        // 12px side padding to match the workspaces pill (the MD3 XS button's
        // own 16px leading/trailing space is too wide for this collapsed strip).
        implicitHeight: 24
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0
        leftPadding: 12
        rightPadding: 12

        mdState.size: MD.Enum.XS
        mdState.type: MD.Enum.BtText
        mdState.textColor: mdState.ctx.color.on_surface

        // Re-tint the state layer neutral while keeping the expanding ripple.
        // The stock BtText ripple is `primary`, but our status glyphs are
        // on_surface (neutral), so MD3 wants the state layer neutral too. This
        // mirrors Button.qml's background but forces the ripple to
        // on_surface_variant to match the workspaces pill.
        background: MD.ElevationRectangle {
            color: "transparent"
            corners: pillButton.mdState.corners

            MD.Ripple {
                anchors.fill: parent
                corners: parent.corners
                pressX: pillButton.pressX
                pressY: pillButton.pressY
                pressed: pillButton.pressed
                stateOpacity: pillButton.mdState.stateLayerOpacity
                color: MD.Token.color.on_surface_variant
            }
        }

        onClicked: root.panelOpen = !root.panelOpen

        contentItem: Item {
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight
            opacity: pillButton.mdState.contentOpacity

            Row {
                id: pillRow

                anchors.centerIn: parent
                spacing: 8

                // Privacy camera first, GNOME-style; then the prototype's
                // indicator order (tray.js): night light, network, DND,
                // bluetooth, airplane, mic, volume, power profile, battery.
                // Absence is the "off" state — nothing here dims to show idle.
                StatusIcon {
                    visible: Audio.cameraInUse
                    name: "videocam"
                    color: MD.Token.color.tertiary
                    tip: I18n.t("quickSettings.cameraInUse")
                }

                StatusIcon {
                    // Active right now per schedule, not merely enabled
                    // (GNOME status/nightLight.js NightLightActive).
                    visible: NightLight.active
                    name: "nightlight"
                    color: pillButton.mdState.textColor
                    tip: I18n.t("quickSettings.nightLight")
                }

                StatusIcon {
                    visible: root.networkIndicatorVisible
                    // While acquiring with nothing active yet the prototype
                    // pulses the full wifi glyph (its .acq state).
                    name: SystemStatus.wifiConnecting && SystemStatus.activeWifiNetwork === null && !SystemStatus.wiredConnected ? "wifi" : SystemStatus.networkIconName
                    color: pillButton.mdState.textColor
                    tip: root.networkTip

                    // Prototype acqPulse: opacity 1 <-> 0.3 while a connect
                    // is in flight (GNOME swaps to a static -acquiring- icon;
                    // the pulse is the prototype's deliberate variant).
                    SequentialAnimation on opacity {
                        running: SystemStatus.wifiConnecting
                        loops: Animation.Infinite

                        onStopped: opacity = 1

                        NumberAnimation {
                            to: 0.3
                            duration: 550
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 1
                            duration: 550
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                StatusIcon {
                    visible: DoNotDisturb.enabled
                    name: "notifications_off"
                    color: pillButton.mdState.textColor
                    tip: I18n.t("quickSettings.doNotDisturb")
                }

                StatusIcon {
                    // GNOME shows the status-area bluetooth glyph only while a
                    // device is connected (status/bluetooth.js: nConnected > 0),
                    // not merely when the radio is on — the toggle owns on/off.
                    visible: SystemStatus.btConnectedDevices.length > 0
                    name: "bluetooth"
                    color: pillButton.mdState.textColor
                    tip: root.bluetoothTip
                }

                StatusIcon {
                    visible: Airplane.enabled
                    name: "airplanemode_active"
                    color: pillButton.mdState.textColor
                    tip: I18n.t("quickSettings.airplaneMode")
                }

                StatusIcon {
                    // Only while an app records; the privacy tint drops on a
                    // muted mic (no privacy concern), prototype trayMic.
                    visible: Audio.microphoneInUse
                    name: Audio.inputMuted ? "mic_off" : "mic"
                    color: Audio.inputMuted ? pillButton.mdState.textColor : MD.Token.color.tertiary
                    tip: I18n.t("quickSettings.microphoneInUse")
                }

                StatusIcon {
                    name: StatusIcons.volumeIcon(Audio.volume, Audio.muted)
                    color: pillButton.mdState.textColor
                    tip: root.volumeTip
                }

                StatusIcon {
                    // Power profile only when non-default (GNOME
                    // status/powerProfiles.js), sharing the power-mode row's
                    // glyphs.
                    visible: PowerMode.available && PowerMode.profile !== PowerProfile.Balanced
                    name: PowerMode.profile === PowerProfile.PowerSaver ? "energy_savings_leaf" : "bolt"
                    color: pillButton.mdState.textColor
                    tip: PowerMode.profile === PowerProfile.PowerSaver ? I18n.t("quickSettings.powerProfile.powerSaver") : I18n.t("quickSettings.powerProfile.performance")
                }

                StatusIcon {
                    visible: SystemStatus.hasBattery
                    name: StatusIcons.batteryIcon(SystemStatus.batteryPercent, SystemStatus.batteryCharging, SystemStatus.batteryFull)
                    color: root.batteryColor
                    tip: root.batteryTip
                }

                MD.Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBatteryText
                    text: I18n.t("quickSettings.batteryPercent", {
                        "percent": SystemStatus.batteryPercent
                    })
                    color: root.batteryColor
                    typescale: MD.Token.typescale.label_large
                    font.family: Theme.textTypeface
                }
            }
        }
    }

    QuickSettingsPopup {
        id: menu

        anchorItem: pillButton
        barBottom: root.barSurfaceRect.y + root.barSurfaceRect.height
        open: root.panelOpen

        onCloseRequested: root.panelOpen = false
        // A completed colour pick reopens the panel on its readout page.
        onOpenRequested: root.panelOpen = true
    }
}
