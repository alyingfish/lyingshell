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

            // Re-run the interactive pick; the result flows back through
            // Niri.lastPickedColor and refreshes the rows in place.
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

                onClicked: Niri.pickColor()
            }

            // HEX/RGB/HSV row: a surface card with a label, the value, and a
            // trailing copy button that flips to a check for a beat on copy.
            component ColorFormatRow: Rectangle {
                id: fmtRow

                property string label: ""
                property string value: ""
                property string copyValue: value

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

                    property bool copied: false

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    mdState.type: MD.Enum.IBtStandard
                    mdState.size: MD.Enum.XS
                    icon.name: copied ? "check" : "content_copy"
                    icon.width: 18
                    icon.height: 18
                    scale: down ? 0.88 : 1

                    Behavior on scale {
                        MotionAnimation {}
                    }

                    onClicked: {
                        Quickshell.clipboardText = fmtRow.copyValue;
                        copied = true;
                        copiedReset.restart();
                    }

                    Timer {
                        id: copiedReset

                        interval: 1200

                        onTriggered: copyButton.copied = false
                    }

                    MD.ToolTip {
                        y: parent.height + 4
                        text: I18n.t("quickSettings.colorPicker.copied")
                        visible: copyButton.copied
                    }
                }
            }
        }
    }
}
