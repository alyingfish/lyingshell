import QtQuick
import Qcm.Material as MD

// MD3 slider row for the quick-settings panel (GNOME QuickSlider): leading
// icon (optionally a real button, e.g. mute), MD.Slider, optional trailing
// chevron opening a detail page. Value is service-owned: bound in via
// `value`, user drags emit `moved` and the service loops the state back.
Item {
    id: control

    required property string iconName
    property real value: 0
    property bool iconReactive: false
    property bool iconChecked: false
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
            icon.name: control.iconName
            checked: control.iconChecked

            onClicked: control.iconClicked()
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

        from: 0
        to: 1

        onMoved: control.moved(value)
    }

    // A Binding object re-asserts service state even after user drags have
    // written slider.value directly.
    Binding {
        target: slider
        property: "value"
        value: control.value
    }

    MD.IconButton {
        id: detailArrow

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: control.hasDetail

        mdState.type: MD.Enum.IBtStandard
        icon.name: control.expanded ? "expand_less" : "expand_more"

        onClicked: control.detailRequested()
    }
}
