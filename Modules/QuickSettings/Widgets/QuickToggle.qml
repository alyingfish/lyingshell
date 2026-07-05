import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import "../../Material/Motion.js" as Motion

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

    checkable: false

    // Desktop-compact: XS tokens in the web-prototype's 44px tile; touch-size
    // MD3 metrics read oversized on a pointer-driven desktop shell.
    mdState.size: MD.Enum.XS
    mdState.type: checked ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
    // Cross-fade the selection colors on the M3E effects spring (critically
    // damped, never overshoots) so the fill animates in step with the shape
    // morph instead of snapping. `checked` is outside StateButton's state
    // machine, so the library never animates these on its own.
    property color animBackground: checked ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_highest
    property color animText: checked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface
    Behavior on animBackground {
        ColorAnimation {
            duration: Motion.effectsDefault.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.effectsDefault.curve
        }
    }
    Behavior on animText {
        ColorAnimation {
            duration: Motion.effectsDefault.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.effectsDefault.curve
        }
    }
    mdState.backgroundColor: animBackground
    mdState.textColor: animText

    // MD3 expressive toggle shape morph: stadium unselected, rounded-rect
    // selected; pressed still wins with the StateButton pressed corner.
    // Spatial-fast spring (the bouncy M3E one); MState's internal 100ms
    // corner Behavior rides on top as a small follower lag.
    property real stateCorner: checked && !down ? MD.Token.shape.corner.medium : mdState.corner
    Behavior on stateCorner {
        NumberAnimation {
            duration: Motion.spatialFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatialFast.curve
        }
    }
    // Select pop (web prototype `pop` keyframes): the icon rescales through
    // the same spring, whose overshoot supplies the bounce. Select only —
    // deselect stays quiet, like the prototype.
    onCheckedChanged: if (checked)
        iconPop.restart()
    mdState.corners: splitCorners ? MD.Util.corners(stateCorner, MD.Token.split_button.xsmall.inner_corner_size, stateCorner, MD.Token.split_button.xsmall.inner_corner_size) : MD.Util.corners(stateCorner)

    implicitHeight: 44
    icon.width: MD.Token.button.xsmall.icon_size
    icon.height: MD.Token.button.xsmall.icon_size
    // As a split-button leading half MD3 tightens the padding (12/10) toward
    // the divider vs a standalone XS button (16/16); the wider standalone
    // padding truncated long labels like "Bluetooth".
    leftPadding: splitCorners ? MD.Token.split_button.xsmall.leading_button_leading_space : MD.Token.button.xsmall.leading_space
    rightPadding: splitCorners ? MD.Token.split_button.xsmall.leading_button_trailing_space : MD.Token.button.xsmall.trailing_space

    contentItem: Item {
        implicitWidth: toggleIcon.width + control.mdState.spacing + titleText.implicitWidth
        implicitHeight: Math.max(toggleIcon.height, titleText.implicitHeight)
        opacity: control.mdState.contentOpacity

        MD.Icon {
            id: toggleIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: control.icon.name
            size: control.icon.width
            color: control.mdState.textColor
            fill: control.checked

            NumberAnimation {
                id: iconPop

                target: toggleIcon
                property: "scale"
                from: 0.6
                to: 1
                duration: Motion.spatialFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast.curve
            }
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

    // Full text on hover when the compact cell truncates it (long SSIDs).
    MD.ToolTip {
        // Below the button, like bar-tray tooltips (library default is above).
        y: parent.height + 4
        text: titleText.text
        visible: control.hovered && titleText.truncated
    }
}
