// Bar.qml
import Quickshell
import QtQuick

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barPanelWindow

            required property var modelData
            screen: modelData
            color: "transparent"
            implicitHeight: barBackground.implicitHeight + barBackground.cornerRadius
            exclusiveZone: barBackground.implicitHeight
            anchors {
                top: true
                left: true
                right: true
            }
            margins.top: barBackground.panelWindowMargin

            BarBackground {
                id: barBackground
                BarContent {
                    anchors.fill: parent
                    anchors.leftMargin: parent.cornerRadius
                    anchors.rightMargin: parent.cornerRadius
                }
            }
        }
    }
}
