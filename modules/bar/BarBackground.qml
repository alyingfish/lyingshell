import Quickshell
import Quickshell.Io
import QtQuick
import qs.common

Rectangle {
    id: barBackground

    property bool isColumnMaximized: false
    property string barStyle: isColumnMaximized ? Config.options.bar.maximizeStyle : Config.options.bar.regularStyle

    // default to Rectangle
    property int panelTopMargin: 0
    anchors {
        fill: parent
        leftMargin: 0
        rightMargin: 0
        bottomMargin: Config.options.bar.radius // leave space to barCorner
    }
    radius: 0
    color: Config.options.bar.backgroundColor

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
                panelTopMargin: Config.options.bar.margin
                anchors.leftMargin: Config.options.bar.margin
                anchors.rightMargin: Config.options.bar.margin
                radius: Config.options.bar.radius
            }
        },
        State {
            name: "hug"
            when: barBackground.barStyle === "hug"
            PropertyChanges {
                target: barBackground
                radius: Config.options.bar.radius
            }
            PropertyChanges {
                target: barTopLeftCorner
                opacity: 1
            }
            PropertyChanges {
                target: barTopRightCorner
                opacity: 1
            }
        },
        State {
            name: "hidden"
            when: barBackground.barStyle === "hidden"
            PropertyChanges {
                target: barBackground
                panelTopMargin: -Config.options.bar.height
            }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation {
                properties: "panelTopMargin, anchors.bottomMargin, anchors.leftMargin, anchors.rightMargin, radius"
                duration: 100
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: barTopLeftCorner
                property: "opacity"
                duration: 100
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: barTopRightCorner
                property: "opacity"
                duration: 100
                easing.type: Easing.InOutQuad
            }
        }
    ]

    Item {
        id: barTopLeftCorner

        opacity: 0 // Hidden by default
        width: Config.options.bar.radius
        height: Config.options.bar.radius * 2
        anchors {
            top: barBackground.verticalCenter
            left: barBackground.left
        }
        // to cover the bottom round of barBackground
        Rectangle {
            id: topLeftRect
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: Config.options.bar.radius
            color: barBackground.color
        }
        RoundCorner {
            size: Config.options.bar.radius
            color: barBackground.color
            corner: RoundCorner.CornerEnum.TopLeft
            anchors {
                top: topLeftRect.bottom
                left: parent.left
                right: parent.right
            }
        }
    }

    Item {
        id: barTopRightCorner

        opacity: 0 // Hidden by default
        width: Config.options.bar.radius
        height: Config.options.bar.radius * 2
        anchors {
            top: barBackground.verticalCenter
            right: barBackground.right
        }
        // to cover the bottom round of barBackground
        Rectangle {
            id: topRightRect
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: Config.options.bar.radius
            color: barBackground.color
        }
        RoundCorner {
            size: Config.options.bar.radius
            color: barBackground.color
            corner: RoundCorner.CornerEnum.TopRight
            anchors {
                top: topRightRect.bottom
                left: parent.left
                right: parent.right
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            barBackground.isColumnMaximized = !barBackground.isColumnMaximized;
        }
    }
}
