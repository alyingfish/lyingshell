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
    // Runtime OS data (SSID, device name, profile, ...) shown instead of the
    // static label while set, so a connected tile reads as its connection.
    property string statusText: ""
    // Squared trailing edge when an arrow segment sits to the right.
    property bool splitCorners: false
    // MD3 expressive selected-icon swap: show a check while checked.
    property bool checkIcon: false

    checkable: false

    // Desktop-compact: XS tokens in a 40px cell; touch-size MD3 metrics read
    // oversized on a pointer-driven desktop shell.
    mdState.size: MD.Enum.XS
    mdState.type: checked ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
    mdState.backgroundColor: checked ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_highest
    mdState.textColor: checked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface_variant

    // MD3 expressive toggle shape morph: stadium unselected, rounded-rect
    // selected; pressed still wins with the StateButton pressed corner.
    readonly property real stateCorner: checked && !down ? MD.Token.shape.corner.medium : mdState.corner
    mdState.corners: splitCorners ? MD.Util.corners(stateCorner, MD.Token.split_button.xsmall.inner_corner_size, stateCorner, MD.Token.split_button.xsmall.inner_corner_size) : MD.Util.corners(stateCorner)

    implicitHeight: 40
    icon.width: MD.Token.button.xsmall.icon_size
    icon.height: MD.Token.button.xsmall.icon_size
    leftPadding: MD.Token.button.xsmall.leading_space
    rightPadding: MD.Token.button.xsmall.trailing_space

    contentItem: Item {
        implicitWidth: toggleIcon.width + control.mdState.spacing + titleText.implicitWidth
        implicitHeight: Math.max(toggleIcon.height, titleText.implicitHeight)
        opacity: control.mdState.contentOpacity

        MD.Icon {
            id: toggleIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: control.checkIcon && control.checked ? "check" : control.icon.name
            size: control.icon.width
            color: control.mdState.textColor
            fill: control.checked
        }

        MD.Text {
            id: titleText

            anchors.left: toggleIcon.right
            anchors.leftMargin: control.mdState.spacing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: control.statusText.length > 0 ? control.statusText : I18n.t(control.labelKey)
            color: control.mdState.textColor
            typescale: MD.Token.typescale.label_medium
            font.family: Theme.textTypeface
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
    }
}
