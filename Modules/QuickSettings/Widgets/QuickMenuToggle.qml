import QtQuick
import Qcm.Material as MD
import "../../Material/Motion.js" as Motion

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
        // Cross-fade selection colors in step with the toggle half (M3E
        // effects spring, same as QuickToggle); `checked` is outside the
        // state machine so the library won't animate these.
        property color animBackground: control.checked ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_highest
        property color animText: control.checked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface
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

        // Mirror the toggle half's shape morph so the split tile stays
        // symmetric: outer (trailing) corners go stadium -> medium on select,
        // inner corners stay squared toward the divider. Same spatial-fast
        // spring as QuickToggle; the indicator's internal corner Behavior rides
        // on top as the follower lag. Without this the arrow half kept its
        // default stadium outer corners while the toggle rounded to 12dp.
        property real outerCorner: control.checked ? MD.Token.shape.corner.medium : mdState.baseCorner
        Behavior on outerCorner {
            NumberAnimation {
                duration: Motion.spatialFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialFast.curve
            }
        }
        mdState.corners: MD.Util.corners(MD.Token.split_button.xsmall.inner_corner_size, outerCorner, MD.Token.split_button.xsmall.inner_corner_size, outerCorner)

        onClicked: control.expandRequested()
    }
}
