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
    // Instant collapse (no spring) for the panel-close reset, so a quick
    // reopen never catches the rows mid-collapse.
    property bool revealAnimated: true
    // Driven by the panel so the power button suppresses its tooltip while
    // the session card is up.
    property bool powerMenuOpen: false

    signal closeRequested
    // Power button pressed; the panel owns the session-menu card.
    signal powerRequested
    // Colour-pick handoff from the tools row; the panel owns the pick.
    signal pickRequested

    function collapseRowsInstant() {
        revealAnimated = false;
        toolsOpen = false;
        pmodeOpen = false;
        revealAnimated = true;
    }

    // Expandable rows are one clipped viewport holding a two-slide track.
    // Open/close is a height reveal (prototype grid-template-rows 0fr -> 1fr on
    // the soft spring, restoring the preceding section gap). Switching
    // tool<->power while open slides the track vertically instead (MD3 shared
    // axis): both slides move up together (tools->power) or down together
    // (power->tools), viewport height unchanged.
    property real switchReveal: (toolsOpen || pmodeOpen) ? 1 : 0

    Behavior on switchReveal {
        enabled: header.revealAnimated

        MotionAnimation {
            spring: Motion.spatialSlow
        }
    }

    readonly property real switchSpace: switchReveal * (sectionGap + 40)

    // Latched index of the shown row (0 tools, 1 pmode); retains its value
    // while collapsed so reopening the same row never slides and open-from-
    // closed to the other row snaps (see the track's Behavior gate). Latching
    // on the *open* edge tracks both button clicks and the e2e/harness direct
    // sets of toolsOpen/pmodeOpen.
    property int switchIndex: 0
    onToolsOpenChanged: if (toolsOpen)
        switchIndex = 0
    onPmodeOpenChanged: if (pmodeOpen)
        switchIndex = 1

    implicitHeight: 32 + switchSpace

    // Switcher track offset (0 tools .. -(gap+40) pmode); the motion test reads
    // it to prove tool<->power is a slide, not a height morph.
    readonly property real switchSlideProbe: switchTrack.y

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
            // first circle with the content edge. The pill (next item) zeroes
            // its insets, so +2 spacing keeps the tools->pill gap at the
            // prototype 6px (4 tools-inset + 2), not the -2 used between two
            // inset-carrying icon buttons.
            anchors.leftMargin: -4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

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
                    // Set the newly-open row before clearing the other so the
                    // reveal never dips false mid-switch (keeps the slide gate
                    // enabled -> clean slide instead of a reveal flicker).
                    if (header.toolsOpen) {
                        header.toolsOpen = false;
                    } else {
                        header.toolsOpen = true;
                        header.pmodeOpen = false;
                    }
                }

                MD.ToolTip {
                    y: parent.height + 4
                    text: I18n.t("quickSettings.tools")
                    visible: toolsButton.hovered && !header.toolsOpen
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
                    // See toolsButton: open the new row before clearing the old.
                    if (header.pmodeOpen) {
                        header.pmodeOpen = false;
                    } else {
                        header.pmodeOpen = true;
                        header.toolsOpen = false;
                    }
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
                    visible: battPill.hovered && !header.pmodeOpen
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

                // Tonal chip (IBtFilledTonal default: secondary_container);
                // dropped the prototype .ib-err error red, which clashed with
                // the blue scheme in dark.
                mdState.type: MD.Enum.IBtFilledTonal
                mdState.size: MD.Enum.XS
                icon.name: "power_settings_new"
                // The filled power_settings_new symbol is optically heavier
                // than the 18px tonal-chip glyphs, so 16 gives it the same
                // breathing room.
                icon.width: 16
                icon.height: 16
                // flat drops the ElevationRectangle shadow in every state
                // (IconButton has no `elevation` prop; mdState.elevation
                // defaults to level1 and the bg only hides it when flat).
                flat: true
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

    // --- expandable-row switcher (prototype #rowSwitch) ---------------------
    // One clipped viewport below the 32px header row; the track holds both
    // slides stacked and translates to switch. Height + opacity reveal on
    // open/close (opacity is the fast standard fade, decoupled from the reveal
    // spring); the track slides only while fully open, so open/close stays a
    // pure reveal (the track snaps under the growing/shrinking clip).
    Item {
        y: 32
        width: parent.width
        height: header.switchSpace
        clip: true
        opacity: (header.toolsOpen || header.pmodeOpen) ? 1 : 0

        Behavior on opacity {
            enabled: header.revealAnimated

            MotionAnimation {
                spring: Motion.effectsSlow
            }
        }

        Item {
            id: switchTrack

            width: parent.width
            // 0 -> tools slide, -(gap+40) -> pmode slide.
            y: -header.switchIndex * (header.sectionGap + 40)

            Behavior on y {
                enabled: header.revealAnimated && header.switchReveal > 0.99

                MotionAnimation {
                    spring: Motion.spatialSlow
                }
            }

            // tools slide (its own preceding section gap on top).
            Item {
                width: parent.width
                height: header.sectionGap + 40

                ToolsRow {
                    anchors.top: parent.top
                    anchors.topMargin: header.sectionGap
                    width: parent.width

                    onPickRequested: header.pickRequested()
                    onCloseRequested: header.closeRequested()
                }
            }

            // power-mode slide.
            Item {
                y: header.sectionGap + 40
                width: parent.width
                height: header.sectionGap + 40

                PowerModeRow {
                    anchors.top: parent.top
                    anchors.topMargin: header.sectionGap
                    width: parent.width
                }
            }
        }
    }
}
