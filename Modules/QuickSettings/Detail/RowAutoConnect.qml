import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Modules.QuickSettings.Controls

// Per-profile auto-connect switch row (prototype .wf-auto): Wi-Fi maps it to
// NM connection.autoconnect, Bluetooth to the BlueZ Trusted flag. M3
// list-with-control: the whole row is the toggle target; it applies
// immediately (a switch, not a checkbox).
Item {
    id: autoRow

    property bool checked: false
    property bool onCurrent: false

    signal toggled(bool checked)

    width: parent ? parent.width : 0
    implicitHeight: 24

    MD.Text {
        anchors.left: parent.left
        anchors.right: rowSwitch.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.t("quickSettings.connectAutomatically")
        color: autoRow.onCurrent ? MD.Token.color.on_secondary_container : MD.Token.color.on_surface
        typescale: MD.Token.typescale.label_large
        prominent: true
        font.family: Theme.textTypeface
        elide: Text.ElideRight
        maximumLineCount: 1
        wrapMode: Text.NoWrap
    }

    MiniSwitch {
        id: rowSwitch

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checkedState: autoRow.checked

        onToggled: autoRow.toggled(checked)
    }

    // The row body toggles too (presses on the switch stay the switch's).
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: rowSwitch.width

        onClicked: autoRow.toggled(!autoRow.checked)
    }
}
