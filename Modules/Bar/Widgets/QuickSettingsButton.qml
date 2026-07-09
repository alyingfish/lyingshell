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

    // Network tooltip: wired, hosting a hotspot, the live SSID (flagged when
    // there's no real internet), or a plain "Wi-Fi".
    readonly property string networkTip: {
        if (SystemStatus.wiredConnected)
            return I18n.t("quickSettings.wired");
        if (SystemStatus.wifiConnecting)
            return I18n.t("quickSettings.wifiConnecting");
        if (SystemStatus.hotspotActive)
            return I18n.t("quickSettings.hotspotActive");
        if (SystemStatus.activeWifiNetwork)
            return SystemStatus.wifiNoInternet ? SystemStatus.activeWifiNetwork.name + " · " + I18n.t("quickSettings.noInternet") : SystemStatus.activeWifiNetwork.name;
        return I18n.t("quickSettings.wifi");
    }

    // Connecting sweep: cycle the fan bars while a wifi network is activating,
    // matching macOS/GNOME/Windows. Only runs while wifiConnecting is true.
    property int connectingBar: 0
    Timer {
        running: SystemStatus.wifiConnecting
        interval: 350
        repeat: true
        onRunningChanged: if (!running) root.connectingBar = 0
        onTriggered: root.connectingBar = (root.connectingBar + 1) % 5
    }

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
            // Below the icon, like the bar-tray tooltips (default is above).
            y: parent.height + 4
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

                // Privacy indicators first, GNOME-style.
                StatusIcon {
                    visible: Audio.cameraInUse
                    name: "videocam"
                    color: MD.Token.color.tertiary
                    tip: I18n.t("quickSettings.cameraInUse")
                }

                StatusIcon {
                    visible: Audio.microphoneInUse
                    name: "mic"
                    color: MD.Token.color.tertiary
                    tip: I18n.t("quickSettings.microphoneInUse")
                }

                StatusIcon {
                    visible: Airplane.enabled
                    name: "airplanemode_active"
                    color: pillButton.mdState.textColor
                    tip: I18n.t("quickSettings.airplaneMode")
                }

                StatusIcon {
                    visible: SystemStatus.wifiDevice !== null || SystemStatus.wiredConnected
                    name: SystemStatus.wifiConnecting ? StatusIcons.wifiSignalIcon(root.connectingBar / 4) : SystemStatus.networkIconName
                    color: pillButton.mdState.textColor
                    tip: root.networkTip
                }

                StatusIcon {
                    visible: SystemStatus.btEnabled
                    name: "bluetooth"
                    color: pillButton.mdState.textColor
                    tip: I18n.t("quickSettings.bluetooth")
                }

                StatusIcon {
                    visible: DoNotDisturb.enabled
                    name: "do_not_disturb_on"
                    color: pillButton.mdState.textColor
                    tip: I18n.t("quickSettings.doNotDisturb")
                }

                StatusIcon {
                    visible: PowerMode.available && PowerMode.profile !== PowerProfile.Balanced
                    name: PowerMode.iconName
                    color: pillButton.mdState.textColor
                    tip: PowerMode.profile === PowerProfile.Performance ? I18n.t("quickSettings.powerProfile.performance") : I18n.t("quickSettings.powerProfile.powerSaver")
                }

                StatusIcon {
                    name: StatusIcons.volumeIcon(Audio.volume, Audio.muted)
                    color: pillButton.mdState.textColor
                    tip: Audio.muted ? I18n.t("quickSettings.muted") : I18n.t("quickSettings.volume")
                }

                StatusIcon {
                    visible: SystemStatus.hasBattery
                    name: StatusIcons.batteryIcon(SystemStatus.batteryPercent, SystemStatus.batteryCharging, SystemStatus.batteryFull)
                    color: root.batteryColor
                    tip: I18n.t("quickSettings.batteryPercent", {
                        "percent": SystemStatus.batteryPercent
                    })
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
    }
}
