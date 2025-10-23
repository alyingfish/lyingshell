// Bar.qml
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            implicitHeight: 30
            anchors {
                top: true
                left: true
                right: true
            }
            color: "transparent"

            property bool isFloat: true
            property int barMargin: isFloat ? 10 : 0
            property int barRadius: isFloat ? 15 : 0

            margins {
                top: barMargin
            }

            Rectangle {
                id: barBackground
                anchors.fill: parent
                anchors.leftMargin: barMargin
                anchors.rightMargin: barMargin
                radius: barRadius
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
                anchors.leftMargin: barMargin + 15
                anchors.rightMargin: barMargin + 15
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    isFloat = isFloat ? false : true;
                }
            }
        }
    }
}
