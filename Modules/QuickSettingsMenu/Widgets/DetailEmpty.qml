import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme

// Empty state for a detail page whose radio is off (prototype .dv-empty).
Item {
    id: emptyState

    property string name: ""
    // Height of the detail list viewport, so the message centers like the
    // prototype (handed down from DetailView via the page).
    property real viewportHeight: 0

    width: parent ? parent.width : 0
    implicitHeight: viewportHeight

    Column {
        anchors.centerIn: parent
        spacing: 4

        MD.Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("quickSettings.detailOffTitle", {
                "name": emptyState.name
            })
            color: MD.Token.color.on_surface_variant
            typescale: MD.Token.typescale.label_large
            prominent: true
            font.family: Theme.textTypeface
        }

        MD.Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("quickSettings.detailOffHint")
            color: MD.Token.color.on_surface_variant
            opacity: 0.75
            typescale: MD.Token.typescale.body_small
            font.family: Theme.textTypeface
        }
    }
}
