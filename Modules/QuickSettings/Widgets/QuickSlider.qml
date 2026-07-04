import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Modules.Material

// MD3 slider row for the quick-settings panel (GNOME QuickSlider): leading
// icon (optionally a real button, e.g. mute or night light), MD.Slider,
// optional trailing chevron opening a detail page. Value is service-owned:
// bound in via `value` (0..1), user drags emit `moved` and the service loops
// the state back. The slider runs 0..100 internally so the MD3 value
// indicator reads as a percentage.
Item {
    id: control

    required property string iconName
    property real value: 0
    property bool iconReactive: false
    property bool iconChecked: false
    // I18n token for the leading icon-button hover tooltip.
    property string iconTooltipKey: ""
    property bool hasDetail: false
    property bool expanded: false

    signal moved(real newValue)
    signal iconClicked
    signal detailRequested

    implicitHeight: Math.max(iconSlot.implicitHeight, slider.implicitHeight)
    implicitWidth: iconSlot.implicitWidth + slider.implicitWidth

    // Non-reactive icons render plain (a disabled button would dim them).
    Item {
        id: iconSlot

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: iconButton.implicitWidth
        implicitHeight: iconButton.implicitHeight
        width: implicitWidth
        height: implicitHeight

        MD.IconButton {
            id: iconButton

            anchors.centerIn: parent
            visible: control.iconReactive

            mdState.type: MD.Enum.IBtStandard
            mdState.size: MD.Enum.XS
            icon.name: control.iconName
            checked: control.iconChecked

            onClicked: control.iconClicked()

            MD.ToolTip {
                text: control.iconTooltipKey.length > 0 ? I18n.t(control.iconTooltipKey) : ""
                visible: iconButton.hovered && text.length > 0
            }
        }

        MD.Icon {
            anchors.centerIn: parent
            visible: !control.iconReactive
            name: control.iconName
            size: iconButton.icon.width
            color: MD.MProp.color.on_surface_variant
        }
    }

    MD.Slider {
        id: slider

        anchors.left: iconSlot.right
        anchors.right: detailArrow.visible ? detailArrow.left : parent.right
        anchors.verticalCenter: parent.verticalCenter

        // Desktop-compact: 16dp XS track + short handle instead of the
        // default 44dp expressive slider.
        implicitHeight: 16
        mdState.handleHeight: 24

        from: 0
        to: 100

        onMoved: control.moved(value / 100)

        // Compact handle with a percent value indicator on press/drag and
        // keyboard focus (upstream handle hardcodes 44dp and 0..1 labels).
        handle: SliderHandle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + (slider.availableHeight - height) / 2
            value: slider.value
            text: I18n.t("quickSettings.percentValue", {
                "percent": Math.round(slider.value)
            })
            handleHasFocus: slider.visualFocus
            handlePressed: slider.pressed
            horizontal: slider.horizontal
            handleWidth: slider.mdState.handleWidth
            handleHeight: slider.mdState.handleHeight
            handleLineWidth: slider.mdState.handleLineWidth
        }
    }

    // A Binding object re-asserts service state even after user drags have
    // written slider.value directly.
    Binding {
        target: slider
        property: "value"
        value: control.value * 100
    }

    MD.IconButton {
        id: detailArrow

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: control.hasDetail

        mdState.type: MD.Enum.IBtStandard
        mdState.size: MD.Enum.XS
        icon.name: control.expanded ? "expand_less" : "expand_more"

        onClicked: control.detailRequested()
    }
}
