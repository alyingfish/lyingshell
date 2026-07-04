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

// Quick-settings panel content mirroring the web-prototype quick-settings
// panel: battery/settings/power header, slider rows, a paged two-row tile
// grid with page-dot tabs, and full-panel detail pages that keep at least
// the measured main-view height. System state lives in Quickshell services
// and the qs.Services boundaries; this file only wires state to MD3 controls.
Item {
    id: root

    signal closeRequested

    // "" | "wifi" | "bluetooth" | "output" | "power" | "kbd"
    property string detail: ""

    // Layout metrics (web prototype: 360px panel, 14px padding, 14px section
    // gap, 8px tile gap).
    readonly property real pad: 14
    readonly property real cellSpacing: 8
    readonly property real contentWidth: 360 - pad * 2
    readonly property real cellWidth: (contentWidth - cellSpacing) / 2

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
    readonly property bool batteryFull: hasBattery && battery.state === UPowerDeviceState.FullyCharged

    // Refresh process-backed state whenever the panel becomes visible.
    onVisibleChanged: {
        if (visible) {
            Brightness.refresh();
            Airplane.refresh();
        } else {
            detail = "";
            pager.page = 0;
        }
    }

    // Test-only surface (tests/e2e/QuickSettingsIpcDriver.qml).
    readonly property int page: pager.page
    readonly property int pageCount: pager.pageCount
    readonly property Item tileArea: pager
    readonly property Item volumeRow: volumeSlider

    function setPage(page: int) {
        pager.page = Math.max(0, Math.min(pager.pageCount - 1, page));
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

    // Prototype: detail pages keep at least the measured main-view height
    // (the web version snapshots the main panel height in a layout effect).
    property real mainViewHeight: 0
    onImplicitHeightChanged: if (detail === "")
        mainViewHeight = implicitHeight
    Component.onCompleted: mainViewHeight = implicitHeight

    // Prototype quick-detail-row: a text-only 42px list row (12px radius,
    // 10px side padding); the active entry reads as secondary-container with
    // a trailing "Current" badge.
    component DetailRow: MD.ListItem {
        id: detailRow

        property bool current: false

        width: parent ? parent.width : 0
        implicitHeight: 42
        leftPadding: 10
        rightPadding: 10
        radius: MD.Token.shape.corner.medium
        font.family: Theme.textTypeface
        font.pixelSize: MD.Token.typescale.body_medium.size
        font.weight: MD.Token.typescale.body_medium.weight

        MD.MProp.textColor: detailRow.current ? MD.Token.color.on_secondary_container : MD.Token.color.on_surface
        MD.MProp.backgroundColor: detailRow.current ? MD.Token.color.secondary_container : "transparent"

        trailing: MD.Text {
            visible: detailRow.current
            text: I18n.t("quickSettings.current")
            typescale: MD.Token.typescale.label_medium
            font.family: Theme.textTypeface
            // Prototype detail-row-state opacity.
            opacity: 0.78
        }
    }

    Column {
        id: mainColumn

        x: root.pad
        y: root.pad
        width: root.contentWidth
        spacing: root.pad

        // --- header: battery readout + settings/power actions -------------
        // Main page only: a detail page replaces the whole panel content
        // (web-prototype navigation), header included.
        Item {
            width: parent.width
            // Prototype panel-header row: 36px icon-button boxes.
            implicitHeight: 36
            visible: root.detail === ""

            // Plain status readout, not a button: it triggers nothing.
            // Prototype battery-readout: 20px icon + body-medium text, "AC"
            // with a power glyph on battery-less machines.
            MD.IconLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                icon.name: root.hasBattery ? QSIcons.batteryIcon(root.batteryPercent, root.batteryCharging, root.batteryFull) : "power"
                icon.size: 20
                color: MD.Token.color.on_surface
                text: root.hasBattery ? I18n.t("quickSettings.batteryPercent", {
                    "percent": root.batteryPercent
                }) : I18n.t("quickSettings.acPower")
                label.typescale: MD.Token.typescale.body_medium
                label.useTypescale: true
                label.font.family: Theme.textTypeface
            }

            Row {
                anchors.right: parent.right
                // XS icon buttons carry 4px transparent insets; -4 keeps the
                // visible circles 4px apart (prototype header-actions gap)
                // and the last circle flush with the content edge.
                anchors.rightMargin: -4
                anchors.verticalCenter: parent.verticalCenter
                spacing: -4

                MD.IconButton {
                    id: settingsButton

                    mdState.type: MD.Enum.IBtStandard
                    mdState.size: MD.Enum.XS
                    icon.name: "settings"

                    onClicked: {
                        Session.openSettings("");
                        root.closeRequested();
                    }

                    MD.ToolTip {
                        // Below the button, like bar-tray tooltips (library default is above).
                        y: parent.height + 4
                        text: I18n.t("quickSettings.settings")
                        visible: settingsButton.hovered
                    }
                }

                MD.IconButton {
                    id: powerButton

                    mdState.type: MD.Enum.IBtStandard
                    mdState.size: MD.Enum.XS
                    icon.name: "power_settings_new"

                    onClicked: sessionMenu.open()

                    MD.ToolTip {
                        // Below the button, like bar-tray tooltips (library default is above).
                        y: parent.height + 4
                        text: I18n.t("quickSettings.power")
                        visible: powerButton.hovered && !sessionMenu.visible
                    }

                    MD.Menu {
                        id: sessionMenu

                        // 8px visual offset below the inset button (prototype
                        // power-menu y-offset).
                        y: powerButton.height + 4

                        // One level above the surface_container panel so the
                        // popup reads as elevated over it (MD3 popup over an
                        // already-elevated surface): level3 tone + shadow.
                        mdState.backgroundColor: MD.Token.color.surface_container_high
                        mdState.elevation: MD.Token.elevation.level3

                        // Leading icons are color-coded by consequence so the
                        // options scan apart: neutral lock, calm suspend/restart,
                        // error-red power off, neutral log out.
                        MD.MenuItem {
                            text: I18n.t("quickSettings.lock")
                            icon.name: "lock"
                            font.family: Theme.textTypeface
                            leadingIconColor: MD.Token.color.onSurfaceVariant

                            onTriggered: {
                                root.closeRequested();
                                Session.lock();
                            }
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.session.suspend")
                            icon.name: "mode_standby"
                            font.family: Theme.textTypeface
                            leadingIconColor: MD.Token.color.tertiary

                            onTriggered: {
                                root.closeRequested();
                                Session.suspend();
                            }
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.session.restart")
                            icon.name: "restart_alt"
                            font.family: Theme.textTypeface
                            leadingIconColor: MD.Token.color.primary

                            onTriggered: {
                                root.closeRequested();
                                Session.reboot();
                            }
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.session.powerOff")
                            icon.name: "power_settings_new"
                            font.family: Theme.textTypeface
                            leadingIconColor: MD.Token.color.error

                            onTriggered: {
                                root.closeRequested();
                                Session.powerOff();
                            }
                        }

                        MD.MenuItem {
                            text: I18n.t("quickSettings.session.logOut")
                            icon.name: "logout"
                            font.family: Theme.textTypeface
                            leadingIconColor: MD.Token.color.secondary

                            onTriggered: {
                                root.closeRequested();
                                Session.logOut();
                            }
                        }
                    }
                }
            }
        }

        // --- main page: slider list ----------------------------------------
        Column {
            visible: root.detail === ""
            width: parent.width
            spacing: root.cellSpacing

            QuickSlider {
                id: volumeSlider

                width: parent.width
                iconName: QSIcons.volumeIcon(Audio.volume, Audio.muted)
                iconReactive: true
                iconChecked: Audio.muted
                iconTooltipKey: Audio.muted ? "quickSettings.unmute" : "quickSettings.mute"
                value: Audio.volume
                dimmed: Audio.muted
                hasDetail: Audio.sinkDevices.length > 1
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
                iconTooltipKey: Audio.inputMuted ? "quickSettings.unmute" : "quickSettings.mute"
                value: Audio.inputVolume
                dimmed: Audio.inputMuted
                visible: Audio.hasSource && Audio.microphoneInUse

                onMoved: newValue => Audio.setInputVolume(newValue)
                onIconClicked: Audio.toggleInputMuted()
            }

            // The brightness icon doubles as the night-light toggle (mirrors
            // the volume icon's mute affordance); the grid has no separate
            // Night Light tile.
            QuickSlider {
                width: parent.width
                iconName: NightLight.enabled ? "wb_twilight" : "brightness_6"
                iconReactive: true
                iconChecked: NightLight.enabled
                iconTooltipKey: "quickSettings.nightLight"
                value: Brightness.percent
                visible: Brightness.available

                onMoved: newValue => Brightness.setPercent(newValue)
                onIconClicked: NightLight.toggle()
            }
        }

        // --- main page: paged quick controls ------------------------------
        Column {
            visible: root.detail === ""
            width: parent.width
            spacing: root.cellSpacing

            // Paged tile grid (web-prototype pagination): a fixed two-row
            // window slides vertically over one dense Grid, so
            // hardware-conditional tiles pack without holes and the panel
            // height never changes between pages.
            Item {
                id: pager

                readonly property int pageRows: 2
                // 44 = QuickToggle cell height.
                readonly property real pageStep: pageRows * (44 + root.cellSpacing)
                readonly property int pageCount: Math.max(1, Math.ceil(tileGrid.visibleChildren.length / (2 * pageRows)))
                property int page: 0

                function movePage(delta: int) {
                    page = Math.max(0, Math.min(pageCount - 1, page + delta));
                }

                width: parent.width
                clip: true
                // Prototype viewport: a fixed two-row window even when a
                // page has empty cells.
                implicitHeight: pageRows * 44 + (pageRows - 1) * root.cellSpacing

                onPageCountChanged: page = Math.min(page, pageCount - 1)

                Grid {
                    id: tileGrid

                    columns: 2
                    spacing: root.cellSpacing
                    y: -pager.page * pager.pageStep

                    Behavior on y {
                        NumberAnimation {
                            duration: MD.Token.duration.medium2
                            easing: MD.Token.easing.emphasized
                        }
                    }

                    // Connectivity cluster first: wifi | bluetooth, wired | airplane.
                    QuickMenuToggle {
                        width: root.cellWidth
                        labelKey: "quickSettings.wifi"
                        iconName: Networking.wifiEnabled ? (root.activeWifiNetwork ? QSIcons.wifiSignalIcon(root.activeWifiNetwork.signalStrength) : "wifi") : "signal_wifi_off"
                        statusText: root.activeWifiNetwork ? root.activeWifiNetwork.name : ""
                        checked: Networking.wifiEnabled
                        visible: root.wifiDevice !== null

                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        onExpandRequested: root.detail = "wifi"
                    }

                    QuickMenuToggle {
                        width: root.cellWidth
                        labelKey: "quickSettings.bluetooth"
                        iconName: root.btEnabled ? (root.btConnectedDevices.length > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"
                        statusText: root.btConnectedDevices.length > 0 ? I18n.t("quickSettings.bluetoothConnectedCount", {
                            "count": root.btConnectedDevices.length
                        }) : ""
                        checked: root.btEnabled
                        visible: root.btAdapter !== null

                        onClicked: root.btAdapter.enabled = !root.btAdapter.enabled
                        onExpandRequested: root.detail = "bluetooth"
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

                    QuickToggle {
                        width: root.cellWidth
                        labelKey: "quickSettings.airplaneMode"
                        icon.name: "airplanemode_active"
                        checked: Airplane.enabled
                        visible: Airplane.available

                        onClicked: Airplane.toggle()
                    }

                    QuickMenuToggle {
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
                        visible: PowerMode.available

                        onClicked: PowerMode.setProfile(PowerMode.profile === PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced)
                        onExpandRequested: root.detail = "power"
                    }

                    QuickToggle {
                        width: root.cellWidth
                        labelKey: "quickSettings.darkStyle"
                        icon.name: "dark_mode"
                        checked: Settings.options.theme.mode === "dark"

                        onClicked: Settings.options.theme.mode = checked ? "light" : "dark"
                    }

                    QuickMenuToggle {
                        width: root.cellWidth
                        labelKey: "quickSettings.keyboardBacklight"
                        iconName: "keyboard"
                        checked: Brightness.kbdLevel > 0
                        visible: Brightness.kbdAvailable

                        onClicked: Brightness.toggleKbd()
                        onExpandRequested: root.detail = "kbd"
                    }
                }

                // Prototype: wheel/touchpad anywhere over the tile area
                // (over a tile or the gaps between tiles) flips pages, one
                // per accumulated notch on the dominant scroll axis. Topmost
                // button-less MouseArea: wheel lands here first, clicks fall
                // through to the tiles (same live-proven pattern as the
                // Bar's Workspaces widget; WheelHandler gets no wheel events
                // on the real compositor). Qt's wheel sign is inverted
                // relative to the web's deltaX/deltaY.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton

                    property real acc: 0

                    onWheel: function (wheel) {
                        const angle = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
                        const pixel = Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y) ? wheel.pixelDelta.x : wheel.pixelDelta.y;
                        const result = QSIcons.wheelNotches(acc, angle, pixel);
                        acc = result.acc;
                        if (result.steps !== 0) {
                            pager.movePage(-result.steps);
                        }
                        wheel.accepted = true;
                    }
                }
            }

            // Page dots (web-prototype page-dot tabs): 7px dots inside 24px
            // hit targets; the active page is an 18px primary pill.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: pager.pageCount

                    Item {
                        id: pageDot

                        required property int index
                        readonly property bool current: pager.page === index

                        width: 24
                        height: 24

                        Rectangle {
                            anchors.centerIn: parent
                            width: pageDot.current ? 18 : 7
                            height: 7
                            radius: height / 2
                            color: pageDot.current ? MD.Token.color.primary : MD.Token.color.on_surface_variant
                            // Prototype dot states: rest 0.48, hover 0.86,
                            // selected 1.
                            opacity: pageDot.current ? 1 : dotHover.hovered ? 0.86 : 0.48

                            Behavior on width {
                                NumberAnimation {
                                    duration: MD.Token.duration.short4
                                    easing: MD.Token.easing.standard
                                }
                            }
                        }

                        HoverHandler {
                            id: dotHover
                        }

                        TapHandler {
                            onTapped: pager.page = pageDot.index
                        }
                    }
                }
            }
        }

        // --- detail pages --------------------------------------------------
        Column {
            visible: root.detail !== ""
            width: parent.width
            spacing: root.cellSpacing

            // Quick-detail-header: a fixed 36px row matching the main-page
            // header height, so the leading control and title hold the same
            // position across navigation.
            Item {
                width: parent.width
                implicitHeight: 36

                Row {
                    anchors.left: parent.left
                    // -4 flushes the back button's visible circle (XS icon
                    // buttons carry 4px transparent insets) with the edge.
                    anchors.leftMargin: -4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    MD.IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        mdState.type: MD.Enum.IBtStandard
                        mdState.size: MD.Enum.XS
                        icon.name: "arrow_back"

                        onClicked: root.detail = ""
                    }

                    MD.Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (root.detail === "wifi") {
                                return I18n.t("quickSettings.wifiNetworks");
                            }
                            if (root.detail === "bluetooth") {
                                return I18n.t("quickSettings.bluetoothDevices");
                            }
                            if (root.detail === "power") {
                                return I18n.t("quickSettings.powerMode");
                            }
                            if (root.detail === "kbd") {
                                return I18n.t("quickSettings.keyboardBacklight");
                            }
                            return I18n.t("quickSettings.outputDevice");
                        }
                        color: MD.Token.color.on_surface
                        typescale: MD.Token.typescale.title_small
                        font.family: Theme.textTypeface
                    }
                }
            }

            // Prototype quick-detail-list: rows sit directly on the panel
            // surface (no filled card — MD3 menu-style list), and this region
            // holds the locked main-view height so the detail page never
            // resizes the panel; longer lists scroll inside. Rows align to the
            // panel gutter like the main view; DetailRow carries its own 10px
            // side padding.
            Item {
                width: parent.width
                height: root.mainViewHeight - root.pad * 2 - 36 - root.cellSpacing

                MD.VerticalFlickable {
                    anchors.fill: parent

                    Loader {
                        id: detailLoader

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
                            if (root.detail === "power") {
                                return powerDetail;
                            }
                            if (root.detail === "kbd") {
                                return kbdDetail;
                            }
                            return null;
                        }
                    }
                }
            }
        }
    }

    // --- wifi network list --------------------------------------------------
    Component {
        id: wifiDetail

        Column {
            spacing: 6

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
                    spacing: 6

                    DetailRow {
                        index: wifiRow.index
                        model: wifiRow.modelData
                        text: wifiRow.modelData.name
                        current: wifiRow.modelData.connected

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
            spacing: 6

            Repeater {
                model: root.btAdapter ? root.btAdapter.devices.values.filter(device => device !== null && (device.paired || device.bonded || device.connected)) : []

                DetailRow {
                    id: btRow

                    required property var modelData

                    model: btRow.modelData
                    text: btRow.modelData.name.length > 0 ? btRow.modelData.name : btRow.modelData.address
                    current: btRow.modelData.connected

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
            spacing: 6

            Repeater {
                model: Audio.sinkDevices

                DetailRow {
                    id: sinkRow

                    required property var modelData

                    model: sinkRow.modelData
                    text: sinkRow.modelData.description.length > 0 ? sinkRow.modelData.description : sinkRow.modelData.name
                    current: Audio.sink !== null && sinkRow.modelData.id === Audio.sink.id

                    onClicked: {
                        Audio.setPreferredSink(sinkRow.modelData);
                        root.detail = "";
                    }
                }
            }
        }
    }

    // --- power profile list -------------------------------------------------
    Component {
        id: powerDetail

        Column {
            spacing: 6

            Repeater {
                model: [
                    {
                        "profile": PowerProfile.Performance,
                        "token": "quickSettings.powerProfile.performance",
                        "available": PowerMode.hasPerformanceProfile
                    },
                    {
                        "profile": PowerProfile.Balanced,
                        "token": "quickSettings.powerProfile.balanced",
                        "available": true
                    },
                    {
                        "profile": PowerProfile.PowerSaver,
                        "token": "quickSettings.powerProfile.powerSaver",
                        "available": true
                    }
                ]

                DetailRow {
                    id: profileRow

                    required property var modelData

                    model: profileRow.modelData
                    visible: profileRow.modelData.available
                    text: I18n.t(profileRow.modelData.token)
                    current: PowerMode.profile === profileRow.modelData.profile

                    onClicked: {
                        PowerMode.setProfile(profileRow.modelData.profile);
                        root.detail = "";
                    }
                }
            }
        }
    }

    // --- keyboard backlight levels --------------------------------------------
    Component {
        id: kbdDetail

        Column {
            spacing: 6

            // Off / half / max mirror the old menu levels.
            Repeater {
                model: [
                    {
                        "level": 0,
                        "token": "quickSettings.kbdBacklight.off"
                    },
                    {
                        "level": Math.max(1, Math.ceil(Brightness.kbdMax / 2)),
                        "token": "quickSettings.kbdBacklight.low"
                    },
                    {
                        "level": Brightness.kbdMax,
                        "token": "quickSettings.kbdBacklight.high"
                    }
                ]

                DetailRow {
                    id: kbdRow

                    required property var modelData

                    model: kbdRow.modelData
                    text: I18n.t(kbdRow.modelData.token)
                    current: Brightness.kbdLevel === kbdRow.modelData.level

                    onClicked: {
                        Brightness.setKbdLevel(kbdRow.modelData.level);
                        root.detail = "";
                    }
                }
            }
        }
    }
}
