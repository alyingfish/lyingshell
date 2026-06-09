import QtQuick
import Quickshell
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Modules.Bar.Widgets

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Settings.bar.height
    exclusiveZone: implicitHeight
    color: MD.Token.color.surface_container

    Item {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            MD.Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "dashboard"
                size: 20
                color: MD.Token.color.primary
                fill: true
            }

            MD.Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("app.name")
                color: MD.Token.color.on_surface
                typescale: MD.Token.typescale.title_small
                verticalAlignment: Text.AlignVCenter
            }
        }

        DateTime {
            anchors.centerIn: parent
        }
    }
}
