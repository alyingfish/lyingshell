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

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 30

            Text {
                anchors.centerIn: parent
                text: "Hello world"
            }
        }
    }
}
