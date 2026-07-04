import QtQuick
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Services
import qs.Modules.QuickSettings.Widgets
import "QuickSettingsIcons.js" as QSIcons

// Quick-settings panel content: GNOME Quick Settings functions and layout
// (system row, sliders, 2-column toggle grid, expanding details) restyled as
// an MD3 surface. System state lives in Quickshell services and the
// qs.Services boundaries; this file only wires state to MD3 controls.
Item {
    id: root

    signal closeRequested

    // "" | "wifi" | "bluetooth" | "output"
    property string detail: ""

    // Layout metrics (structural; desktop-compact density).
    readonly property real pad: 12
    readonly property real cellSpacing: 8
    readonly property real cellWidth: 188
    readonly property real contentWidth: cellWidth * 2 + cellSpacing

    // --- derived network state -------------------------------------------
    readonly property var wifiDevice: Networking.devices.values.find(device => device !== null && device.type === DeviceType.Wifi) || null
    readonly property var wiredDevice: Networking.devices.values.find(device => device !== null && device.type === DeviceType.Wired) || null
    readonly property var activeWifiNetwork: wifiDevice ? wifiDevice.networks.values.find(network => network !== null && network.connected) || null : null

    // --- derived bluetooth state -----------------------------------------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btEnabled: btAdapter !== null && btAdapter.enabled
    readonly property var btConnectedDevices: Bluetooth.devices.values.filter(device => device !== null && device.connected)

    // --- battery -----------------------------------------------------------
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.ready && battery.isLaptopBattery
    readonly property int batteryPercent: hasBattery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batteryCharging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge || battery.state === UPowerDeviceState.FullyCharged)

    // Refresh process-backed state whenever the panel becomes visible.
    onVisibleChanged: {
        if (visible) {
            Brightness.refresh();
            Airplane.refresh();
            DoNotDisturb.refresh();
        } else {
            detail = "";
        }
    }

    // Wifi scanning only while the network list is open.
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.detail === "wifi"
        when: root.wifiDevice !== null
    }

    implicitWidth: contentWidth + pad * 2
    implicitHeight: mainColumn.implicitHeight + pad * 2

    Column {
        id: mainColumn

        x: root.pad
        y: root.pad
        width: root.contentWidth
        spacing: root.cellSpacing * 2

        // --- system row (GNOME system.js) --------------------------------
        Item {
            width: parent.width
            implicitHeight: powerButton.implicitHeight

            MD.Button {
                id: batteryButton

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasBattery
                mdState.type: MD.Enum.BtFilledTonal
                icon.name: root.hasBattery ? QSIcons.batteryIcon(root.batteryPercent, root.batteryCharging) : "battery_unknown"
                text: I18n.t("quickSettings.batteryPercent", {
                    "percent": root.batteryPercent
                })
                font.family: Theme.textTypeface

                onClicked: {
                    Session.openSettings("power");
                    root.closeRequested();
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                MD.IconButton {
                    mdState.type: MD.Enum.IBtStandard
                    icon.name: "screenshot_region"

                    onClicked: {
                        root.closeRequested();
                        Session.takeScreenshot();
                    }
                }

                MD.IconButton {
                    mdState.type: MD.Enum.IBtStandard
                    icon.name: "settings"

                    onClicked: {
                        Session.openSettings("");
                        root.closeRequested();
                    }
                }

                MD.IconButton {
                    mdState.type: MD.Enum.IBtStandard
                    icon.name: "lock"

                    onClicked: {
                        root.closeRequested();
                        Session.lock();
                    }
                }

                MD.IconButton {
                    id: powerButton

                    mdState.type: MD.Enum.IBtStandard
                    icon.name: "power_settings_new"

                    onClicked: sessionMenu.open()

                    MD.Menu {
                        id: sessionMenu

                        y: powerButton.height

                        MD.MenuItem {
                            text: I18n.t("quickSettings.session.suspend")
                            icon.name: "mode_standby"
                            font.family: Theme.textTypeface

                            onTriggered: {
                                root.closeRequested();
                                Session.suspend();
                            }
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.session.restart")
                            icon.name: "restart_alt"
                            font.family: Theme.textTypeface

                            onTriggered: {
                                root.closeRequested();
                                Session.reboot();
                            }
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.session.powerOff")
                            icon.name: "power_settings_new"
                            font.family: Theme.textTypeface

                            onTriggered: {
                                root.closeRequested();
                                Session.powerOff();
                            }
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.session.logOut")
                            icon.name: "logout"
                            font.family: Theme.textTypeface

                            onTriggered: {
                                root.closeRequested();
                                Session.logOut();
                            }
                        }
                    }
                }
            }
        }

        // --- main page: sliders + toggle grid ------------------------------
        Column {
            visible: root.detail === ""
            width: parent.width
            spacing: root.cellSpacing

            QuickSlider {
                width: parent.width
                iconName: QSIcons.volumeIcon(Audio.volume, Audio.muted)
                iconReactive: true
                iconChecked: Audio.muted
                value: Audio.volume
                hasDetail: Audio.sinkDevices.length > 1
                expanded: false
                visible: Audio.hasSink

                onMoved: newValue => Audio.setVolume(newValue)
                onIconClicked: Audio.toggleMuted()
                onDetailRequested: root.detail = "output"
            }

            QuickSlider {
                width: parent.width
                iconName: Audio.inputMuted ? "mic_off" : "mic"
                iconReactive: true
                iconChecked: Audio.inputMuted
                value: Audio.inputVolume
                visible: Audio.hasSource && Audio.microphoneInUse

                onMoved: newValue => Audio.setInputVolume(newValue)
                onIconClicked: Audio.toggleInputMuted()
            }

            QuickSlider {
                width: parent.width
                iconName: "brightness_6"
                value: Brightness.percent
                visible: Brightness.available

                onMoved: newValue => Brightness.setPercent(newValue)
            }

            Grid {
                columns: 2
                spacing: root.cellSpacing

                QuickMenuToggle {
                    width: root.cellWidth
                    labelKey: "quickSettings.wifi"
                    iconName: Networking.wifiEnabled ? (root.activeWifiNetwork ? QSIcons.wifiSignalIcon(root.activeWifiNetwork.signalStrength) : "wifi") : "signal_wifi_off"
                    statusText: root.activeWifiNetwork ? root.activeWifiNetwork.name : ""
                    checked: Networking.wifiEnabled
                    expanded: root.detail === "wifi"
                    visible: root.wifiDevice !== null

                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    onExpandRequested: root.detail = root.detail === "wifi" ? "" : "wifi"
                }

                QuickToggle {
                    width: root.cellWidth
                    labelKey: "quickSettings.wired"
                    icon.name: "lan"
                    checked: root.wiredDevice !== null && root.wiredDevice.connected
                    visible: root.wiredDevice !== null && (root.wiredDevice.connected || root.wiredDevice.networks.values.length > 0)

                    onClicked: {
                        if (checked) {
                            root.wiredDevice.disconnect();
                        } else {
                            const known = root.wiredDevice.networks.values.find(network => network !== null && network.known);
                            if (known) {
                                known.connect();
                            }
                        }
                    }
                }

                QuickMenuToggle {
                    width: root.cellWidth
                    labelKey: "quickSettings.bluetooth"
                    iconName: root.btEnabled ? (root.btConnectedDevices.length > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"
                    statusText: root.btConnectedDevices.length > 0 ? I18n.t("quickSettings.bluetoothConnectedCount", {
                        "count": root.btConnectedDevices.length
                    }) : ""
                    checked: root.btEnabled
                    expanded: root.detail === "bluetooth"
                    visible: root.btAdapter !== null

                    onClicked: root.btAdapter.enabled = !root.btAdapter.enabled
                    onExpandRequested: root.detail = root.detail === "bluetooth" ? "" : "bluetooth"
                }

                QuickMenuToggle {
                    id: powerModeToggle

                    width: root.cellWidth
                    labelKey: "quickSettings.powerMode"
                    iconName: PowerMode.iconName
                    statusText: {
                        if (PowerMode.profile === PowerProfile.Performance) {
                            return I18n.t("quickSettings.powerProfile.performance");
                        }
                        if (PowerMode.profile === PowerProfile.PowerSaver) {
                            return I18n.t("quickSettings.powerProfile.powerSaver");
                        }
                        return I18n.t("quickSettings.powerProfile.balanced");
                    }
                    checked: PowerMode.profile !== PowerProfile.Balanced
                    expanded: powerModeMenu.visible
                    visible: PowerMode.available

                    onClicked: PowerMode.setProfile(PowerMode.profile === PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced)
                    onExpandRequested: powerModeMenu.open()

                    MD.Menu {
                        id: powerModeMenu

                        y: powerModeToggle.height

                        MD.MenuItem {
                            text: I18n.t("quickSettings.powerProfile.performance")
                            icon.name: "speed"
                            font.family: Theme.textTypeface
                            visible: PowerMode.hasPerformanceProfile

                            onTriggered: PowerMode.setProfile(PowerProfile.Performance)
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.powerProfile.balanced")
                            icon.name: "balance"
                            font.family: Theme.textTypeface

                            onTriggered: PowerMode.setProfile(PowerProfile.Balanced)
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.powerProfile.powerSaver")
                            icon.name: "energy_savings_leaf"
                            font.family: Theme.textTypeface

                            onTriggered: PowerMode.setProfile(PowerProfile.PowerSaver)
                        }
                    }
                }

                QuickToggle {
                    width: root.cellWidth
                    labelKey: "quickSettings.nightLight"
                    icon.name: "nightlight"
                    checked: NightLight.enabled

                    onClicked: NightLight.toggle()
                }

                QuickToggle {
                    width: root.cellWidth
                    labelKey: "quickSettings.darkStyle"
                    icon.name: "dark_mode"
                    checked: Settings.options.theme.mode === "dark"

                    onClicked: Settings.options.theme.mode = checked ? "light" : "dark"
                }

                QuickToggle {
                    width: root.cellWidth
                    labelKey: "quickSettings.airplaneMode"
                    icon.name: "airplanemode_active"
                    checked: Airplane.enabled
                    visible: Airplane.available

                    onClicked: Airplane.toggle()
                }

                QuickMenuToggle {
                    id: kbdToggle

                    width: root.cellWidth
                    labelKey: "quickSettings.keyboardBacklight"
                    iconName: "keyboard"
                    checked: Brightness.kbdLevel > 0
                    expanded: kbdMenu.visible
                    visible: Brightness.kbdAvailable

                    onClicked: Brightness.toggleKbd()
                    onExpandRequested: kbdMenu.open()

                    MD.Menu {
                        id: kbdMenu

                        y: kbdToggle.height

                        MD.MenuItem {
                            text: I18n.t("quickSettings.kbdBacklight.off")
                            icon.name: "backlight_low"
                            font.family: Theme.textTypeface

                            onTriggered: Brightness.setKbdLevel(0)
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.kbdBacklight.low")
                            icon.name: "backlight_high"
                            font.family: Theme.textTypeface

                            onTriggered: Brightness.setKbdLevel(Math.max(1, Math.ceil(Brightness.kbdMax / 2)))
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.kbdBacklight.high")
                            icon.name: "backlight_high"
                            font.family: Theme.textTypeface

                            onTriggered: Brightness.setKbdLevel(Brightness.kbdMax)
                        }
                    }
                }

                QuickToggle {
                    width: root.cellWidth
                    labelKey: "quickSettings.doNotDisturb"
                    icon.name: "do_not_disturb_on"
                    checked: DoNotDisturb.enabled
                    visible: DoNotDisturb.available

                    onClicked: DoNotDisturb.toggle()
                }
            }
        }

        // --- detail pages --------------------------------------------------
        Column {
            visible: root.detail !== ""
            width: parent.width
            spacing: root.cellSpacing

            Row {
                spacing: root.cellSpacing

                MD.IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    mdState.type: MD.Enum.IBtStandard
                    icon.name: "arrow_back"

                    onClicked: root.detail = ""
                }

                MD.Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.detail === "wifi") {
                            return I18n.t("quickSettings.wifi");
                        }
                        if (root.detail === "bluetooth") {
                            return I18n.t("quickSettings.bluetooth");
                        }
                        return I18n.t("quickSettings.outputDevice");
                    }
                    color: MD.Token.color.on_surface
                    typescale: MD.Token.typescale.title_medium
                    font.family: Theme.textTypeface
                }
            }

            Loader {
                width: parent.width
                sourceComponent: {
                    if (root.detail === "wifi") {
                        return wifiDetail;
                    }
                    if (root.detail === "bluetooth") {
                        return bluetoothDetail;
                    }
                    if (root.detail === "output") {
                        return outputDetail;
                    }
                    return null;
                }
            }
        }
    }

    // --- wifi network list --------------------------------------------------
    Component {
        id: wifiDetail

        Column {
            spacing: 0

            // Which network shows the inline password field.
            property var pendingNetwork: null

            MD.LinearIndicator {
                width: parent.width
                visible: root.wifiDevice !== null && root.wifiDevice.networks.values.length === 0
            }

            Repeater {
                model: root.wifiDevice ? root.wifiDevice.networks.values.slice().sort((a, b) => (b.connected ? 2 : b.signalStrength > 1 ? b.signalStrength / 100 : b.signalStrength) - (a.connected ? 2 : a.signalStrength > 1 ? a.signalStrength / 100 : a.signalStrength)).slice(0, 10) : []

                Column {
                    id: wifiRow

                    required property var modelData
                    required property int index

                    width: parent.width

                    MD.ListItem {
                        width: parent.width
                        index: wifiRow.index
                        model: wifiRow.modelData
                        text: wifiRow.modelData.name
                        icon.name: QSIcons.wifiSignalIcon(wifiRow.modelData.signalStrength)
                        font.family: Theme.textTypeface
                        radius: MD.Token.shape.corner.medium

                        trailing: MD.Icon {
                            name: wifiRow.modelData.connected ? "check" : "lock"
                            visible: wifiRow.modelData.connected || wifiRow.modelData.security !== WifiSecurityType.Open
                            size: 16
                            color: MD.MProp.color.on_surface_variant
                        }

                        onClicked: {
                            if (wifiRow.modelData.connected) {
                                wifiRow.modelData.disconnect();
                            } else if (wifiRow.modelData.known || wifiRow.modelData.security === WifiSecurityType.Open) {
                                wifiRow.modelData.connect();
                                root.detail = "";
                            } else {
                                pendingNetwork = pendingNetwork === wifiRow.modelData ? null : wifiRow.modelData;
                            }
                        }
                    }

                    Row {
                        visible: pendingNetwork === wifiRow.modelData
                        width: parent.width
                        spacing: root.cellSpacing

                        MD.TextField {
                            id: pskField

                            width: parent.width - connectButton.width - root.cellSpacing
                            echoMode: TextInput.Password
                            placeholderText: I18n.t("quickSettings.wifiPassword")

                            onAccepted: connectButton.clicked()
                        }

                        MD.Button {
                            id: connectButton

                            anchors.verticalCenter: parent.verticalCenter
                            mdState.type: MD.Enum.BtFilledTonal
                            text: I18n.t("quickSettings.connect")
                            font.family: Theme.textTypeface

                            onClicked: {
                                wifiRow.modelData.connectWithPsk(pskField.text);
                                pendingNetwork = null;
                                root.detail = "";
                            }
                        }
                    }
                }
            }
        }
    }

    // --- bluetooth device list ------------------------------------------------
    Component {
        id: bluetoothDetail

        Column {
            spacing: 0

            Repeater {
                model: root.btAdapter ? root.btAdapter.devices.values.filter(device => device !== null && (device.paired || device.bonded || device.connected)) : []

                MD.ListItem {
                    id: btRow

                    required property var modelData

                    width: parent.width
                    model: btRow.modelData
                    text: btRow.modelData.name.length > 0 ? btRow.modelData.name : btRow.modelData.address
                    icon.name: "bluetooth"
                    font.family: Theme.textTypeface
                    radius: MD.Token.shape.corner.medium

                    trailing: MD.Icon {
                        name: "check"
                        visible: btRow.modelData.connected
                        size: 16
                        color: MD.MProp.color.on_surface_variant
                    }

                    onClicked: {
                        if (btRow.modelData.connected) {
                            btRow.modelData.disconnect();
                        } else {
                            btRow.modelData.connect();
                        }
                    }
                }
            }
        }
    }

    // --- output device list -----------------------------------------------------
    Component {
        id: outputDetail

        Column {
            spacing: 0

            Repeater {
                model: Audio.sinkDevices

                MD.ListItem {
                    id: sinkRow

                    required property var modelData

                    width: parent.width
                    model: sinkRow.modelData
                    text: sinkRow.modelData.description.length > 0 ? sinkRow.modelData.description : sinkRow.modelData.name
                    icon.name: "speaker"
                    font.family: Theme.textTypeface
                    radius: MD.Token.shape.corner.medium

                    trailing: MD.Icon {
                        name: "check"
                        visible: Audio.sink !== null && sinkRow.modelData.id === Audio.sink.id
                        size: 16
                        color: MD.MProp.color.on_surface_variant
                    }

                    onClicked: {
                        Audio.setPreferredSink(sinkRow.modelData);
                        root.detail = "";
                    }
                }
            }
        }
    }
}
