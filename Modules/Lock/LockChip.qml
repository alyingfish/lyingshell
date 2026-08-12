import QtQuick
import Qcm.Material as MD
import qs.Commons.Theme
import qs.Material

import "../../Material/Motion.js" as Motion

// A tonal chip under the password pill: the caps-lock warning and the refusal
// answer. It takes no room at all when it is not showing, so the column does
// not reserve a gap for something that is usually absent — the pill's own
// spacing is what the eye reads at rest.
Item {
    id: root

    required property real cqw
    required property real cqh

    property bool shown: false
    property string text: ""
    property string icon: ""
    property color background: MD.Token.color.tertiary_container
    property color ink: MD.Token.color.on_tertiary_container

    implicitWidth: shown ? body.implicitWidth : 0
    implicitHeight: shown ? 1.3 * cqh + body.implicitHeight : 0

    Behavior on implicitHeight {
        MotionAnimation {
            spring: Motion.spatialFast
        }
    }

    clip: true

    Item {
        id: body

        implicitWidth: chip.implicitWidth
        implicitHeight: chip.implicitHeight

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.8

        transform: Translate {
            y: root.shown ? 0 : 1.2 * root.cqh
        }

        Behavior on opacity {
            MotionAnimation {
                spring: Motion.effectsDefault
            }
        }
        Behavior on scale {
            MotionAnimation {
                spring: Motion.spatialFast
            }
        }

        Rectangle {
            id: chip

            implicitWidth: row.implicitWidth + 2.1 * root.cqw
            implicitHeight: row.implicitHeight + 1.4 * root.cqh

            radius: height / 2
            color: root.background

            Row {
                id: row

                anchors.centerIn: parent
                spacing: 0.45 * root.cqw

                MD.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.icon.length > 0
                    name: root.icon
                    size: 1.0 * root.cqw
                    color: root.ink
                }

                MD.Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.text
                    color: root.ink
                    font.family: Theme.textTypeface
                    font.pixelSize: 0.83 * root.cqw
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
