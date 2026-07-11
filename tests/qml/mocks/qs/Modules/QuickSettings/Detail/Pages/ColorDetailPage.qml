import QtQuick
import Quickshell
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Material
import "../../../../Material/Motion.js" as Motion
import qs.Services.Niri
import qs.Modules.QuickSettings.Detail

// Color-picker result page, M3-expressive split-hero layout. Every section
// keeps its natural fixed height: the detail viewport is fixed anyway (the
// panel locks the tools-open main height, since the readout is only reached
// through the tools row), so nothing stretches to soak the leftover — spare
// viewport reads as quiet whitespace below the content:
//   - hero band: the readout swatch paired with a square "pick again" button
//     (asymmetric corner split, hover morph) at a fixed compact height;
//   - HEX / RGB / HSV rows as a grouped list (big outer corners, small inner)
//     each with a copy button;
//   - a Recent grid of the last picks (settings-persisted by the panel):
//     tapping a thumbnail reloads it into the readout to compare or re-copy,
//     and a clear button in the section header empties the history.
// Reached only after a successful pick (the panel pushes it on
// Niri.colorPicked), so a color is normally present; the prompt is a fallback
// for an empty state. Reads the live result through the Niri singleton.
DetailPage {
    id: root

    // "Pick again" hands off to the panel's beginColorPick: the card closes
    // for the aim and reopens on this page when niri replies.
    signal pickRequested

    detailName: "color"
    title: I18n.t("quickSettings.tool.colorPicker")

    bodyContent: Component {
        Item {
            id: page

            // Viewport height handed down by DetailPage; the layout fills it.
            property real viewportHeight: 0

            // Recent picks, newest first (QuickSettingsPanel writes them).
            readonly property var recents: Settings.options.quickSettings.colorPicker.recentColors || []
            // Grid slots; matches QuickSettingsPanel.maxRecentColors.
            readonly property int recentSlots: 8

            // The color on the readout: follows the live pick until a Recent
            // thumbnail is tapped (the tap assignment breaks this binding; the
            // Connections below re-arms it on the next pick). The recents
            // fallback covers a page opened with no pick this session.
            property string shownHex: Niri.lastPickedColor.length > 0 ? Niri.lastPickedColor : (recents.length > 0 ? recents[0] : "")

            readonly property bool hasColor: shownHex.length > 0
            readonly property color shown: hasColor ? shownHex : "transparent"
            readonly property int r: Math.round(shown.r * 255)
            readonly property int g: Math.round(shown.g * 255)
            readonly property int b: Math.round(shown.b * 255)
            // hsvHue is -1 for achromatic (grey); clamp it to 0.
            readonly property int h: Math.round((shown.hsvHue < 0 ? 0 : shown.hsvHue) * 360)
            readonly property int s: Math.round(shown.hsvSaturation * 100)
            readonly property int v: Math.round(shown.hsvValue * 100)

            // What sits on the clipboard: the format key ("hex"/"rgb"/"hsv")
            // plus the hex it was copied from, so exactly one row shows a
            // persistent "copied" check — and only while the readout still
            // shows that color (a thumbnail tap must not carry the check to
            // another color's identical row).
            property string copiedFormat: ""
            property string copiedHex: ""

            // Legible ink over an arbitrary swatch color (check + ripple).
            function inkFor(c: color): color {
                return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.55 ? Qt.rgba(0, 0, 0, 0.8) : Qt.rgba(1, 1, 1, 0.95);
            }

            width: parent ? parent.width : 0
            // Natural content height: a viewport shorter than the content
            // scrolls; a taller one leaves bottom whitespace.
            height: hasColor ? body.implicitHeight : viewportHeight

            // The panel auto-copies the picked HEX on every pick; claim the
            // HEX row's check and snap the readout back to the live pick
            // (a thumbnail tap may have detached the shownHex binding).
            Connections {
                target: Niri

                function onColorPicked(hex) {
                    page.shownHex = hex;
                    page.copiedFormat = "hex";
                    page.copiedHex = hex;
                }
            }

            // First open: the pick completed before this page was built (the
            // readout is pushed only after niri replies), so seed the check.
            Component.onCompleted: {
                if (Niri.lastPickedColor.length > 0) {
                    copiedFormat = "hex";
                    copiedHex = Niri.lastPickedColor;
                }
            }

            Column {
                id: body

                width: parent.width
                visible: page.hasColor
                spacing: 8

                // --- hero: swatch + pick-again split pair -------------------
                // Fixed compact band: the readout identity, not a space filler.
                Item {
                    id: hero

                    width: parent.width
                    height: 72

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: pickAgainBtn.left
                        anchors.rightMargin: 4
                        topLeftRadius: 22
                        bottomLeftRadius: 22
                        topRightRadius: 8
                        bottomRightRadius: 8
                        color: page.shown
                        border.width: 1
                        border.color: MD.Token.color.outline_variant

                        // Smooth swap when a Recent thumbnail reloads the
                        // readout, so a compare reads as one morph.
                        Behavior on color {
                            MotionColorAnimation {}
                        }
                    }

                    // Square trailing half of the split pair; hover morphs the
                    // outer corner like the tools-row chips (same override:
                    // MState's internal 100ms corner Behavior cannot render a
                    // spring, so the background is replaced).
                    MD.Button {
                        id: pickAgainBtn

                        readonly property real targetCorner: hovered ? 28 : 22
                        property real renderCorner: targetCorner

                        Behavior on renderCorner {
                            MotionAnimation {
                                spring: Motion.spatialDefault
                            }
                        }

                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 64
                        flat: true
                        topInset: 0
                        bottomInset: 0
                        leftInset: 0
                        rightInset: 0
                        mdState.size: MD.Enum.XS
                        mdState.type: MD.Enum.BtFilledTonal
                        scale: down ? 0.95 : 1

                        Behavior on scale {
                            MotionAnimation {}
                        }

                        contentItem: Item {
                            implicitWidth: 20
                            implicitHeight: 20
                            opacity: pickAgainBtn.mdState.contentOpacity

                            MD.Icon {
                                anchors.centerIn: parent
                                name: "colorize"
                                size: 20
                                color: pickAgainBtn.mdState.textColor
                            }
                        }

                        background: MD.ElevationRectangle {
                            corners: MD.Util.corners(8, pickAgainBtn.renderCorner, 8, pickAgainBtn.renderCorner)
                            color: pickAgainBtn.mdState.backgroundColor
                            elevationVisible: false

                            MD.Ripple {
                                anchors.fill: parent
                                corners: parent.corners
                                pressX: pickAgainBtn.pressX
                                pressY: pickAgainBtn.pressY
                                pressed: pickAgainBtn.pressed
                                stateOpacity: pickAgainBtn.mdState.stateLayerOpacity
                                color: pickAgainBtn.mdState.stateLayerColor
                            }

                            MD.FocusIndicator {
                                corners: parent.corners
                                active: pickAgainBtn.visualFocus
                            }
                        }

                        onClicked: root.pickRequested()

                        MD.ToolTip {
                            y: parent.height + 4
                            text: I18n.t("quickSettings.colorPicker.pickAgain")
                            visible: pickAgainBtn.hovered
                        }
                    }
                }

                // --- HEX / RGB / HSV grouped list ---------------------------
                Column {
                    id: formatGroup

                    width: parent.width
                    spacing: 2

                    ColorFormatRow {
                        width: parent.width
                        topCorner: 16
                        formatKey: "hex"
                        label: I18n.t("quickSettings.colorPicker.hex")
                        value: page.shownHex.toUpperCase()
                        copyValue: page.shownHex
                    }

                    ColorFormatRow {
                        width: parent.width
                        formatKey: "rgb"
                        label: I18n.t("quickSettings.colorPicker.rgb")
                        value: page.r + ", " + page.g + ", " + page.b
                        copyValue: "rgb(" + page.r + ", " + page.g + ", " + page.b + ")"
                    }

                    ColorFormatRow {
                        width: parent.width
                        bottomCorner: 16
                        formatKey: "hsv"
                        label: I18n.t("quickSettings.colorPicker.hsv")
                        value: page.h + "°, " + page.s + "%, " + page.v + "%"
                        copyValue: page.h + ", " + page.s + ", " + page.v
                    }
                }

                // --- Recent picks grid --------------------------------------
                Column {
                    id: recentSection

                    width: parent.width
                    spacing: 6

                    // Section header: label + a clear action that empties the
                    // history (the grid collapses to its empty sockets).
                    Item {
                        width: parent.width
                        height: 26

                        MD.Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("quickSettings.colorPicker.recent")
                            color: MD.Token.color.on_surface_variant
                            typescale: MD.Token.typescale.label_medium
                            font.family: Theme.textTypeface
                        }

                        MD.IconButton {
                            id: clearButton

                            // Test hook (tests/qml/tst_color_readout.qml).
                            objectName: "clearRecents"

                            // Optical pull: align the glyph with the grid's
                            // right edge past the button's built-in padding
                            // (the DetailPage back button does the same).
                            anchors.right: parent.right
                            anchors.rightMargin: -4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.recents.length > 0
                            mdState.type: MD.Enum.IBtStandard
                            mdState.size: MD.Enum.XS
                            icon.name: "delete_history"
                            icon.width: 16
                            icon.height: 16
                            scale: down ? 0.88 : 1

                            Behavior on scale {
                                MotionAnimation {}
                            }

                            onClicked: {
                                // Keep the readout: detach shownHex from its
                                // recents fallback before the history under
                                // it is dropped (self-assign breaks the
                                // binding; the value is unchanged).
                                page.shownHex = page.shownHex;
                                Settings.options.quickSettings.colorPicker.recentColors = [];
                            }

                            MD.ToolTip {
                                y: parent.height + 4
                                text: I18n.t("quickSettings.colorPicker.clearRecent")
                                visible: clearButton.hovered
                            }
                        }
                    }

                    Row {
                        id: recentRow

                        readonly property real cellSize: (width - (page.recentSlots - 1) * spacing) / page.recentSlots

                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: page.recentSlots

                            // Filled slot: a tappable swatch that reloads the
                            // readout; the shown one morphs round -> square
                            // with a check. Empty slot: a faint socket.
                            delegate: Item {
                                id: slot

                                required property int index

                                readonly property bool filled: index < page.recents.length
                                readonly property string slotHex: filled ? page.recents[index] : ""

                                width: recentRow.cellSize
                                height: 34

                                Rectangle {
                                    anchors.fill: parent
                                    visible: !slot.filled
                                    radius: height / 2
                                    color: MD.Token.color.surface_container_high
                                    opacity: 0.55
                                }

                                MD.Button {
                                    id: cell

                                    // Test hook (tests/qml/tst_color_readout.qml).
                                    objectName: "recentCell-" + slot.index

                                    readonly property bool current: slot.filled && slot.slotHex === page.shownHex
                                    readonly property real targetCorner: current ? 12 : height / 2
                                    property real renderCorner: targetCorner

                                    Behavior on renderCorner {
                                        MotionAnimation {
                                            spring: Motion.spatialDefault
                                        }
                                    }

                                    anchors.fill: parent
                                    visible: slot.filled
                                    flat: true
                                    topInset: 0
                                    bottomInset: 0
                                    leftInset: 0
                                    rightInset: 0
                                    mdState.size: MD.Enum.XS
                                    scale: down ? 0.88 : 1

                                    Behavior on scale {
                                        MotionAnimation {}
                                    }

                                    contentItem: Item {}

                                    background: Rectangle {
                                        id: cellFace

                                        radius: cell.renderCorner
                                        color: slot.slotHex.length > 0 ? slot.slotHex : "transparent"
                                        border.width: 1
                                        border.color: MD.Token.color.outline_variant

                                        MD.Icon {
                                            anchors.centerIn: parent
                                            name: "check"
                                            size: 16
                                            color: page.inkFor(cellFace.color)
                                            opacity: cell.current ? 1 : 0
                                            scale: cell.current ? 1 : 0.5

                                            Behavior on opacity {
                                                MotionAnimation {}
                                            }

                                            Behavior on scale {
                                                MotionAnimation {
                                                    spring: Motion.spatialDefault
                                                }
                                            }
                                        }

                                        MD.Ripple {
                                            anchors.fill: parent
                                            corners: MD.Util.corners(cell.renderCorner)
                                            pressX: cell.pressX
                                            pressY: cell.pressY
                                            pressed: cell.pressed
                                            stateOpacity: cell.mdState.stateLayerOpacity
                                            color: page.inkFor(cellFace.color)
                                        }

                                        MD.FocusIndicator {
                                            corners: MD.Util.corners(cell.renderCorner)
                                            active: cell.visualFocus
                                        }
                                    }

                                    // Reload this pick into the readout (breaks
                                    // the live-pick binding; the next pick
                                    // re-arms it via the Connections above).
                                    onClicked: page.shownHex = slot.slotHex

                                    MD.ToolTip {
                                        y: parent.height + 4
                                        text: slot.slotHex.toUpperCase()
                                        visible: cell.hovered && slot.slotHex.length > 0
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty-state fallback (color never picked), centered like the
            // other details' off states.
            MD.Text {
                anchors.centerIn: parent
                width: parent.width
                visible: !page.hasColor
                text: I18n.t("quickSettings.colorPicker.prompt")
                color: MD.Token.color.on_surface_variant
                typescale: MD.Token.typescale.body_medium
                font.family: Theme.textTypeface
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // HEX/RGB/HSV row: a grouped-list card with a label, the value,
            // and a trailing copy button. The button shows a persistent check
            // while this row's value (for the color on the readout) is the
            // one on the clipboard.
            component ColorFormatRow: Rectangle {
                id: fmtRow

                // Bookkeeping key for the copied check ("hex"/"rgb"/"hsv");
                // stable across locale switches, unlike the display label.
                property string formatKey: ""
                property string label: ""
                property string value: ""
                property string copyValue: value
                // Grouped-list corners: big on the group's outer edges, small
                // between neighbours.
                property real topCorner: 5
                property real bottomCorner: 5

                // True while this row's value is what sits on the clipboard.
                readonly property bool onClipboard: page.copiedFormat === formatKey && page.copiedHex === page.shownHex

                implicitHeight: 40
                topLeftRadius: topCorner
                topRightRadius: topCorner
                bottomLeftRadius: bottomCorner
                bottomRightRadius: bottomCorner
                color: MD.Token.color.surface_container_high

                MD.Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    text: fmtRow.label
                    color: MD.Token.color.on_surface_variant
                    typescale: MD.Token.typescale.label_medium
                    font.family: Theme.textTypeface
                }

                MD.Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 58
                    anchors.right: copyButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: fmtRow.value
                    color: MD.Token.color.on_surface
                    typescale: MD.Token.typescale.label_large
                    prominent: true
                    font.family: Theme.textTypeface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }

                MD.IconButton {
                    id: copyButton

                    // Transient: shows the "Copied" tooltip for a beat after an
                    // actual click. Kept apart from the persistent check so an
                    // auto-copy never pops a tooltip with no interaction.
                    property bool justClicked: false

                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    mdState.type: MD.Enum.IBtStandard
                    mdState.size: MD.Enum.XS
                    icon.name: fmtRow.onClipboard ? "check" : "content_copy"
                    icon.width: 18
                    icon.height: 18
                    scale: down ? 0.88 : 1

                    Behavior on scale {
                        MotionAnimation {}
                    }

                    onClicked: {
                        // Detached wl-copy, not Quickshell.clipboardText: that
                        // selection dies when the panel loses focus, so the
                        // value would vanish before the user can paste it.
                        Quickshell.execDetached(["wl-copy", fmtRow.copyValue]);
                        page.copiedFormat = fmtRow.formatKey;
                        page.copiedHex = page.shownHex;
                        justClicked = true;
                        tooltipReset.restart();
                    }

                    Timer {
                        id: tooltipReset

                        interval: 1200

                        onTriggered: copyButton.justClicked = false
                    }

                    MD.ToolTip {
                        id: copiedTip

                        // Anchor the popup to the row, not the button: it opens
                        // on click, while the button's press scale (0.88 -> 1)
                        // is still springing back, and a popup tracks its
                        // parent's transform — parented to the button it drifts
                        // for a beat after appearing. The row never scales.
                        parent: fmtRow
                        x: copyButton.x + (copyButton.width - copiedTip.implicitWidth) / 2
                        y: copyButton.y + copyButton.height + 4
                        // MD.ToolTip defaults to a 500ms hover delay; this one
                        // is driven by a click, so show it the instant it opens.
                        delay: 0
                        text: I18n.t("quickSettings.colorPicker.copied")
                        visible: copyButton.justClicked
                    }
                }
            }
        }
    }
}
