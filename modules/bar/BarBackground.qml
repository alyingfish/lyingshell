import Quickshell
import Quickshell.Io
import QtQuick
import qs.common

Rectangle {
    id: barBackground

    property bool hasWindows: false
    property string barStyle: hasWindows ? Config.options.bar.style.hasWindowStyle : Config.options.bar.style.noWindowStyle

    // default to Rectangle
    property int panelWindowMargin: 0
    anchors {
        fill: parent
        leftMargin: 0
        rightMargin: 0
        bottomMargin: Config.options.bar.style.roundRadius // leave space to barCorner
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
                panelWindowMargin: Config.options.bar.style.floatMargin
                anchors.leftMargin: Config.options.bar.style.floatMargin
                anchors.rightMargin: Config.options.bar.style.floatMargin
                radius: Config.options.bar.style.roundRadius
            }
        },
        State {
            name: "hug"
            when: barBackground.barStyle === "hug"
            PropertyChanges {
                target: barBackground
                radius: Config.options.bar.style.roundRadius
            }
            PropertyChanges {
                target: barLeftCorner
                opacity: 1
            }
            PropertyChanges {
                target: barRightCorner
                opacity: 1
            }
        },
        State {
            name: "hidden"
            when: barBackground.barStyle === "hidden"
            PropertyChanges {
                target: barBackground
                panelWindowMargin: -Config.options.bar.height
            }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation {
                properties: "panelWindowMargin, anchors.leftMargin, anchors.rightMargin, radius"
                duration: 100
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: barLeftCorner
                property: "opacity"
                duration: 100
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: barRightCorner
                property: "opacity"
                duration: 100
                easing.type: Easing.InOutQuad
            }
        }
    ]

    Item {
        id: barLeftCorner

        opacity: 0 // Hidden by default
        width: Config.options.bar.style.roundRadius
        height: Config.options.bar.style.roundRadius * 2
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
            height: Config.options.bar.style.roundRadius
            color: barBackground.color
        }
        RoundCorner {
            size: Config.options.bar.style.roundRadius
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
        id: barRightCorner

        opacity: 0 // Hidden by default
        width: Config.options.bar.style.roundRadius
        height: Config.options.bar.style.roundRadius * 2
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
            height: Config.options.bar.style.roundRadius
            color: barBackground.color
        }
        RoundCorner {
            size: Config.options.bar.style.roundRadius
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
            barBackground.hasWindows = !barBackground.hasWindows;
        }
    }
}
