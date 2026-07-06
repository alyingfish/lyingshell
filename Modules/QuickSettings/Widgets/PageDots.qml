import QtQuick
import Qcm.Material as MD
import qs.Material
import "../../../Material/Motion.js" as Motion

// Page indicator (prototype .tiles-dots): 6px dots; the active page morphs
// to a 20px primary pill.
Item {
    id: root

    property int page: 0
    property int pageCount: 1

    signal pageRequested(int page)

    implicitHeight: 12
    height: 12

    Row {
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.pageCount

            Rectangle {
                id: pageDot

                required property int index
                readonly property bool current: root.page === index

                anchors.verticalCenter: parent.verticalCenter
                width: current ? 20 : 6
                height: 6
                radius: 3
                color: current ? MD.Token.color.primary : MD.Token.color.outline_variant

                Behavior on width {
                    MotionAnimation {}
                }

                Behavior on color {
                    MotionColorAnimation {
                        spring: Motion.effectsSlow
                    }
                }

                TapHandler {
                    // Extends the 6px dot to a usable hit target.
                    margin: 8

                    onTapped: root.pageRequested(pageDot.index)
                }
            }
        }
    }
}
