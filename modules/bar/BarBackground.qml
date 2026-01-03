import QtQuick
import qs.common
import qs.services

Rectangle {
    id: barBackground

    property bool hasWindows: NiriService.focusedWorkspace.active_window_id ?? false
    property bool isOverviewOpened: NiriService.isOverviewOpened
    property string barStyle: isOverviewOpened ? "hidden" : hasWindows ? Config.options.bar.style.hasWindowStyle : Config.options.bar.style.noWindowStyle
    // default to Rectangle
    property int panelWindowMargin: 0
    property int cornerOpacity: 0
    property int cornerRadius: Config.options.bar.style.roundRadius

    anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        leftMargin: 0
        rightMargin: 0
    }
    implicitHeight: Config.options.bar.height
    radius: 0
    color: Theme.colors.bar.background
    border.width: 0

    states: [
        State {
            name: "rectangle"
            when: barBackground.barStyle === "rectangle"
        },
        State {
            name: "float"
            when: barBackground.barStyle === "float"
            PropertyChanges {
                target: barBackground
                panelWindowMargin: Config.options.bar.style.floatMargin
                anchors.leftMargin: Config.options.bar.style.floatMargin
                anchors.rightMargin: Config.options.bar.style.floatMargin
                radius: cornerRadius
            }
        },
        State {
            name: "hug"
            when: barBackground.barStyle === "hug"
            PropertyChanges {
                target: barBackground
                cornerOpacity: 1
            }
        },
        State {
            name: "hidden"
            when: barBackground.barStyle === "hidden"
            PropertyChanges {
                target: barBackground
                panelWindowMargin: -barBackground.implicitHeight
            }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation {
                properties: "panelWindowMargin, cornerOpacity, anchors.leftMargin, anchors.rightMargin, radius"
                duration: 100
                easing.type: Easing.InOutQuad
            }
        }
    ]

    RoundCorner {
        anchors {
            top: parent.bottom
            left: parent.left
        }
        implicitSize: parent.cornerRadius
        color: parent.color
        corner: RoundCorner.CornerEnum.TopLeft
        opacity: parent.cornerOpacity
    }

    RoundCorner {
        anchors {
            top: parent.bottom
            right: parent.right
        }
        implicitSize: parent.cornerRadius
        color: parent.color
        corner: RoundCorner.CornerEnum.TopRight
        opacity: parent.cornerOpacity
    }

}
