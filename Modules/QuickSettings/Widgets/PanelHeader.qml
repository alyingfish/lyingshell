import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Material
import qs.Services
import "../../../Material/Motion.js" as Motion
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Panel header (prototype header + expandable rows): tools button, battery
// pill, settings and power actions in a 32px row, with the tools and
// power-mode rows folding out below. One block so each open row contributes
// its own preceding 10px gap (prototype xrow margin-top -10px cancels the
// flex gap while closed). The rows are mutually exclusive.
Item {
    id: header

    property real sectionGap: 10
    // Expandable-row state; the panel aliases these for tests and e2e.
    property bool toolsOpen: false
    property bool pmodeOpen: false
    // Instant collapse (no spring) when a detail page must measure the
    // compact panel, mirroring the prototype's collapseRowsInstant().
    property bool revealAnimated: true
    // Driven by the panel so the power button suppresses its tooltip while
    // the session card is up.
    property bool powerMenuOpen: false

    signal closeRequested
    // Power button pressed; the panel owns the session-menu card.
    signal powerRequested

    function collapseRowsInstant() {
        revealAnimated = false;
        toolsOpen = false;
        pmodeOpen = false;
        revealAnimated = true;
    }

    // Expandable-row reveals (prototype grid-template-rows 0fr -> 1fr on the
    // soft spring; each open row also restores its preceding section gap).
    property real toolsReveal: toolsOpen ? 1 : 0

    Behavior on toolsReveal {
        enabled: header.revealAnimated

        MotionAnimation {
            spring: Motion.spatialDefault
        }
    }

    property real pmodeReveal: pmodeOpen ? 1 : 0

    Behavior on pmodeReveal {
        enabled: header.revealAnimated

        MotionAnimation {
            spring: Motion.spatialDefault
        }
    }

    readonly property real toolsSpace: toolsReveal * (sectionGap + 40)
    readonly property real pmodeSpace: pmodeReveal * (sectionGap + 40)

    implicitHeight: 32 + toolsSpace + pmodeSpace

    // Test-only surface (tests/qml/tst_powermode_matrix.qml).
    readonly property bool pillVisibleProbe: battPill.visible
    readonly property bool pillEnabledProbe: battPill.enabled
    readonly property string pillIconProbe: pillModeIcon.name
    readonly property string pillTextProbe: pillLabel.text

    // --- header row (32px) -------------------------------------------------
    Item {
        width: parent.width
        height: 32

        Row {
            anchors.left: parent.left
            // XS icon buttons carry 4px transparent insets; -4 flushes the
            // first circle with the content edge and -2 spacing keeps
            // visible gaps at the prototype 6px.
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
                checked: header.toolsOpen

                // Prototype .ib: surface-container-high chip that fills
                // primary and squares 16 -> 11 while its row is open.
                property color animBackground: header.toolsOpen ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_high
                property color animText: header.toolsOpen ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface_variant

                Behavior on animBackground {
                    MotionColorAnimation {}
                }

                Behavior on animText {
                    MotionColorAnimation {}
                }

                mdState.backgroundColor: animBackground
                mdState.textColor: animText
                readonly property real stateCorner: header.toolsOpen && !down ? 11 : mdState.corner
                mdState.corners: MD.Util.corners(stateCorner)
                scale: down ? 0.88 : 1

                Behavior on scale {
                    MotionAnimation {}
                }

                onClicked: {
                    header.pmodeOpen = false;
                    header.toolsOpen = !header.toolsOpen;
                }

                MD.ToolTip {
                    y: parent.height + 4
                    text: I18n.t("quickSettings.tools")
                    visible: toolsButton.hovered
                }
            }

            // Battery pill: power-mode icon + charge readout; opens the
            // power-mode row (prototype .batt).
            MD.Button {
                id: battPill

                anchors.verticalCenter: parent.verticalCenter
                // Interactive whenever it shows (battery present or a daemon):
                // even with no profile daemon the pill expands the row to read
                // the time-left estimate.
                visible: SystemStatus.hasBattery || PowerMode.available
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
                mdState.type: header.pmodeOpen ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
                property color animBackground: header.pmodeOpen ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_high
                property color animText: header.pmodeOpen ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface
                // Prototype .pmico: the mode glyph reads primary at rest,
                // on-primary while the row is open.
                property color animIcon: header.pmodeOpen ? mdState.ctx.color.on_primary : mdState.ctx.color.primary

                Behavior on animBackground {
                    MotionColorAnimation {}
                }

                Behavior on animText {
                    MotionColorAnimation {}
                }

                Behavior on animIcon {
                    MotionColorAnimation {}
                }

                mdState.backgroundColor: animBackground
                mdState.textColor: animText
                readonly property real stateCorner: header.pmodeOpen && !down ? 11 : 16
                mdState.corners: MD.Util.corners(stateCorner)
                scale: down ? 0.94 : 1

                Behavior on scale {
                    MotionAnimation {}
                }

                onClicked: {
                    header.toolsOpen = false;
                    header.pmodeOpen = !header.pmodeOpen;
                }

                contentItem: Row {
                    spacing: 6

                    MD.Icon {
                        id: pillModeIcon

                        anchors.verticalCenter: parent.verticalCenter
                        name: PowerMode.available ? PowerMode.iconName : StatusIcons.batteryIcon(SystemStatus.batteryPercent, SystemStatus.batteryCharging, SystemStatus.batteryFull)
                        size: 16
                        color: battPill.animIcon

                        // Prototype: the pill glyph pops when the mode changes.
                        MotionAnimation {
                            id: pillIconPop

                            target: pillModeIcon
                            property: "scale"
                            from: 0.5
                            to: 1
                        }

                        Connections {
                            target: PowerMode

                            function onProfileChanged() {
                                pillIconPop.restart();
                            }
                        }
                    }

                    MD.Text {
                        id: pillLabel

                        anchors.verticalCenter: parent.verticalCenter
                        text: SystemStatus.hasBattery ? I18n.t("quickSettings.batteryPercent", {
                            "percent": SystemStatus.batteryPercent
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
            // -4 keeps the last visible circle flush with the content edge
            // (XS icon-button insets).
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
                    MotionAnimation {}
                }

                // Prototype #btnSettings:hover: the gear turns.
                contentItem: Item {
                    implicitWidth: settingsButton.icon.width
                    implicitHeight: settingsButton.icon.height
                    opacity: settingsButton.mdState.contentOpacity

                    MD.Icon {
                        anchors.centerIn: parent
                        name: settingsButton.icon.name
                        // Prototype #i-settings is the filled gear.
                        fill: true
                        size: settingsButton.icon.width
                        color: settingsButton.mdState.textColor
                        rotation: settingsButton.hovered ? 55 : 0

                        Behavior on rotation {
                            MotionAnimation {}
                        }
                    }
                }

                onClicked: {
                    Session.openSettings();
                    header.closeRequested();
                }

                MD.ToolTip {
                    y: parent.height + 4
                    text: I18n.t("quickSettings.settings")
                    visible: settingsButton.hovered
                }
            }

            MD.IconButton {
                id: powerButton

                // Prototype .ib-err: error-container chip, the one
                // emphasized header action.
                mdState.type: MD.Enum.IBtFilledTonal
                mdState.size: MD.Enum.XS
                icon.name: "power_settings_new"
                // Prototype .ib-err glyph reads smaller than the tonal chips'
                // 18px; the filled power_settings_new symbol is optically
                // heavier, so 16 matches the prototype's breathing room.
                icon.width: 16
                icon.height: 16
                // flat drops the ElevationRectangle shadow in every state
                // (IconButton has no `elevation` prop; mdState.elevation
                // defaults to level1 and the bg only hides it when flat).
                flat: true
                mdState.backgroundColor: mdState.ctx.color.error_container
                mdState.textColor: mdState.ctx.color.on_error_container
                scale: down ? 0.88 : 1

                Behavior on scale {
                    MotionAnimation {}
                }

                // The session menu is a panel-level card (see
                // QuickSettingsPanel); the button just toggles it.
                onClicked: header.powerRequested()

                MD.ToolTip {
                    y: parent.height + 4
                    text: I18n.t("quickSettings.power")
                    visible: powerButton.hovered && !header.powerMenuOpen
                }
            }
        }
    }

    // --- tools row (prototype #rowTools) ------------------------------------
    Item {
        y: 32
        width: parent.width
        height: header.toolsSpace
        clip: true
        opacity: header.toolsReveal

        ToolsRow {
            anchors.bottom: parent.bottom
            width: parent.width

            onCollapseRequested: header.toolsOpen = false
            onCloseRequested: header.closeRequested()
        }
    }

    // --- power-mode row (prototype #rowPmode) --------------------------------
    Item {
        y: 32 + header.toolsSpace
        width: parent.width
        height: header.pmodeSpace
        clip: true
        opacity: header.pmodeReveal

        PowerModeRow {
            anchors.bottom: parent.bottom
            width: parent.width
        }
    }
}
