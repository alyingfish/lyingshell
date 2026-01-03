import QtQuick
import Quickshell
import qs.common

PopupWindow {
    id: root

    required property Item target
    required property string text

    // 1. Anchor to the BOTTOM of the icon
    anchor {
        item: target
        gravity: Edges.Bottom
        edges: Edges.Bottom
    }

    // 2. Add a gap so the mouse doesn't accidentally touch the window
    anchor.margins.top: 5

    // Standard settings
    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 10

    color: "transparent"

    // Background
    Rectangle {
        anchors.fill: parent
        color: Theme.colors.bar.systemTray.tooltipBackground
        border.width: 0
        radius: 4

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.colors.bar.systemTray.tooltipTextColor
            font.pixelSize: 12
        }
    }
}
