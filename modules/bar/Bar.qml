// Bar.qml
import Quickshell
import Quickshell.Io
import QtQuick
import qs.common

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barPanelWindow
            required property var modelData
            screen: modelData
            implicitHeight: Config.options.bar.height
            anchors {
                top: true
                left: true
                right: true
            }
            color: "transparent"

            property bool isColumnMaximized: false
            property int currentStyle: isColumnMaximized ? Config.options.bar.maximizeStyle : Config.options.bar.regularStyle
            visible: currentStyle !== Config.BarStyle.Hidden
            property int barMargin: {
                switch (currentStyle) {
                case Config.BarStyle.Float:
                    return 10;
                default:
                    return 0;
                }
            }
            property int barRadius: {
                switch (currentStyle) {
                case Config.BarStyle.Float:
                    return 15;
                default:
                    return 0;
                }
            }

            Rectangle {
                id: barBackground
                anchors.fill: parent
                anchors.leftMargin: barMargin
                anchors.rightMargin: barMargin
                radius: barRadius
            }

            // BarCorner {
            //     id: barTopLeftCorner
            //     visible: barPanelWindow.currentStyle === Config.BarStyle.Hug
            //     color: "black"
            //     corner: BarCorner.CornerEnum.TopLeft
            //     implicitSize: Config.options.bar.radius
            //     anchors.top: barBackground.top
            //     anchors.left: barBackground.left
            // }

            margins {
                top: barMargin
            }

            Behavior on barMargin {
                NumberAnimation {
                    duration: 100
                }
            }
            Behavior on barRadius {
                NumberAnimation {
                    duration: 100
                }
            }

            BarContent {
                anchors.fill: parent
                anchors.leftMargin: barMargin + Config.options.bar.radius
                anchors.rightMargin: barMargin + Config.options.bar.radius
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    isColumnMaximized = !isColumnMaximized;
                }
            }
        }
    }
}
