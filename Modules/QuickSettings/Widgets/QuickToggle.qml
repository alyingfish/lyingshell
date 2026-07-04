import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme

// MD3 toggle-button cell for the quick-settings grid (GNOME QuickToggle).
// Display state is service-owned: `checked` is bound in, clicks only emit
// `clicked` and the caller flips the service. MD3 toggle-button colors
// (selected primary / unselected surface-container-highest) are not a
// QmlMaterial button variant, so they override the StateButton bindings.
MD.Button {
    id: control

    required property string labelKey
    // Runtime OS data shown as the second line (SSID, device name, ...).
    property string statusText: ""
    // Squared trailing edge when an arrow segment sits to the right.
    property bool splitCorners: false

    checkable: false

    // Desktop-compact: S-size tokens with a 48px two-line cell (GNOME QS
    // rhythm); M-size touch metrics are too tall for a pointer-driven shell.
    mdState.size: MD.Enum.S
    mdState.type: checked ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
    mdState.backgroundColor: checked ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_highest
    mdState.textColor: checked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface_variant
    mdState.corners: splitCorners ? MD.Util.corners(mdState.corner, MD.Token.split_button.small.inner_corner_size, mdState.corner, MD.Token.split_button.small.inner_corner_size) : MD.Util.corners(mdState.corner)

    implicitHeight: 48
    // xsmall spaces: the small-size 24px paddings starve fixed grid cells.
    leftPadding: MD.Token.button.xsmall.leading_space
    rightPadding: MD.Token.button.xsmall.trailing_space

    contentItem: Item {
        implicitWidth: toggleIcon.width + control.mdState.spacing + Math.max(titleText.implicitWidth, subtitleText.visible ? subtitleText.implicitWidth : 0)
        implicitHeight: Math.max(toggleIcon.height, labelColumn.implicitHeight)
        opacity: control.mdState.contentOpacity

        MD.Icon {
            id: toggleIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: control.icon.name
            size: control.icon.width
            color: control.mdState.textColor
            fill: control.checked
        }

        Column {
            id: labelColumn

            anchors.left: toggleIcon.right
            anchors.leftMargin: control.mdState.spacing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            MD.Text {
                id: titleText

                width: parent.width
                text: I18n.t(control.labelKey)
                color: control.mdState.textColor
                typescale: MD.Token.typescale.label_large
                font.family: Theme.textTypeface
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            MD.Text {
                id: subtitleText

                width: parent.width
                visible: control.statusText.length > 0
                text: control.statusText
                color: control.mdState.textColor
                typescale: MD.Token.typescale.body_small
                font.family: Theme.textTypeface
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }
        }
    }
}
