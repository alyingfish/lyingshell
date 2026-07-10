import QtQuick
import Quickshell
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Material
import qs.Services.Niri

// Color-picker result page (dank-style readout): a large swatch of the color
// niri handed back, then HEX / RGB / HSV rows each with a copy button, and a
// "pick again" action. Replaces the old dead-end chip swatch -- the picked
// value is now reusable. Reached only after a successful pick (the panel pushes
// it on Niri.colorPicked), so a color is normally present; the prompt is a
// fallback for an empty state. Reads the result through the Niri singleton.
DetailPage {
    id: root

    // "Pick again" hands off to the panel's beginColorPick: the card closes
    // for the aim and reopens on this page when niri replies.
    signal pickRequested

    detailName: "color"
    title: I18n.t("quickSettings.tool.colorPicker")

    bodyContent: Component {
        Column {
            id: page

            // Required by DetailPage (centres empty states in the viewport).
            property real viewportHeight: 0

            readonly property bool hasColor: Niri.lastPickedColor.length > 0
            readonly property color picked: hasColor ? Niri.lastPickedColor : "transparent"
            readonly property int r: Math.round(picked.r * 255)
            readonly property int g: Math.round(picked.g * 255)
            readonly property int b: Math.round(picked.b * 255)
            // hsvHue is -1 for achromatic (grey); clamp it to 0.
            readonly property int h: Math.round((picked.hsvHue < 0 ? 0 : picked.hsvHue) * 360)
            readonly property int s: Math.round(picked.hsvSaturation * 100)
            readonly property int v: Math.round(picked.hsvValue * 100)

            // Label of the row whose value is currently on the clipboard, so
            // exactly one row shows a persistent "copied" check. Seeded to the
            // HEX row because the panel auto-copies HEX on every pick; a manual
            // copy of another row hands the check over to it.
            property string copiedFormat: ""

            width: parent ? parent.width : 0
            spacing: 8

            // Large preview swatch.
            Rectangle {
                width: parent.width
                height: 72
                radius: 16
                visible: page.hasColor
                color: page.picked
                border.width: 1
                border.color: MD.Token.color.outline_variant
            }

            // Empty-state fallback (color never picked).
            MD.Text {
                width: parent.width
                visible: !page.hasColor
                text: I18n.t("quickSettings.colorPicker.prompt")
                color: MD.Token.color.on_surface_variant
                typescale: MD.Token.typescale.body_medium
                font.family: Theme.textTypeface
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            ColorFormatRow {
                width: parent.width
                visible: page.hasColor
                label: I18n.t("quickSettings.colorPicker.hex")
                value: Niri.lastPickedColor.toUpperCase()
                // The panel auto-copies the picked HEX to the clipboard on
                // every pick; echo that on this row so the notice isn't silent.
                echoAutoCopy: true
            }

            ColorFormatRow {
                width: parent.width
                visible: page.hasColor
                label: I18n.t("quickSettings.colorPicker.rgb")
                value: page.r + ", " + page.g + ", " + page.b
                copyValue: "rgb(" + page.r + ", " + page.g + ", " + page.b + ")"
            }

            ColorFormatRow {
                width: parent.width
                visible: page.hasColor
                label: I18n.t("quickSettings.colorPicker.hsv")
                value: page.h + "°, " + page.s + "%, " + page.v + "%"
                copyValue: page.h + ", " + page.s + ", " + page.v
            }

            // Re-run the interactive pick; the panel closes out of the way
            // and the result flows back through Niri.lastPickedColor,
            // refreshing the rows when the panel reopens on this page.
            MD.Button {
                id: pickAgainBtn

                width: parent.width
                implicitHeight: 46
                flat: true
                topInset: 0
                bottomInset: 0
                leftInset: 0
                rightInset: 0
                mdState.size: MD.Enum.XS
                mdState.type: MD.Enum.BtFilledTonal
                mdState.corners: MD.Util.corners(15)
                scale: down ? 0.97 : 1

                Behavior on scale {
                    MotionAnimation {}
                }

                contentItem: Item {
                    implicitWidth: pickAgainRow.implicitWidth
                    implicitHeight: pickAgainRow.implicitHeight
                    opacity: pickAgainBtn.mdState.contentOpacity

                    Row {
                        id: pickAgainRow

                        anchors.centerIn: parent
                        spacing: 8

                        MD.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "colorize"
                            size: 18
                            color: pickAgainBtn.mdState.textColor
                        }

                        MD.Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("quickSettings.colorPicker.pickAgain")
                            color: pickAgainBtn.mdState.textColor
                            typescale: MD.Token.typescale.label_large
                            prominent: true
                            font.family: Theme.textTypeface
                        }
                    }
                }

                onClicked: root.pickRequested()
            }

            // HEX/RGB/HSV row: a surface card with a label, the value, and a
            // trailing copy button. The button shows a persistent check while
            // this row's value is the one on the clipboard (page.copiedFormat),
            // so the auto-copied HEX reads as "already copied" without a flash.
            component ColorFormatRow: Rectangle {
                id: fmtRow

                property string label: ""
                property string value: ""
                property string copyValue: value
                // The HEX row sets this: on every pick the panel auto-copies
                // HEX, so seed page.copiedFormat to this row's label to claim
                // the check without touching the clipboard ourselves.
                property bool echoAutoCopy: false

                // True while this row's value is what sits on the clipboard.
                readonly property bool onClipboard: page.copiedFormat.length > 0 && page.copiedFormat === label

                // Claim the "copied" check on a fresh pick. onColorPicked covers
                // "pick again" (this row already exists); onCompleted covers the
                // first pick, where the signal fired before this row was built
                // (the readout page is pushed only after the pick completes).
                Component.onCompleted: if (echoAutoCopy && page.hasColor)
                    page.copiedFormat = label

                Connections {
                    target: Niri
                    enabled: fmtRow.echoAutoCopy

                    function onColorPicked(hex) {
                        page.copiedFormat = fmtRow.label;
                    }
                }

                implicitHeight: 46
                radius: 15
                color: MD.Token.color.surface_container_high

                MD.Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    text: fmtRow.label
                    color: MD.Token.color.on_surface_variant
                    typescale: MD.Token.typescale.label_medium
                    font.family: Theme.textTypeface
                }

                MD.Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 64
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
                    anchors.rightMargin: 6
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
                        page.copiedFormat = fmtRow.label;
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
