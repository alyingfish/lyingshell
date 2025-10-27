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
            implicitHeight: Config.options.bar.height + Config.options.bar.radius // height for the barBackground, radius for the barCorner
            exclusiveZone: Config.options.bar.height
            anchors {
                top: true
                left: true
                right: true
            }
            margins.top: barBackground.panelTopMargin

            BarBackground {
                id: barBackground
            }

            BarContent {
                anchors.fill: barBackground
                anchors.leftMargin: Config.options.bar.radius
                anchors.rightMargin: Config.options.bar.radius
            }
        }
    }
}
