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
            color: "transparent"
            implicitHeight: Config.options.bar.height + Config.options.bar.style.roundRadius // height for the barBackground, radius for the barCorner
            exclusiveZone: Config.options.bar.height
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
                    anchors.leftMargin: Config.options.bar.style.roundRadius
                    anchors.rightMargin: Config.options.bar.style.roundRadius
                }
            }
        }
    }
}
