import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Services
import "QuickSettingsIcons.js" as QSIcons

// Quick-settings bar widget (GNOME's system status pill) plus its panel.
// Same window contract as SystemTray: the panel renders in a window-level
// overlay and Bar.qml expands the window to full height while `expanded`.
Item {
    id: root

    // Fed by Bar.qml so the overlay can track bar geometry.
    property bool barHidden: false
    property rect barSurfaceRect

    property bool panelOpen: false
    // Bar.qml: full-screen window + full input mask while true.
    readonly property bool expanded: panelOpen || panelCard.openProgress > 0.001
    readonly property real barBottom: barSurfaceRect.y + barSurfaceRect.height

    // --- pill indicator state (GNOME panel-status-indicators-box) ---------
    readonly property var wifiDevice: Networking.devices.values.find(device => device !== null && device.type === DeviceType.Wifi) || null
    readonly property var wiredDevice: Networking.devices.values.find(device => device !== null && device.type === DeviceType.Wired) || null
    readonly property var activeWifiNetwork: wifiDevice ? wifiDevice.networks.values.find(network => network !== null && network.connected) || null : null
    readonly property string networkIconName: {
        if (wiredDevice && wiredDevice.connected) {
            return "lan";
        }
        if (!Networking.wifiEnabled) {
            return "signal_wifi_off";
        }
        if (activeWifiNetwork) {
            return QSIcons.wifiSignalIcon(activeWifiNetwork.signalStrength);
        }
        return "signal_wifi_0_bar";
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.ready && battery.isLaptopBattery
    readonly property int batteryPercent: hasBattery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batteryCharging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batteryFull: hasBattery && battery.state === UPowerDeviceState.FullyCharged
    // Low == the battery_alert icon threshold (QSIcons.batteryCritical).
    readonly property bool batteryLow: hasBattery && QSIcons.batteryCritical(batteryPercent, batteryCharging)
    readonly property color batteryColor: batteryLow ? MD.Token.color.error : batteryCharging ? MD.Token.color.tertiary : pillButton.mdState.textColor
    // always | never | whenLow (unknown values fall back to whenLow).
    readonly property string showBatteryValue: Settings.options.bar.quickSettings.showBatteryValue
    readonly property bool showBatteryText: hasBattery && (showBatteryValue === "always" || (showBatteryValue !== "never" && batteryLow))

    implicitWidth: pillButton.implicitWidth
    implicitHeight: pillButton.implicitHeight

    onBarHiddenChanged: if (barHidden)
        panelOpen = false
    onPanelOpenChanged: console.info("[QuickSettings] panel " + (panelOpen ? "open" : "closed"))

    // Reactive overlay-space position (same reasoning as SystemTray:
    // mapToItem registers no dependencies, summing x/y up the chain does).
    function overlayX(item) {
        let x = 0;
        for (let it = item; it && it !== overlay.parent; it = it.parent)
            x += it.x;
        return x;
    }

    // --- e2e surface ------------------------------------------------------
    // Plain functions consumed by the test-only IPC driver
    // (tests/e2e/QuickSettingsIpcDriver.qml). Product ships no IpcHandler;
    // the driver loads only when LYINGSHELL_QS_E2E_DRIVER points at it.

    readonly property string e2eDriverSource: String(Quickshell.env("LYINGSHELL_QS_E2E_DRIVER") || "")

    function serializeState() {
        return JSON.stringify({
            "panelOpen": panelOpen,
            "expanded": expanded,
            "detail": panel.detail,
            "page": panel.page,
            "pageCount": panel.pageCount,
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
                "hasWifiDevice": wifiDevice !== null,
                "wifiEnabled": Networking.wifiEnabled,
                "ssid": activeWifiNetwork ? activeWifiNetwork.name : ""
            },
            "bluetooth": {
                "available": btAdapter !== null,
                "enabled": btEnabled
            },
            "powerMode": {
                "available": PowerMode.available
            },
            "nightLight": {
                "enabled": NightLight.enabled,
                "active": NightLight.active
            },
            "darkStyle": Settings.options.theme.mode === "dark",
            "airplane": {
                "available": Airplane.available,
                "enabled": Airplane.enabled
            },
            "doNotDisturb": {
                "available": DoNotDisturb.available,
                "enabled": DoNotDisturb.enabled
            },
            "battery": {
                "present": hasBattery,
                "percent": batteryPercent,
                "charging": batteryCharging
            },
            "geometry": {
                "barBottom": barBottom,
                "pill": overlay.mapFromItem(pillButton, 0, 0, pillButton.width, pillButton.height),
                "card": Qt.rect(panelCard.x, panelCard.y, panelCard.width, panelCard.height)
            }
        });
    }

    function setDetail(name: string) {
        panel.detail = name;
    }

    function e2eSetPage(page: int) {
        panel.setPage(page);
    }

    // Wheel-probe targets for the driver's synthetic QWheelEvents.
    readonly property Item e2eTileArea: panel.tileArea
    readonly property Item e2eVolumeRow: panel.volumeRow
    readonly property Item e2ePanel: panel

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
        Settings.options.theme.mode = Settings.options.theme.mode === "dark" ? "light" : "dark";
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

        // Bar strip metrics: same 28px pill height as the tray buttons.
        implicitHeight: 28
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0

        mdState.size: MD.Enum.XS
        mdState.type: MD.Enum.BtText
        mdState.textColor: mdState.ctx.color.on_surface

        onClicked: root.panelOpen = !root.panelOpen

        contentItem: Item {
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight
            opacity: pillButton.mdState.contentOpacity

            Row {
                id: pillRow

                anchors.centerIn: parent
                spacing: 6

                // Privacy indicators first, GNOME-style.
                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Audio.cameraInUse
                    name: "videocam"
                    size: 16
                    color: MD.Token.color.tertiary
                }

                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Audio.microphoneInUse
                    name: "mic"
                    size: 16
                    color: MD.Token.color.tertiary
                }

                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Airplane.enabled
                    name: "airplanemode_active"
                    size: 16
                    color: pillButton.mdState.textColor
                }

                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.wifiDevice !== null || (root.wiredDevice !== null && root.wiredDevice.connected)
                    name: root.networkIconName
                    size: 16
                    color: pillButton.mdState.textColor
                }

                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.btEnabled
                    name: "bluetooth"
                    size: 16
                    color: pillButton.mdState.textColor
                }

                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: DoNotDisturb.enabled
                    name: "do_not_disturb_on"
                    size: 16
                    color: pillButton.mdState.textColor
                }

                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: PowerMode.available && PowerMode.profile !== PowerProfile.Balanced
                    name: PowerMode.iconName
                    size: 16
                    color: pillButton.mdState.textColor
                }

                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: QSIcons.volumeIcon(Audio.volume, Audio.muted)
                    size: 16
                    color: pillButton.mdState.textColor
                }

                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasBattery
                    name: QSIcons.batteryIcon(root.batteryPercent, root.batteryCharging, root.batteryFull)
                    size: 16
                    color: root.batteryColor
                }

                MD.Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showBatteryText
                    text: I18n.t("quickSettings.batteryPercent", {
                        "percent": root.batteryPercent
                    })
                    color: root.batteryColor
                    typescale: MD.Token.typescale.label_large
                    font.family: Theme.textTypeface
                }
            }
        }
    }

    // Window-level overlay: click-catcher + panel card.
    Item {
        id: overlay

        parent: root.QsWindow.window ? root.QsWindow.window.contentItem : null
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        z: 90

        MouseArea {
            x: 0
            y: root.barBottom
            width: overlay.width
            height: Math.max(0, overlay.height - y)
            visible: root.panelOpen
            acceptedButtons: Qt.AllButtons

            onPressed: root.panelOpen = false
        }

        Item {
            id: panelCard

            property real openProgress: root.panelOpen ? 1 : 0
            readonly property real pad: 8
            readonly property real anchorRightX: root.overlayX(pillButton) + pillButton.width

            Behavior on openProgress {
                NumberAnimation {
                    duration: MD.Token.duration.medium2
                    easing: MD.Token.easing.emphasized
                }
            }

            width: panel.implicitWidth
            height: panel.implicitHeight

            Behavior on height {
                NumberAnimation {
                    duration: MD.Token.duration.medium2
                    easing: MD.Token.easing.emphasized
                }
            }

            x: Math.max(pad, Math.min(anchorRightX - width, overlay.width - width - pad))
            y: root.barBottom + pad - 12 * (1 - openProgress)
            opacity: openProgress
            visible: openProgress > 0.001

            MD.ElevationRectangle {
                anchors.fill: parent
                // Prototype floating-panel: 16px radius, surface-container-high
                // fill, hairline outline-variant border at 62%.
                corners: MD.Util.corners(MD.Token.shape.corner.large)
                color: MD.Token.color.surface_container_high
                border.width: 1
                border.color: Qt.alpha(MD.Token.color.outline_variant, 0.62)
                elevation: MD.Token.elevation.level2
                elevationVisible: true

                // Context colors for descendants (ListItem, Menu, TextField
                // defaults resolve MProp.textColor/backgroundColor).
                MD.MProp.textColor: MD.Token.color.on_surface
                MD.MProp.backgroundColor: MD.Token.color.surface_container_high

                // Swallow presses so the catcher below does not dismiss.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                // Clip only the content during height animation; clipping the
                // ElevationRectangle itself cuts its shadow into a hard rim.
                Item {
                    anchors.fill: parent
                    clip: true

                    QuickSettingsPanel {
                        id: panel

                        width: parent.width
                        visible: root.expanded

                        onCloseRequested: root.panelOpen = false
                    }
                }
            }
        }
    }
}
