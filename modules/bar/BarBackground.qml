import Quickshell
import Quickshell.Io
import QtQuick
import qs.common

Rectangle {
    id: barBackground

    property int panelTopMargin
    property bool isColumnMaximized: false
    property string barStyle: isColumnMaximized ? Config.options.bar.maximizeStyle : Config.options.bar.regularStyle

    color: Config.options.bar.backgroundColor
    anchors.fill: parent
    // height: Config.options.bar.height
    anchors.bottomMargin: Config.options.bar.radius

    states: [
        State {
            name: "hidden"
            when: barBackground.barStyle === "hidden"
            PropertyChanges {
                target: barBackground
                panelTopMargin: -parent.implicitHeight
            }
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
            PropertyChanges {
                target: barTopLeftCorner
                opacity: 0
            }
            PropertyChanges {
                target: barTopRightCorner
                opacity: 0
            }
        },
        State {
            name: "rectangle"
            when: barBackground.barStyle === "rectangle"
            PropertyChanges {
                target: barBackground
                panelTopMargin: 0
                anchors.leftMargin: 0
                anchors.rightMargin: 0
                radius: 0
            }
            PropertyChanges {
                target: barTopLeftCorner
                opacity: 0
            }
            PropertyChanges {
                target: barTopRightCorner
                opacity: 0
            }
        },
        State {
            name: "hug"
            when: barBackground.barStyle === "hug"
            PropertyChanges {
                target: barBackground
                panelTopMargin: 0
                // anchors.bottomMargin: 0
                anchors.leftMargin: 0
                anchors.rightMargin: 0
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

    RoundCorner {
        id: barTopLeftCorner
        opacity: 0 // Hidden by default
        size: Config.options.bar.radius
        color: barBackground.color
        corner: RoundCorner.CornerEnum.TopLeft
        anchors.top: barBackground.verticalCenter
        anchors.left: barBackground.left
    }

    RoundCorner {
        id: barTopRightCorner
        opacity: 0 // Hidden by default
        size: Config.options.bar.radius
        color: barBackground.color
        corner: RoundCorner.CornerEnum.TopRight
        anchors.top: barBackground.verticalCenter
        anchors.right: barBackground.right
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            barBackground.isColumnMaximized = !barBackground.isColumnMaximized;
        }
    }
}
