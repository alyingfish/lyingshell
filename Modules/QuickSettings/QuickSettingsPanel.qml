import QtQuick
import qs.Material
import qs.Services
import qs.Modules.QuickSettings.Widgets
import "../../Material/Motion.js" as Motion
import "../../Commons/Icons/StatusIcons.js" as StatusIcons

// Quick-settings panel content mirroring the web prototype: a 344px card
// (12px padding, 10px section gap) of header actions + battery pill, two
// expandable rows (tools, power mode), expressive sliders, a horizontally
// paged toggle-tile grid with page dots, and sliding detail views (Wi-Fi /
// Bluetooth / Sound output / Keyboard). System state lives in Quickshell
// services and the qs.Services boundaries; this module only wires state to
// MD3 controls. Motion map: the prototype's bouncy `--spring` is
// Motion.spatialFast, its `--spring-soft` is Motion.spatialDefault, and its
// short standard fades are the effects springs. This file owns panel state
// and composition; the pieces live in Widgets/.
Item {
    id: root

    signal closeRequested

    // Mirrors the menu's open state so the staggered entrance can run at
    // the start of the card's open transform, not at first visibility.
    property bool open: false

    // "" | "wifi" | "bluetooth" | "output" | "kbd"
    property string detail: ""
    // The mounted detail page: lags `detail` on close so the exit slide has
    // content to fade out.
    property string shownDetail: ""

    // Expandable-row state lives in the header; aliased here for tests/e2e.
    property alias toolsOpen: header.toolsOpen
    property alias pmodeOpen: header.pmodeOpen
    property alias toolsReveal: header.toolsReveal
    property alias pmodeReveal: header.pmodeReveal

    // Session-menu card (prototype #pmenu) floats over the panel at top-right;
    // owned here so it stacks above the tiles and stays clipped to the card.
    property bool sessionMenuOpen: false

    // Layout metrics (web prototype: 344px panel, 12px padding, 10px section
    // gap, 6px tile gap).
    readonly property real pad: 12
    readonly property real sectionGap: 10
    readonly property real contentWidth: 344 - pad * 2

    // Refresh process-backed state whenever the panel becomes visible.
    onVisibleChanged: {
        if (visible) {
            Brightness.refresh();
            Airplane.refresh();
            DoNotDisturb.refresh();
        } else {
            detail = "";
            shownDetail = "";
            header.toolsOpen = false;
            header.pmodeOpen = false;
            sessionMenuOpen = false;
            pager.setPage(0);
        }
    }

    onOpenChanged: if (open)
        riseAnim.restart()

    onDetailChanged: {
        if (detail !== "") {
            // Lock the compact height before the detail view replaces the
            // main view 1:1 (prototype collapseRowsInstant + height lock).
            header.collapseRowsInstant();
            sessionMenuOpen = false;
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
    readonly property real headerOpacityProbe: header.opacity
    readonly property real pagerOpacityProbe: pager.opacity
    readonly property real mainSlideProbe: mainTx.x
    readonly property real detailSlideProbe: detailView.slideX
    readonly property Item tileTrackProbe: pager.trackItem

    function setPage(page: int) {
        pager.setPage(page);
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
        // Prototype #qs.detail #viewMain: slide 28px left and fade out. NOT
        // gated with `enabled`: disabling would flip every MD control into its
        // greyed disabled palette and animate it back, a flash the CSS
        // crossfade never has. Input is blocked by the detail view's cover
        // (DetailView catcher) while it is up.
        opacity: root.detail === "" ? 1 : 0

        transform: Translate {
            id: mainTx

            x: root.detail === "" ? 0 : -28

            Behavior on x {
                MotionAnimation {
                    spring: Motion.spatialDefault
                }
            }
        }

        Behavior on opacity {
            MotionAnimation {
                spring: Motion.effectsDefault
            }
        }

        Column {
            id: mainColumn

            width: parent.width
            spacing: root.sectionGap

            PanelHeader {
                id: header

                width: parent.width
                sectionGap: root.sectionGap

                transform: Translate {
                    id: headerRise
                }

                powerMenuOpen: root.sessionMenuOpen

                onCloseRequested: root.closeRequested()
                onPowerRequested: root.sessionMenuOpen = !root.sessionMenuOpen
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
                    iconName: StatusIcons.volumeIcon(Audio.volume, Audio.muted)
                    iconReactive: true
                    iconChecked: Audio.muted
                    iconTooltipKey: Audio.muted ? "quickSettings.unmute" : "quickSettings.mute"
                    value: Audio.volume
                    dimmed: Audio.muted
                    hasDetail: Audio.hasSink
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
                    // lives on its own tile.
                    iconName: StatusIcons.brightnessIcon(Brightness.percent)
                    value: Brightness.percent
                    visible: Brightness.available

                    onMoved: newValue => Brightness.setPercent(newValue)
                }
            }

            TilePager {
                id: pager

                width: parent.width

                transform: Translate {
                    id: pagerRise
                }

                onDetailRequested: name => root.detail = name
            }

            PageDots {
                id: dotsRow

                width: parent.width
                visible: pager.pageCount > 1
                page: pager.page
                pageCount: pager.pageCount

                transform: Translate {
                    id: dotsRise
                }

                onPageRequested: page => pager.setPage(page)
            }
        }
    }

    // Staggered entrance (prototype rise keyframes + nth-child delays):
    // geometry on the spatial spring, opacity on the effects spring.
    SequentialAnimation {
        id: riseAnim

        ScriptAction {
            script: {
                for (const [item, ty] of [[header, headerRise], [slidersCol, slidersRise], [pager, pagerRise], [dotsRow, dotsRise]]) {
                    item.opacity = 0;
                    ty.y = -10;
                }
            }
        }

        ParallelAnimation {
            RiseSeq {
                delay: 20
                riseItem: header
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
            MotionAnimation {
                target: riseTranslate
                property: "y"
                to: 0
            }

            MotionAnimation {
                target: riseItem
                property: "opacity"
                to: 1
                spring: Motion.effectsDefault
            }
        }
    }

    // ======================================================================
    // Detail view (slides in over the locked-height panel)
    // ======================================================================
    DetailView {
        id: detailView

        x: root.pad
        y: root.pad
        width: root.contentWidth
        height: root.compactContentHeight
        detail: root.detail
        shownDetail: root.shownDetail

        onBackRequested: root.detail = ""
    }

    // ======================================================================
    // Session menu (prototype #pmenu): a card over the panel + a catcher that
    // dismisses it on any press elsewhere in the panel.
    // ======================================================================
    MouseArea {
        anchors.fill: parent
        z: 5
        visible: root.sessionMenuOpen
        acceptedButtons: Qt.AllButtons

        onPressed: root.sessionMenuOpen = false
    }

    SessionMenu {
        id: sessionMenu

        z: 6
        open: root.sessionMenuOpen
        // Prototype #pmenu: right edge flush with the content's right edge,
        // 6px below the 32px header row.
        x: root.pad + root.contentWidth - width
        y: root.pad + 32 + 6

        onPanelCloseRequested: root.closeRequested()
    }
}
