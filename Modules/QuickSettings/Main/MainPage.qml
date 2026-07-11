import QtQuick
import qs.Material
import qs.Services
import qs.Modules.QuickSettings.Controls
import "../../../Commons/Icons/StatusIcons.js" as StatusIcons

// Main quick-settings page (prototype #viewMain): the StackView's initial item.
// Header actions + battery pill, expandable tools/power-mode rows, expressive
// sliders, the paged toggle-tile grid, and page dots. The panel owns
// navigation and composition; this owns the main-view content and its
// staggered entrance. Sized to fill the StackView.
Item {
    id: root

    property real sectionGap: 10
    // Mirrors the panel/menu open state so the staggered entrance runs at the
    // start of the card's open transform.
    property bool open: false
    // Suppresses the power button tooltip while the session card is up.
    property bool powerMenuOpen: false

    signal closeRequested
    signal detailRequested(string name)
    signal powerRequested
    // Colour-pick handoff from the tools row; the panel owns the pick.
    signal pickRequested

    // Expandable-row state; the panel aliases these for tests/e2e.
    property alias toolsOpen: header.toolsOpen
    property alias pmodeOpen: header.pmodeOpen
    // Unified reveal (0 closed, 1 open) driving the row-switcher height.
    property alias switchReveal: header.switchReveal

    // Probes/handles the panel forwards (tests + e2e wheel targets).
    readonly property real switchSlideProbe: header.switchSlideProbe
    readonly property real headerOpacityProbe: header.opacity
    readonly property real pagerOpacityProbe: pager.opacity
    readonly property Item tileArea: pager
    readonly property Item volumeRow: volumeSlider
    readonly property Item tileTrackProbe: pager.trackItem
    readonly property int page: pager.page
    readonly property int pageCount: pager.pageCount

    // Main-view height as last measured on screen (open rows included); the
    // detail pages lock the panel onto it so navigation never resizes the
    // card. Frozen while hidden: the StackView hides this page under a pushed
    // detail (and the popup hides the whole panel for a colour pick), which
    // collapses the Column's live measurement.
    property real lastShownHeight: 0

    implicitHeight: mainColumn.implicitHeight

    onImplicitHeightChanged: if (visible)
        lastShownHeight = implicitHeight
    onVisibleChanged: if (visible)
        lastShownHeight = implicitHeight

    function setPage(page: int) {
        pager.setPage(page);
    }

    function collapseRowsInstant() {
        header.collapseRowsInstant();
    }

    onOpenChanged: if (open)
        riseAnim.restart()

    Column {
        id: mainColumn

        width: root.width
        spacing: root.sectionGap

        PanelHeader {
            id: header

            width: parent.width
            sectionGap: root.sectionGap

            transform: Translate {
                id: headerRise
            }

            powerMenuOpen: root.powerMenuOpen

            onCloseRequested: root.closeRequested()
            onPowerRequested: root.powerRequested()
            onPickRequested: root.pickRequested()
        }

        // --- sliders --------------------------------------------------------
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
                detailTooltipKey: "quickSettings.sound"
                value: Audio.volume
                dimmed: Audio.muted
                hasDetail: Audio.hasSink
                visible: Audio.hasSink

                onMoved: newValue => Audio.setVolume(newValue)
                onIconClicked: Audio.toggleMuted()
                onDetailRequested: root.detailRequested("sound")
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
                // Plain level readout (prototype briIco); night light lives on
                // its own tile.
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

            onDetailRequested: name => root.detailRequested(name)
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

    // Prototype `@keyframes rise` runs on `--spring` over .55s, so opacity
    // (0->1) and translateY(-10)->0 share the one eased progress -- geometry
    // AND opacity trace the same curve/duration here (encoded once below).
    readonly property var riseSpring: ({
            "duration": 550,
            "curve": [0.34, 1.56, 0.64, 1.0, 1.0, 1.0]
        })

    // Staggered entrance (prototype rise keyframes + nth-child delays). The
    // collapsed #rowSwitch (child 2, .05s) is merged into `header`, so the four
    // visible rows take the delays of #viewMain children 1,3,4,5.
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
                delay: 80
                riseItem: slidersCol
                riseTranslate: slidersRise
            }

            RiseSeq {
                delay: 110
                riseItem: pager
                riseTranslate: pagerRise
            }

            RiseSeq {
                delay: 140
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
                spring: root.riseSpring
            }

            MotionAnimation {
                target: riseItem
                property: "opacity"
                to: 1
                spring: root.riseSpring
            }
        }
    }
}
