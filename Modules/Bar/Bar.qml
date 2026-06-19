import QtQuick
import Quickshell
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Modules.Bar.Widgets
import qs.Services.Niri

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Settings.options.bar.height
    exclusiveZone: implicitHeight
    color: MD.Token.color.surface_container

    Item {
        id: content

        readonly property int edgeMargin: 8
        readonly property int rowSpacing: 8
        readonly property int minimumCenterGap: 24
        readonly property real availableWidth: width - edgeMargin * 2
        readonly property bool rightContentVisible: availableWidth >= leftContent.implicitWidth + rightContent.implicitWidth + minimumCenterGap
        readonly property bool centerContentVisible: rightContentVisible
            && availableWidth >= leftContent.implicitWidth + rightContent.implicitWidth + centerDateTime.implicitWidth + minimumCenterGap * 2

        anchors.fill: parent
        anchors.leftMargin: edgeMargin
        anchors.rightMargin: edgeMargin

        Row {
            id: leftContent

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: content.rowSpacing

            Workspaces {
                workspaceModel: root.screen && root.screen.name
                    ? Niri.workspacesByOutput[root.screen.name] || []
                    : []

                onFocusRequested: function(workspaceId) {
                    Niri.focusWorkspaceById(workspaceId);
                }
            }
        }

        Row {
            id: rightContent

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: content.rowSpacing
            visible: content.rightContentVisible

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
                font.family: Theme.textTypeface
                verticalAlignment: Text.AlignVCenter
            }
        }

        DateTime {
            id: centerDateTime

            anchors.centerIn: parent
            visible: content.centerContentVisible
        }
    }
}
