import QtQuick
import Qcm.Material as MD

// Test stand-in for the bar's quick-settings pill. The real widget pulls the
// whole quick-settings tree (network, bluetooth, audio, upower); the lock
// scene only needs a pill-shaped thing of the right size in the right corner,
// and the panel's own behaviour is covered by the quick-settings tests.
Item {
    id: root

    property bool registerIpc: true
    property color surfaceColor: "transparent"
    property color surfaceHoverColor: "transparent"
    property Item overlayParent: null
    property rect barSurfaceRect
    property bool panelOpen: false
    readonly property bool expanded: false
    readonly property var panel: ({
            "detail": "",
            "sessionMenuOpen": false,
            "toolsOpen": false,
            "pmodeOpen": false
        })

    implicitWidth: 132
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.surfaceColor

        Row {
            anchors.centerIn: parent
            spacing: 8

            MD.Icon {
                name: "wifi"
                size: 16
                color: MD.Token.color.on_surface
            }
            MD.Icon {
                name: "bluetooth"
                size: 16
                color: MD.Token.color.on_surface
            }
            MD.Icon {
                name: "volume_up"
                size: 16
                color: MD.Token.color.on_surface
            }
            MD.Icon {
                name: "battery_5_bar"
                size: 16
                color: MD.Token.color.on_surface
            }
        }
    }
}
