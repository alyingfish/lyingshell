import QtQuick
import Qcm.Material as MD

// MD3 split button pairing a QuickToggle with a trailing arrow segment
// (GNOME QuickMenuToggle). The toggle half emits `clicked`, the arrow half
// emits `expandRequested`; the panel decides whether that opens a menu or a
// detail page and drives `expanded` for the chevron.
Item {
    id: control

    required property string labelKey
    property alias iconName: toggleButton.icon.name
    property alias statusText: toggleButton.statusText
    property alias checkIcon: toggleButton.checkIcon
    property bool checked: false
    property bool expanded: false

    signal clicked
    signal expandRequested

    implicitHeight: toggleButton.implicitHeight
    implicitWidth: toggleButton.implicitWidth + arrow.width + MD.Token.split_button.xsmall.between_space

    QuickToggle {
        id: toggleButton

        anchors.left: parent.left
        anchors.right: arrow.left
        anchors.rightMargin: MD.Token.split_button.xsmall.between_space
        anchors.verticalCenter: parent.verticalCenter

        labelKey: control.labelKey
        checked: control.checked
        splitCorners: true

        onClicked: control.clicked()
    }

    MD.SplitButtonIndicator {
        id: arrow

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // Compact arrow: xsmall spaces around a 16px chevron.
        width: MD.Token.split_button.xsmall.trailing_button_leading_space + 16 + MD.Token.split_button.xsmall.trailing_button_trailing_space
        height: toggleButton.height
        icon.width: 16
        icon.height: 16

        // Display-only check state: the chevron mirrors `expanded`, clicks
        // must not self-toggle.
        checkable: false
        checked: control.expanded

        mdState.size: MD.Enum.XS
        mdState.type: control.checked ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
        mdState.backgroundColor: control.checked ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_highest
        mdState.textColor: control.checked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface_variant

        onClicked: control.expandRequested()
    }
}
