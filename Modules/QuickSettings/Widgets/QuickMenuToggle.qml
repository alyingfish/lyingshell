import QtQuick
import Qcm.Material as MD

// MD3 split button pairing a QuickToggle with a trailing arrow segment
// (GNOME QuickMenuToggle). The toggle half emits `clicked`; the arrow half
// emits `expandRequested` and always navigates to an in-panel detail page,
// so it shows a static chevron_right, never an expand chevron.
Item {
    id: control

    required property string labelKey
    property alias iconName: toggleButton.icon.name
    property alias statusText: toggleButton.statusText
    property bool checked: false

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
        // Navigation into a detail page, not a dropdown below.
        icon.name: "chevron_right"

        // Clicks must not self-toggle a check state.
        checkable: false

        mdState.size: MD.Enum.XS
        mdState.type: control.checked ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
        mdState.backgroundColor: control.checked ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_highest
        mdState.textColor: control.checked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface

        onClicked: control.expandRequested()
    }
}
