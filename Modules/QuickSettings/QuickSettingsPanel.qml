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
import qs.Services.Niri
import qs.Modules.Material
import qs.Modules.QuickSettings.Widgets
import "../Material/Motion.js" as Motion
import "QuickSettingsIcons.js" as QSIcons

// Quick-settings panel content mirroring the web prototype: a 344px card
// (12px padding, 10px section gap) of header actions + battery pill, two
// expandable rows (tools, power mode), expressive sliders, a horizontally
// paged toggle-tile grid with page dots, and sliding detail views (Wi-Fi /
// Bluetooth / Sound output / Keyboard). System state lives in Quickshell
// services and the qs.Services boundaries; this file only wires state to
// MD3 controls. Motion map: the prototype's bouncy `--spring` is
// Motion.spatialFast, its `--spring-soft` is Motion.spatialDefault, and its
// short standard fades are the effects springs.
Item {
    id: root

    signal closeRequested

    // Mirrors QuickSettings.panelOpen so the staggered entrance can run at
    // the start of the card's open transform, not at first visibility.
    property bool open: false

    // "" | "wifi" | "bluetooth" | "output" | "kbd"
    property string detail: ""
    // The mounted detail page: lags `detail` on close so the exit slide has
    // content to fade out.
    property string shownDetail: ""

    // Layout metrics (web prototype: 344px panel, 12px padding, 10px section
    // gap, 6px tile gap).
    readonly property real pad: 12
    readonly property real sectionGap: 10
    readonly property real contentWidth: 344 - pad * 2
    readonly property real tileGap: 6
    readonly property real cellWidth: (contentWidth - tileGap) / 2

    // --- expandable rows (tools / power mode), mutually exclusive ---------
    property bool toolsOpen: false
    property bool pmodeOpen: false
    // Instant collapse (no spring) when a detail page must measure the
    // compact panel, mirroring the prototype's collapseRowsInstant().
    property bool revealAnimated: true

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

    // --- color-picker tool result ------------------------------------------
    property color pickedColor: "transparent"
    property bool hasPickedColor: false

    Connections {
        target: Niri

        function onColorPicked(hex) {
            root.pickedColor = hex;
            root.hasPickedColor = true;
            // The picked color lands on the clipboard, GNOME-picker style.
            Quickshell.clipboardText = hex;
        }
    }

    // Refresh process-backed state whenever the panel becomes visible.
    onVisibleChanged: {
        if (visible) {
            Brightness.refresh();
            Airplane.refresh();
            DoNotDisturb.refresh();
        } else {
            detail = "";
            shownDetail = "";
            toolsOpen = false;
            pmodeOpen = false;
            pager.page = 0;
        }
    }

    onOpenChanged: if (open)
        riseAnim.restart()

    onDetailChanged: {
        if (detail !== "") {
            // Lock the compact height before the detail view replaces the
            // main view 1:1 (prototype collapseRowsInstant + height lock).
            revealAnimated = false;
            toolsOpen = false;
            pmodeOpen = false;
            revealAnimated = true;
            shownDetail = detail;
            detailUnload.stop();
        } else {
            detailUnload.restart();
        }
    }

    // Keeps the outgoing detail page mounted through the exit slide.
    Timer {
        id: detailUnload

        interval: 250

        onTriggered: root.shownDetail = ""
    }

    // Test-only surface (tests/e2e/QuickSettingsIpcDriver.qml and
    // tests/qml/tst_quicksettings_motion.qml).
    readonly property int page: pager.page
    readonly property int pageCount: pager.pageCount
    readonly property Item tileArea: pager
    readonly property Item volumeRow: volumeSlider
    readonly property real headerOpacityProbe: headerBlock.opacity
    readonly property real pagerOpacityProbe: pager.opacity
    readonly property real mainSlideProbe: mainTx.x
    readonly property real detailSlideProbe: detailTx.x
    readonly property Item tileTrackProbe: tileTrack

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

    // Detail pages keep exactly the compact main-view height (expandable
    // rows collapsed), so navigation never resizes the panel.
    readonly property real compactContentHeight: 32 + sectionGap + slidersCol.implicitHeight + sectionGap + pager.height + (dotsRow.visible ? sectionGap + dotsRow.height : 0)

    implicitWidth: contentWidth + pad * 2
    implicitHeight: pad * 2 + (detail !== "" ? compactContentHeight : mainColumn.implicitHeight)

    // ======================================================================
    // Main view
    // ======================================================================
    Item {
        id: mainArea

        x: root.pad
        y: root.pad
        width: root.contentWidth
        height: mainColumn.implicitHeight
        // Prototype #qs.detail #viewMain: slide 28px left and fade out.
        enabled: root.detail === ""
        opacity: root.detail === "" ? 1 : 0
        transform: Translate {
            id: mainTx

            x: root.detail === "" ? 0 : -28

            Behavior on x {
                NumberAnimation {
                    duration: Motion.spatialDefault.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spatialDefault.curve
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effectsDefault.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.effectsDefault.curve
            }
        }

        Column {
            id: mainColumn

            width: parent.width
            spacing: root.sectionGap

            // --- header + expandable rows ---------------------------------
            // One block so each open row contributes its own preceding
            // 10px gap (prototype xrow margin-top -10px cancels the flex
            // gap while closed).
            Item {
                id: headerBlock

                readonly property real toolsSpace: root.toolsReveal * (root.sectionGap + 40)
                readonly property real pmodeSpace: root.pmodeReveal * (root.sectionGap + 40)

                width: parent.width
                implicitHeight: 32 + toolsSpace + pmodeSpace

                transform: Translate {
                    id: headerRise
                }

                // --- header row (32px) ---
                Item {
                    width: parent.width
                    height: 32

                    Row {
                        anchors.left: parent.left
                        // XS icon buttons carry 4px transparent insets; -4
                        // flushes the first circle with the content edge and
                        // -2 spacing keeps visible gaps at the prototype 6px.
                        anchors.leftMargin: -4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -2

                        MD.IconButton {
                            id: toolsButton

                            anchors.verticalCenter: parent.verticalCenter
                            mdState.type: MD.Enum.IBtFilledTonal
                            mdState.size: MD.Enum.XS
                            flat: true
                            icon.name: "apps"
                            icon.width: 18
                            icon.height: 18
                            checked: root.toolsOpen

                            // Prototype .ib: surface-container-high chip that
                            // fills primary and squares 16 -> 11 while its
                            // row is open.
                            property color animBackground: root.toolsOpen ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_high
                            property color animText: root.toolsOpen ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface_variant
                            Behavior on animBackground {
                                ColorAnimation {
                                    duration: Motion.effectsDefault.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.effectsDefault.curve
                                }
                            }
                            Behavior on animText {
                                ColorAnimation {
                                    duration: Motion.effectsDefault.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.effectsDefault.curve
                                }
                            }
                            mdState.backgroundColor: animBackground
                            mdState.textColor: animText
                            readonly property real stateCorner: root.toolsOpen && !down ? 11 : mdState.corner
                            mdState.corners: MD.Util.corners(stateCorner)
                            scale: down ? 0.88 : 1
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.spatialFast.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.spatialFast.curve
                                }
                            }

                            onClicked: {
                                root.pmodeOpen = false;
                                root.toolsOpen = !root.toolsOpen;
                            }

                            MD.ToolTip {
                                y: parent.height + 4
                                text: I18n.t("quickSettings.tools")
                                visible: toolsButton.hovered
                            }
                        }

                        // Battery pill: power-mode icon + charge readout;
                        // opens the power-mode row (prototype .batt).
                        MD.Button {
                            id: battPill

                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.hasBattery || PowerMode.available
                            enabled: PowerMode.available
                            checkable: false
                            flat: true
                            topInset: 0
                            bottomInset: 0
                            leftInset: 0
                            rightInset: 0
                            implicitHeight: 32
                            leftPadding: 10
                            rightPadding: 12

                            mdState.size: MD.Enum.XS
                            mdState.type: root.pmodeOpen ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
                            property color animBackground: root.pmodeOpen ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_high
                            property color animText: root.pmodeOpen ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface
                            // Prototype .pmico: the mode glyph reads primary
                            // at rest, on-primary while the row is open.
                            property color animIcon: root.pmodeOpen ? mdState.ctx.color.on_primary : mdState.ctx.color.primary
                            Behavior on animBackground {
                                ColorAnimation {
                                    duration: Motion.effectsDefault.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.effectsDefault.curve
                                }
                            }
                            Behavior on animText {
                                ColorAnimation {
                                    duration: Motion.effectsDefault.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.effectsDefault.curve
                                }
                            }
                            Behavior on animIcon {
                                ColorAnimation {
                                    duration: Motion.effectsDefault.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.effectsDefault.curve
                                }
                            }
                            mdState.backgroundColor: animBackground
                            mdState.textColor: animText
                            readonly property real stateCorner: root.pmodeOpen && !down ? 11 : 16
                            mdState.corners: MD.Util.corners(stateCorner)
                            scale: down ? 0.94 : 1
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.spatialFast.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.spatialFast.curve
                                }
                            }

                            onClicked: {
                                root.toolsOpen = false;
                                root.pmodeOpen = !root.pmodeOpen;
                            }

                            contentItem: Row {
                                spacing: 6

                                MD.Icon {
                                    id: pillModeIcon

                                    anchors.verticalCenter: parent.verticalCenter
                                    name: PowerMode.available ? PowerMode.iconName : QSIcons.batteryIcon(root.batteryPercent, root.batteryCharging, root.hasBattery && root.battery.state === UPowerDeviceState.FullyCharged)
                                    size: 16
                                    color: battPill.animIcon

                                    // Prototype: the pill glyph pops when the
                                    // mode changes.
                                    NumberAnimation {
                                        id: pillIconPop

                                        target: pillModeIcon
                                        property: "scale"
                                        from: 0.5
                                        to: 1
                                        duration: Motion.spatialFast.duration
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Motion.spatialFast.curve
                                    }

                                    Connections {
                                        target: PowerMode

                                        function onProfileChanged() {
                                            pillIconPop.restart();
                                        }
                                    }
                                }

                                MD.Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.hasBattery ? I18n.t("quickSettings.batteryPercent", {
                                        "percent": root.batteryPercent
                                    }) : I18n.t("quickSettings.acPower")
                                    color: battPill.animText
                                    typescale: MD.Token.typescale.label_medium
                                    prominent: true
                                    font.family: Theme.textTypeface
                                }
                            }

                            MD.ToolTip {
                                y: parent.height + 4
                                text: I18n.t("quickSettings.powerMode")
                                visible: battPill.hovered
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        // -4 keeps the last visible circle flush with the
                        // content edge (XS icon-button insets).
                        anchors.rightMargin: -4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -2

                        MD.IconButton {
                            id: settingsButton

                            mdState.type: MD.Enum.IBtStandard
                            mdState.size: MD.Enum.XS
                            icon.name: "settings"
                            icon.width: 18
                            icon.height: 18
                            scale: down ? 0.88 : 1
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.spatialFast.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.spatialFast.curve
                                }
                            }

                            // Prototype #btnSettings:hover: the gear turns.
                            contentItem: Item {
                                implicitWidth: settingsButton.icon.width
                                implicitHeight: settingsButton.icon.height
                                opacity: settingsButton.mdState.contentOpacity

                                MD.Icon {
                                    anchors.centerIn: parent
                                    name: settingsButton.icon.name
                                    size: settingsButton.icon.width
                                    color: settingsButton.mdState.textColor
                                    rotation: settingsButton.hovered ? 55 : 0
                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: Motion.spatialFast.duration
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Motion.spatialFast.curve
                                        }
                                    }
                                }
                            }

                            onClicked: {
                                Session.openSettings();
                                root.closeRequested();
                            }

                            MD.ToolTip {
                                y: parent.height + 4
                                text: I18n.t("quickSettings.settings")
                                visible: settingsButton.hovered
                            }
                        }

                        MD.IconButton {
                            id: powerButton

                            // Prototype .ib-err: error-container chip, the
                            // one emphasized header action.
                            mdState.type: MD.Enum.IBtFilledTonal
                            mdState.size: MD.Enum.XS
                            icon.name: "power_settings_new"
                            icon.width: 18
                            icon.height: 18
                            // flat drops the ElevationRectangle shadow in
                            // every state (IconButton has no `elevation`
                            // prop; mdState.elevation defaults to level1 and
                            // the bg only hides it when flat).
                            flat: true
                            mdState.backgroundColor: mdState.ctx.color.error_container
                            mdState.textColor: mdState.ctx.color.on_error_container
                            scale: down ? 0.88 : 1
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.spatialFast.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.spatialFast.curve
                                }
                            }

                            onClicked: sessionMenu.open()

                            MD.ToolTip {
                                y: parent.height + 4
                                text: I18n.t("quickSettings.power")
                                visible: powerButton.hovered && !sessionMenu.visible
                            }

                            MD.Menu {
                                id: sessionMenu

                                // 8px visual offset below the inset button
                                // (prototype power-menu y-offset).
                                y: powerButton.height + 4

                                // One level above the panel so the popup
                                // reads as elevated over it.
                                mdState.backgroundColor: MD.Token.color.surface_container_high
                                mdState.elevation: MD.Token.elevation.level3

                                // Leading icons are color-coded by
                                // consequence so the options scan apart.
                                MD.MenuItem {
                                    text: I18n.t("quickSettings.lock")
                                    icon.name: "lock"
                                    font.family: Theme.textTypeface
                                    leadingIconColor: MD.Token.color.on_surface_variant

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

                // --- tools row (prototype #rowTools) ---
                Item {
                    y: 32
                    width: parent.width
                    height: headerBlock.toolsSpace
                    clip: true
                    opacity: root.toolsReveal

                    Row {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 40
                        spacing: 8

                        ToolChip {
                            icon.name: "colorize"
                            alt: false
                            tooltipKey: "quickSettings.tool.colorPicker"

                            onClicked: {
                                root.toolsOpen = false;
                                Session.pickColor();
                            }

                            // Picked-color swatch (prototype .cdot).
                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                width: 11
                                height: 11
                                radius: 5.5
                                visible: root.hasPickedColor
                                color: root.pickedColor
                                border.width: 2
                                border.color: MD.Token.color.surface_container_low
                            }
                        }

                        ToolChip {
                            icon.name: "screenshot_monitor"
                            alt: true
                            tooltipKey: "quickSettings.tool.screenshot"

                            onClicked: {
                                root.toolsOpen = false;
                                root.closeRequested();
                                screenshotDelay.restart();
                            }
                        }

                        ToolChip {
                            icon.name: "calculate"
                            alt: false
                            tooltipKey: "quickSettings.tool.calculator"

                            onClicked: {
                                root.toolsOpen = false;
                                root.closeRequested();
                                Session.openCalculator();
                            }
                        }
                    }
                }

                // --- power-mode row (prototype #rowPmode) ---
                Item {
                    y: 32 + headerBlock.toolsSpace
                    width: parent.width
                    height: headerBlock.pmodeSpace
                    clip: true
                    opacity: root.pmodeReveal

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 40
                        radius: 20
                        color: MD.Token.color.surface_container

                        MD.IconLabel {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: pmodeGroup.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Qt.AlignLeft
                            spacing: 10
                            icon.name: "schedule"
                            icon.size: 18
                            icon.color: MD.Token.color.on_surface_variant
                            color: MD.Token.color.on_surface
                            text: root.pmodeLabel
                            label.typescale: MD.Token.typescale.label_large
                            label.prominent: true
                            label.useTypescale: true
                            label.font.family: Theme.textTypeface
                        }

                        ConnectedButtonGroup {
                            id: pmodeGroup

                            anchors.right: parent.right
                            anchors.rightMargin: 3
                            anchors.verticalCenter: parent.verticalCenter
                            // Prototype .pmode: 42px icon-only segments, the
                            // selected one springs to 52px.
                            width: 142
                            implicitHeight: 34
                            gap: 3
                            innerCorner: 6
                            selectedWeight: 52 / 42
                            labelStyle: MD.Enum.IconOnly
                            textTypeface: Theme.textTypeface
                            model: [
                                {
                                    "icon": "energy_savings_leaf",
                                    "text": I18n.t("quickSettings.powerProfile.powerSaver"),
                                    "value": PowerProfile.PowerSaver,
                                    "available": true
                                },
                                {
                                    "icon": "speed",
                                    "text": I18n.t("quickSettings.powerProfile.balanced"),
                                    "value": PowerProfile.Balanced,
                                    "available": true
                                },
                                {
                                    "icon": "bolt",
                                    "text": I18n.t("quickSettings.powerProfile.performance"),
                                    "available": PowerMode.hasPerformanceProfile,
                                    "value": PowerProfile.Performance
                                }
                            ].filter(profile => profile.available)
                            current: PowerMode.profile

                            onSelected: value => PowerMode.setProfile(value)
                        }
                    }
                }
            }

            // --- sliders ----------------------------------------------------
            Column {
                id: slidersCol

                width: parent.width
                // Prototype .sliders gap.
                spacing: 8

                transform: Translate {
                    id: slidersRise
                }

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

                QuickSlider {
                    width: parent.width
                    // Plain level readout (prototype briIco); night light
                    // lives on its own tile now.
                    iconName: QSIcons.brightnessIcon(Brightness.percent)
                    value: Brightness.percent
                    visible: Brightness.available

                    onMoved: newValue => Brightness.setPercent(newValue)
                }
            }

            // --- paged toggle-tile grid -------------------------------------
            Item {
                id: pager

                readonly property var shownTiles: [wifiTile, btTile, wiredTile, airplaneTile, darkTile, nightTile, dndTile, kbdTile].filter(tile => tile.shown)
                readonly property int pageCount: Math.max(1, Math.ceil(shownTiles.length / 6))
                readonly property int firstPageRows: Math.ceil(Math.min(Math.max(shownTiles.length, 1), 6) / 2)
                property int page: 0
                // Live drag offset from the swipe handler (prototype
                // .tiles-track.drag follows the pointer 1:1).
                property real dragOffset: 0

                function movePage(delta: int) {
                    page = Math.max(0, Math.min(pageCount - 1, page + delta));
                }

                function slotX(index: int): real {
                    if (index < 0) {
                        return 0;
                    }
                    return Math.floor(index / 6) * width + (index % 2) * (root.cellWidth + root.tileGap);
                }

                function slotY(index: int): real {
                    if (index < 0) {
                        return 0;
                    }
                    return Math.floor((index % 6) / 2) * (44 + root.tileGap);
                }

                width: parent.width
                height: firstPageRows * 44 + (firstPageRows - 1) * root.tileGap
                clip: true

                transform: Translate {
                    id: pagerRise
                }

                onPageCountChanged: page = Math.min(page, pageCount - 1)

                Item {
                    id: tileTrack

                    width: pager.pageCount * pager.width
                    height: pager.height
                    x: -pager.page * pager.width + pager.dragOffset

                    Behavior on x {
                        enabled: !tileSwipe.active
                        NumberAnimation {
                            duration: Motion.spatialDefault.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.spatialDefault.curve
                        }
                    }

                    // Connectivity cluster first: wifi | bluetooth, then
                    // wired | airplane, appearance, and page 2 extras. Slots
                    // pack in shown order, 6 per page, prototype-style.
                    QuickMenuToggle {
                        id: wifiTile

                        readonly property bool shown: root.wifiDevice !== null

                        x: pager.slotX(pager.shownTiles.indexOf(wifiTile))
                        y: pager.slotY(pager.shownTiles.indexOf(wifiTile))
                        width: root.cellWidth
                        visible: shown
                        labelKey: "quickSettings.wifi"
                        iconName: root.activeWifiNetwork ? QSIcons.wifiSignalIcon(root.activeWifiNetwork.signalStrength) : "wifi"
                        offIconName: "signal_wifi_off"
                        statusText: root.activeWifiNetwork ? root.activeWifiNetwork.name : ""
                        checked: Networking.wifiEnabled

                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        onExpandRequested: root.detail = "wifi"
                    }

                    QuickMenuToggle {
                        id: btTile

                        readonly property bool shown: root.btAdapter !== null

                        x: pager.slotX(pager.shownTiles.indexOf(btTile))
                        y: pager.slotY(pager.shownTiles.indexOf(btTile))
                        width: root.cellWidth
                        visible: shown
                        labelKey: "quickSettings.bluetooth"
                        iconName: root.btConnectedDevices.length > 0 ? "bluetooth_connected" : "bluetooth"
                        offIconName: "bluetooth_disabled"
                        statusText: root.btConnectedDevices.length > 0 ? I18n.t("quickSettings.bluetoothConnectedCount", {
                            "count": root.btConnectedDevices.length
                        }) : ""
                        checked: root.btEnabled

                        onClicked: root.btAdapter.enabled = !root.btAdapter.enabled
                        onExpandRequested: root.detail = "bluetooth"
                    }

                    QuickToggle {
                        id: wiredTile

                        readonly property bool shown: root.wiredDevice !== null && (root.wiredDevice.connected || root.wiredDevice.networks.values.length > 0)

                        x: pager.slotX(pager.shownTiles.indexOf(wiredTile))
                        y: pager.slotY(pager.shownTiles.indexOf(wiredTile))
                        width: root.cellWidth
                        visible: shown
                        labelKey: "quickSettings.wired"
                        icon.name: "lan"
                        checked: root.wiredDevice !== null && root.wiredDevice.connected

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
                        id: airplaneTile

                        readonly property bool shown: Airplane.available

                        x: pager.slotX(pager.shownTiles.indexOf(airplaneTile))
                        y: pager.slotY(pager.shownTiles.indexOf(airplaneTile))
                        width: root.cellWidth
                        visible: shown
                        labelKey: "quickSettings.airplaneMode"
                        icon.name: "airplanemode_active"
                        checked: Airplane.enabled

                        onClicked: Airplane.toggle()
                    }

                    QuickToggle {
                        id: darkTile

                        readonly property bool shown: true

                        x: pager.slotX(pager.shownTiles.indexOf(darkTile))
                        y: pager.slotY(pager.shownTiles.indexOf(darkTile))
                        width: root.cellWidth
                        labelKey: "quickSettings.darkStyle"
                        // Prototype tile-dark: sun at rest, moon when on,
                        // outline glyphs that fill on hover.
                        icon.name: "dark_mode"
                        offIconName: "light_mode"
                        fillOnHover: true
                        checked: Settings.options.theme.mode === "dark"

                        onClicked: Settings.options.theme.mode = checked ? "light" : "dark"
                    }

                    QuickToggle {
                        id: nightTile

                        readonly property bool shown: true

                        x: pager.slotX(pager.shownTiles.indexOf(nightTile))
                        y: pager.slotY(pager.shownTiles.indexOf(nightTile))
                        width: root.cellWidth
                        visible: shown
                        labelKey: "quickSettings.nightLight"
                        icon.name: "wb_twilight"
                        checked: NightLight.enabled

                        onClicked: NightLight.toggle()
                    }

                    QuickToggle {
                        id: dndTile

                        readonly property bool shown: DoNotDisturb.available

                        x: pager.slotX(pager.shownTiles.indexOf(dndTile))
                        y: pager.slotY(pager.shownTiles.indexOf(dndTile))
                        width: root.cellWidth
                        visible: shown
                        labelKey: "quickSettings.doNotDisturb"
                        icon.name: "do_not_disturb_on"
                        checked: DoNotDisturb.enabled

                        onClicked: DoNotDisturb.toggle()
                    }

                    QuickMenuToggle {
                        id: kbdTile

                        readonly property bool shown: Brightness.kbdAvailable

                        x: pager.slotX(pager.shownTiles.indexOf(kbdTile))
                        y: pager.slotY(pager.shownTiles.indexOf(kbdTile))
                        width: root.cellWidth
                        visible: shown
                        labelKey: "quickSettings.keyboardBacklight"
                        // Backlight glyphs, not an input-device keyboard
                        // (todos: "keyboard button icon should be changed").
                        iconName: "backlight_high"
                        offIconName: "backlight_low"
                        checked: Brightness.kbdLevel > 0

                        onClicked: Brightness.toggleKbd()
                        onExpandRequested: root.detail = "kbd"
                    }
                }

                // Pointer-drag swipe between pages (prototype tiles-track
                // drag): passive until the drag threshold, then it takes the
                // grab from the pressed tile so the release cannot also
                // toggle it.
                DragHandler {
                    id: tileSwipe

                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false

                    onActiveTranslationChanged: if (active)
                        pager.dragOffset = activeTranslation.x
                    onActiveChanged: {
                        if (!active) {
                            const moved = pager.dragOffset;
                            pager.dragOffset = 0;
                            if (Math.abs(moved) > 45) {
                                pager.movePage(moved < 0 ? 1 : -1);
                            }
                        }
                    }
                }

                // Wheel/touchpad anywhere over the tile area flips pages,
                // one per accumulated notch on the dominant scroll axis.
                // Topmost button-less MouseArea: wheel lands here first,
                // clicks fall through to the tiles (WheelHandler gets no
                // wheel events on the live compositor). Qt's wheel sign is
                // inverted relative to the web's deltaX/deltaY.
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

            // --- page dots (prototype .tiles-dots) --------------------------
            Item {
                id: dotsRow

                width: parent.width
                height: 12
                visible: pager.pageCount > 1

                transform: Translate {
                    id: dotsRise
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: pager.pageCount

                        Rectangle {
                            id: pageDot

                            required property int index
                            readonly property bool current: pager.page === index

                            anchors.verticalCenter: parent.verticalCenter
                            // 6px dot; the active page morphs to a 20px
                            // primary pill.
                            width: current ? 20 : 6
                            height: 6
                            radius: 3
                            color: current ? MD.Token.color.primary : MD.Token.color.outline_variant

                            Behavior on width {
                                NumberAnimation {
                                    duration: Motion.spatialFast.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.spatialFast.curve
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Motion.effectsSlow.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Motion.effectsSlow.curve
                                }
                            }

                            TapHandler {
                                // Extends the 6px dot to a usable hit target.
                                margin: 8

                                onTapped: pager.page = pageDot.index
                            }
                        }
                    }
                }
            }
        }
    }

    // Staggered entrance (prototype rise keyframes + nth-child delays):
    // geometry on the spatial spring, opacity on the effects spring.
    SequentialAnimation {
        id: riseAnim

        ScriptAction {
            script: {
                for (const [item, ty] of [[headerBlock, headerRise], [slidersCol, slidersRise], [pager, pagerRise], [dotsRow, dotsRise]]) {
                    item.opacity = 0;
                    ty.y = -10;
                }
            }
        }

        ParallelAnimation {
            RiseSeq {
                delay: 20
                riseItem: headerBlock
                riseTranslate: headerRise
            }
            RiseSeq {
                delay: 110
                riseItem: slidersCol
                riseTranslate: slidersRise
            }
            RiseSeq {
                delay: 140
                riseItem: pager
                riseTranslate: pagerRise
            }
            RiseSeq {
                delay: 0
                riseItem: dotsRow
                riseTranslate: dotsRise
            }
        }
    }

    component RiseSeq: SequentialAnimation {
        property int delay: 0
        required property Item riseItem
        required property Translate riseTranslate

        PauseAnimation {
            duration: delay
        }

        ParallelAnimation {
            NumberAnimation {
                target: riseTranslate
                property: "y"
                to: 0
                duration: Motion.spatialFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast.curve
            }
            NumberAnimation {
                target: riseItem
                property: "opacity"
                to: 1
                duration: Motion.effectsDefault.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.effectsDefault.curve
            }
        }
    }

    // Expandable-row reveals (prototype grid-template-rows 0fr -> 1fr on the
    // soft spring; each open row also restores its preceding section gap).
    property real toolsReveal: toolsOpen ? 1 : 0
    Behavior on toolsReveal {
        enabled: root.revealAnimated
        NumberAnimation {
            duration: Motion.spatialDefault.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatialDefault.curve
        }
    }
    property real pmodeReveal: pmodeOpen ? 1 : 0
    Behavior on pmodeReveal {
        enabled: root.revealAnimated
        NumberAnimation {
            duration: Motion.spatialDefault.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatialDefault.curve
        }
    }

    // Power-mode row label: remaining battery estimate when one exists,
    // otherwise the current profile name.
    readonly property string pmodeLabel: {
        if (hasBattery && !batteryCharging && battery.timeToEmpty > 0) {
            return I18n.t("quickSettings.timeLeft", {
                "hours": Math.floor(battery.timeToEmpty / 3600),
                "minutes": Math.floor(battery.timeToEmpty % 3600 / 60)
            });
        }
        if (hasBattery && batteryCharging && battery.timeToFull > 0) {
            return I18n.t("quickSettings.timeUntilFull", {
                "hours": Math.floor(battery.timeToFull / 3600),
                "minutes": Math.floor(battery.timeToFull % 3600 / 60)
            });
        }
        if (PowerMode.profile === PowerProfile.Performance) {
            return I18n.t("quickSettings.powerProfile.performance");
        }
        if (PowerMode.profile === PowerProfile.PowerSaver) {
            return I18n.t("quickSettings.powerProfile.powerSaver");
        }
        return I18n.t("quickSettings.powerProfile.balanced");
    }

    // Delays niri's screenshot UI until the panel's close animation cleared
    // the frame it freezes.
    Timer {
        id: screenshotDelay

        interval: 300

        onTriggered: Session.takeScreenshot()
    }

    // Tools-row chip (prototype .tools-row .ib): equal-width 40px tonal
    // chips in an M3E round/square rhythm; hover morphs the shape only. The
    // background is overridden so the corner spring bypasses MState's
    // internal 100ms corner Behavior (which cannot render a hover spring).
    component ToolChip: MD.Button {
        id: chip

        property bool alt: false
        property string tooltipKey: ""

        readonly property real targetCorner: (alt ? chip.hovered : !chip.hovered) ? 20 : 12
        property real renderCorner: targetCorner
        Behavior on renderCorner {
            NumberAnimation {
                duration: Motion.spatialDefault.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialDefault.curve
            }
        }

        width: (root.contentWidth - 2 * 8) / 3
        implicitHeight: 40
        checkable: false
        flat: true
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0
        mdState.size: MD.Enum.XS
        mdState.type: MD.Enum.BtFilledTonal
        mdState.backgroundColor: mdState.ctx.color.surface_container_high
        mdState.textColor: mdState.ctx.color.on_surface_variant
        scale: down ? 0.88 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Motion.spatialDefault.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialDefault.curve
            }
        }

        contentItem: Item {
            implicitWidth: 18
            implicitHeight: 18
            opacity: chip.mdState.contentOpacity

            MD.Icon {
                anchors.centerIn: parent
                name: chip.icon.name
                size: 18
                color: chip.mdState.textColor
            }
        }

        background: MD.ElevationRectangle {
            implicitHeight: 40
            corners: MD.Util.corners(chip.renderCorner)
            color: chip.mdState.backgroundColor
            elevationVisible: false

            MD.Ripple {
                anchors.fill: parent
                corners: parent.corners
                pressX: chip.pressX
                pressY: chip.pressY
                pressed: chip.pressed
                stateOpacity: chip.mdState.stateLayerOpacity
                color: chip.mdState.stateLayerColor
            }

            MD.FocusIndicator {
                corners: parent.corners
                active: chip.visualFocus
            }
        }

        MD.ToolTip {
            y: parent.height + 4
            text: chip.tooltipKey.length > 0 ? I18n.t(chip.tooltipKey) : ""
            visible: chip.hovered && text.length > 0
        }
    }

    // ======================================================================
    // Detail view (prototype #viewDetail): slides in over the locked-height
    // panel; back + title + switch header, then a scrolling device list.
    // ======================================================================
    Item {
        id: detailArea

        x: root.pad
        y: root.pad
        width: root.contentWidth
        height: root.compactContentHeight
        visible: root.shownDetail !== ""
        enabled: root.detail !== ""
        opacity: root.detail !== "" ? 1 : 0
        transform: Translate {
            id: detailTx

            x: root.detail !== "" ? 0 : 44

            Behavior on x {
                NumberAnimation {
                    duration: Motion.spatialDefault.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spatialDefault.curve
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effectsDefault.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.effectsDefault.curve
            }
        }

        // --- detail header (prototype .dv-head) ---
        Item {
            id: detailHead

            width: parent.width
            height: 32

            Row {
                anchors.left: parent.left
                anchors.leftMargin: -4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                MD.IconButton {
                    id: backButton

                    anchors.verticalCenter: parent.verticalCenter
                    mdState.type: MD.Enum.IBtStandard
                    mdState.size: MD.Enum.XS
                    icon.name: "arrow_back"
                    icon.width: 18
                    icon.height: 18
                    scale: down ? 0.88 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: Motion.spatialFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.spatialFast.curve
                        }
                    }

                    onClicked: root.detail = ""

                    MD.ToolTip {
                        y: parent.height + 4
                        text: I18n.t("quickSettings.back")
                        visible: backButton.hovered
                    }
                }

                MD.Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.shownDetail === "wifi") {
                            return I18n.t("quickSettings.wifi");
                        }
                        if (root.shownDetail === "bluetooth") {
                            return I18n.t("quickSettings.bluetooth");
                        }
                        if (root.shownDetail === "kbd") {
                            return I18n.t("quickSettings.keyboardBacklight");
                        }
                        return I18n.t("quickSettings.outputDevice");
                    }
                    color: MD.Token.color.on_surface
                    typescale: MD.Token.typescale.title_medium
                    prominent: true
                    font.family: Theme.textTypeface
                }
            }

            // Prototype .swt mini switch: gates the wifi/bluetooth radios.
            MD.Switch {
                id: dvSwitch

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.shownDetail === "wifi" || root.shownDetail === "bluetooth"

                // A Binding object re-asserts service state after user
                // toggles wrote `checked` directly.
                Binding {
                    target: dvSwitch
                    property: "checked"
                    value: root.shownDetail === "wifi" ? Networking.wifiEnabled : root.btEnabled
                }

                onToggled: {
                    if (root.shownDetail === "wifi") {
                        Networking.wifiEnabled = checked;
                    } else if (root.btAdapter !== null) {
                        root.btAdapter.enabled = checked;
                    }
                }

                // Prototype 34x20 track, 10px outline thumb growing to a
                // 15px filled one; springs on the thumb travel and size.
                indicator: Rectangle {
                    id: swtTrack

                    width: 34
                    height: 20
                    radius: 10
                    y: (dvSwitch.height - height) / 2
                    color: dvSwitch.checked ? MD.Token.color.primary : MD.Token.color.surface_container_highest
                    border.width: 2
                    border.color: dvSwitch.checked ? MD.Token.color.primary : MD.Token.color.outline
                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.effectsDefault.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.effectsDefault.curve
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Motion.effectsDefault.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.effectsDefault.curve
                        }
                    }

                    Rectangle {
                        readonly property real thumbSize: dvSwitch.checked ? 15 : dvSwitch.pressed ? 13 : 10

                        x: dvSwitch.checked ? swtTrack.width - width - 2.5 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: thumbSize
                        height: thumbSize
                        radius: thumbSize / 2
                        color: dvSwitch.checked ? MD.Token.color.on_primary : MD.Token.color.outline

                        Behavior on x {
                            NumberAnimation {
                                duration: Motion.spatialFast.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.spatialFast.curve
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: Motion.spatialFast.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.spatialFast.curve
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Motion.effectsDefault.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Motion.effectsDefault.curve
                            }
                        }
                    }
                }
            }
        }

        // --- device list (prototype .dv-list) ---
        Item {
            id: detailListArea

            y: detailHead.height + 8
            width: parent.width
            height: parent.height - y

            MD.VerticalFlickable {
                id: detailFlick

                anchors.fill: parent

                Loader {
                    id: detailLoader

                    width: parent.width
                    sourceComponent: {
                        if (root.shownDetail === "wifi") {
                            return wifiDetail;
                        }
                        if (root.shownDetail === "bluetooth") {
                            return bluetoothDetail;
                        }
                        if (root.shownDetail === "output") {
                            return outputDetail;
                        }
                        if (root.shownDetail === "kbd") {
                            return kbdDetail;
                        }
                        return null;
                    }
                }
            }

            // Prototype edge fade: clipped rows read as "more to scroll".
            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 14
                visible: detailFlick.contentHeight > detailFlick.height && detailFlick.contentY > 1
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: MD.Token.color.surface_container_low
                    }
                    GradientStop {
                        position: 1
                        color: MD.Util.transparent(MD.Token.color.surface_container_low, 0)
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 14
                visible: detailFlick.contentHeight > detailFlick.height && detailFlick.contentY < detailFlick.contentHeight - detailFlick.height - 1
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: MD.Util.transparent(MD.Token.color.surface_container_low, 0)
                    }
                    GradientStop {
                        position: 1
                        color: MD.Token.color.surface_container_low
                    }
                }
            }
        }
    }

    // Prototype .dvi list row: 46px surface-container-high card (radius 15,
    // 12 selected = secondary-container) with icon, name + optional badge
    // glyph, sub line, and a popping trailing check; rows rise in with a
    // 35ms/index stagger.
    component DetailRow: MD.Button {
        id: detailRow

        property bool current: false
        property string subText: ""
        property string leadingIcon: ""
        // Small glyph beside the name (prototype's 12px lock).
        property string nameBadgeIcon: ""
        // Replaces the check with a progress affordance while connecting.
        property bool busy: false
        property int order: 0

        width: parent ? parent.width : 0
        implicitHeight: 46
        leftPadding: 14
        rightPadding: 14
        checkable: false
        flat: true
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0
        mdState.size: MD.Enum.XS
        mdState.type: current ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
        property color animBackground: current ? mdState.ctx.color.secondary_container : mdState.ctx.color.surface_container_high
        Behavior on animBackground {
            ColorAnimation {
                duration: Motion.effectsDefault.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.effectsDefault.curve
            }
        }
        mdState.backgroundColor: animBackground
        mdState.textColor: current ? mdState.ctx.color.on_secondary_container : mdState.ctx.color.on_surface
        readonly property real rowCorner: current ? 12 : 15
        mdState.corners: MD.Util.corners(rowCorner)
        scale: down ? 0.97 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Motion.spatialFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast.curve
            }
        }

        // Entrance (prototype dvIn keyframes, 35ms/index stagger).
        transform: Translate {
            id: rowTy
        }
        Component.onCompleted: rowIn.restart()
        SequentialAnimation {
            id: rowIn

            ScriptAction {
                script: {
                    detailRow.opacity = 0;
                    rowTy.y = -8;
                }
            }
            PauseAnimation {
                duration: detailRow.order * 35
            }
            ParallelAnimation {
                NumberAnimation {
                    target: rowTy
                    property: "y"
                    to: 0
                    duration: Motion.spatialFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.spatialFast.curve
                }
                NumberAnimation {
                    target: detailRow
                    property: "opacity"
                    to: 1
                    duration: Motion.effectsDefault.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.effectsDefault.curve
                }
            }
        }

        contentItem: Item {
            implicitHeight: 46 - 8

            MD.Icon {
                id: rowIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: detailRow.leadingIcon.length > 0
                name: detailRow.leadingIcon
                size: 18
                color: detailRow.current ? detailRow.mdState.ctx.color.on_secondary_container : detailRow.mdState.ctx.color.on_surface_variant
            }

            Column {
                anchors.left: rowIcon.visible ? rowIcon.right : parent.left
                anchors.leftMargin: rowIcon.visible ? 10 : 0
                anchors.right: rowTrailing.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Row {
                    width: parent.width
                    spacing: 6

                    MD.Text {
                        // Reserve room for the badge glyph.
                        width: Math.min(implicitWidth, parent.width - (badgeIcon.visible ? badgeIcon.width + parent.spacing : 0))
                        text: detailRow.text
                        color: detailRow.mdState.textColor
                        typescale: MD.Token.typescale.label_large
                        prominent: detailRow.current
                        font.family: Theme.textTypeface
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                    }

                    MD.Icon {
                        id: badgeIcon

                        anchors.verticalCenter: parent.verticalCenter
                        visible: detailRow.nameBadgeIcon.length > 0
                        name: detailRow.nameBadgeIcon
                        size: 12
                        opacity: 0.75
                        color: detailRow.mdState.ctx.color.on_surface_variant
                    }
                }

                MD.Text {
                    width: parent.width
                    visible: detailRow.subText.length > 0
                    text: detailRow.subText
                    color: detailRow.mdState.ctx.color.on_surface_variant
                    typescale: MD.Token.typescale.body_small
                    font.family: Theme.textTypeface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }
            }

            Item {
                id: rowTrailing

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18

                MD.Icon {
                    anchors.centerIn: parent
                    visible: !detailRow.busy
                    name: "check"
                    size: 18
                    color: MD.Token.color.primary
                    opacity: detailRow.current ? 1 : 0
                    scale: detailRow.current ? 1 : 0.4
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.effectsFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.effectsFast.curve
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Motion.spatialFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.spatialFast.curve
                        }
                    }
                }

                MD.BusyIndicator {
                    anchors.centerIn: parent
                    visible: detailRow.busy
                    running: visible
                    implicitWidth: 18
                    implicitHeight: 18
                }
            }
        }
    }

    // Prototype .dv-empty: shown when the radio behind a detail page is off.
    component DetailEmpty: Item {
        id: emptyState

        property string name: ""

        width: parent ? parent.width : 0
        // Fills the list viewport so the message centers like the prototype.
        implicitHeight: detailListArea.height

        Column {
            anchors.centerIn: parent
            spacing: 4

            MD.Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("quickSettings.detailOffTitle", {
                    "name": emptyState.name
                })
                color: MD.Token.color.on_surface_variant
                typescale: MD.Token.typescale.label_large
                prominent: true
                font.family: Theme.textTypeface
            }

            MD.Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("quickSettings.detailOffHint")
                color: MD.Token.color.on_surface_variant
                opacity: 0.75
                typescale: MD.Token.typescale.body_small
                font.family: Theme.textTypeface
            }
        }
    }

    // --- wifi network list --------------------------------------------------
    Component {
        id: wifiDetail

        Column {
            spacing: 5

            // Which network shows the inline password field.
            property var pendingNetwork: null

            DetailEmpty {
                visible: !Networking.wifiEnabled
                name: I18n.t("quickSettings.wifi")
            }

            MD.LinearIndicator {
                width: parent.width
                visible: Networking.wifiEnabled && root.wifiDevice !== null && root.wifiDevice.networks.values.length === 0
            }

            Repeater {
                model: Networking.wifiEnabled && root.wifiDevice ? root.wifiDevice.networks.values.slice().sort((a, b) => (b.connected ? 2 : b.signalStrength > 1 ? b.signalStrength / 100 : b.signalStrength) - (a.connected ? 2 : a.signalStrength > 1 ? a.signalStrength / 100 : a.signalStrength)).slice(0, 10) : []

                Column {
                    id: wifiRow

                    required property var modelData
                    required property int index

                    width: parent.width
                    spacing: 5

                    DetailRow {
                        order: wifiRow.index
                        text: wifiRow.modelData.name
                        current: wifiRow.modelData.connected
                        leadingIcon: QSIcons.wifiSignalIcon(wifiRow.modelData.signalStrength)
                        nameBadgeIcon: wifiRow.modelData.security !== WifiSecurityType.Open ? "lock" : ""
                        busy: wifiRow.modelData.stateChanging
                        subText: {
                            if (wifiRow.modelData.stateChanging) {
                                return I18n.t("quickSettings.wifiConnecting");
                            }
                            if (wifiRow.modelData.connected) {
                                return I18n.t("quickSettings.wifiConnected");
                            }
                            if (wifiRow.modelData.security !== WifiSecurityType.Open) {
                                return I18n.t("quickSettings.wifiSecured");
                            }
                            return I18n.t("quickSettings.wifiOpen");
                        }

                        onClicked: {
                            if (wifiRow.modelData.connected) {
                                wifiRow.modelData.disconnect();
                            } else if (wifiRow.modelData.known || wifiRow.modelData.security === WifiSecurityType.Open) {
                                wifiRow.modelData.connect();
                            } else {
                                pendingNetwork = pendingNetwork === wifiRow.modelData ? null : wifiRow.modelData;
                            }
                        }
                    }

                    Row {
                        visible: pendingNetwork === wifiRow.modelData
                        width: parent.width
                        spacing: 8

                        MD.TextField {
                            id: pskField

                            // Compact 56dp field for the panel (outlined default is 64dp).
                            mdState.dense: true
                            width: parent.width - connectButton.width - 8
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
            spacing: 5

            DetailEmpty {
                visible: !root.btEnabled
                name: I18n.t("quickSettings.bluetooth")
            }

            Repeater {
                model: root.btEnabled && root.btAdapter ? root.btAdapter.devices.values.filter(device => device !== null && (device.paired || device.bonded || device.connected)) : []

                DetailRow {
                    id: btRow

                    required property var modelData
                    required property int index

                    order: index
                    text: btRow.modelData.name.length > 0 ? btRow.modelData.name : btRow.modelData.address
                    current: btRow.modelData.connected
                    leadingIcon: QSIcons.btDeviceIcon(btRow.modelData.icon)
                    subText: btRow.modelData.connected ? I18n.t("quickSettings.btConnected") : I18n.t("quickSettings.btNotConnected")

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
            spacing: 5

            Repeater {
                model: Audio.sinkDevices

                DetailRow {
                    id: sinkRow

                    required property var modelData
                    required property int index

                    order: index
                    text: sinkRow.modelData.description.length > 0 ? sinkRow.modelData.description : sinkRow.modelData.name
                    current: Audio.sink !== null && sinkRow.modelData.id === Audio.sink.id
                    leadingIcon: QSIcons.audioSinkIcon(sinkRow.modelData.description + " " + sinkRow.modelData.name)

                    onClicked: Audio.setPreferredSink(sinkRow.modelData)
                }
            }
        }
    }

    // --- keyboard backlight levels --------------------------------------------
    Component {
        id: kbdDetail

        Column {
            spacing: 5

            // Off / half / max mirror the old menu levels.
            Repeater {
                model: [
                    {
                        "level": 0,
                        "token": "quickSettings.kbdBacklight.off",
                        "icon": "backlight_high_off"
                    },
                    {
                        "level": Math.max(1, Math.ceil(Brightness.kbdMax / 2)),
                        "token": "quickSettings.kbdBacklight.low",
                        "icon": "backlight_low"
                    },
                    {
                        "level": Brightness.kbdMax,
                        "token": "quickSettings.kbdBacklight.high",
                        "icon": "backlight_high"
                    }
                ]

                DetailRow {
                    id: kbdRow

                    required property var modelData
                    required property int index

                    order: index
                    text: I18n.t(kbdRow.modelData.token)
                    current: Brightness.kbdLevel === kbdRow.modelData.level
                    leadingIcon: kbdRow.modelData.icon

                    onClicked: Brightness.setKbdLevel(kbdRow.modelData.level)
                }
            }
        }
    }
}
