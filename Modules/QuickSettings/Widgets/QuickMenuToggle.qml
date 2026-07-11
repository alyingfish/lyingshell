import QtQuick
import Qcm.Material as MD
import qs.Material

// Web-prototype split tile pairing a QuickToggle with a trailing arrow
// segment (GNOME QuickMenuToggle): 2px divider, 38px arrow, outer corners
// 22 -> 14 on select while the divider edge holds 6 -> 5. The toggle half
// emits `clicked`; the arrow half emits `expandRequested` and always
// navigates to an in-panel detail page, so it shows a static chevron_right,
// never an expand chevron.
Item {
    id: control

    required property string labelKey
    property alias iconName: toggleButton.icon.name
    property alias offIconName: toggleButton.offIconName
    property alias statusText: toggleButton.statusText
    property alias pulsing: toggleButton.pulsing
    property bool checked: false

    signal clicked()
    signal expandRequested()

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

        // Cross-fade selection colors in step with the toggle half (M3E
        // effects spring, same as QuickToggle); `checked` is outside the
        // state machine so the library won't animate these.
        property color animBackground: control.checked ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_high
        property color animText: control.checked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface_variant
        // Mirror the toggle's morph so the split tile stays symmetric: outer
        // corners step 22 -> 14 on select, the divider edge holds 6 -> 5.
        // Step it (no spring Behavior) for the same reason as QuickToggle —
        // a spring here stalls the internal Behavior.
        readonly property real outerCorner: control.checked ? toggleButton.selectedCorner : height / 2
        readonly property real dividerCorner: toggleButton.innerCorner

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // Prototype `.chev`: a fixed 38px arrow segment with a 16px chevron.
        width: 38
        height: toggleButton.height
        icon.width: 16
        icon.height: 16
        // Navigation into a detail page, not a dropdown below.
        icon.name: "chevron_right"
        // Clicks must not self-toggle a check state.
        checkable: false
        mdState.size: MD.Enum.XS
        mdState.type: control.checked ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
        mdState.backgroundColor: animBackground
        mdState.textColor: animText
        mdState.corners: MD.Util.corners(dividerCorner, outerCorner, dividerCorner, outerCorner)
        onClicked: control.expandRequested()

        Behavior on animBackground {
            MotionColorAnimation {
            }

        }

        Behavior on animText {
            MotionColorAnimation {
            }

        }

    }

}
