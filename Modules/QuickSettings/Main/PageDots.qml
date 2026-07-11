import QtQuick
import Qcm.Material as MD
import qs.Material
import "../../../Material/Motion.js" as Motion

// Page indicator (prototype .tiles-dots): 6px dots; the active page morphs to a
// 20px primary pill. Wraps MD.PageIndicator with a custom pill delegate; the
// Item wrapper keeps the caller's width/page/pageCount/pageRequested contract.
Item {
    id: root

    property int page: 0
    property int pageCount: 1

    signal pageRequested(int page)

    implicitHeight: 12
    height: 12

    MD.PageIndicator {
        anchors.centerIn: parent

        count: root.pageCount
        currentIndex: root.page
        // Taps are handled per-dot below so currentIndex stays driven by `page`.
        interactive: false
        padding: 0
        spacing: 6

        delegate: Rectangle {
            id: pageDot

            required property int index
            readonly property bool current: root.page === index

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            implicitWidth: current ? 20 : 6
            implicitHeight: 6
            radius: 3
            color: current ? MD.Token.color.primary : MD.Token.color.outline_variant

            Behavior on implicitWidth {
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
