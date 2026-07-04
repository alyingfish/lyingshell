import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Modules.Material
import "../QuickSettingsIcons.js" as QSIcons

// MD3 slider row for the quick-settings panel (GNOME QuickSlider): leading
// icon (optionally a real button, e.g. mute or night light), MD.Slider,
// optional trailing chevron opening a detail page. Value is service-owned:
// bound in via `value` (0..1), user drags emit `moved` and the service loops
// the state back. The slider runs 0..100 internally so the MD3 value
// indicator reads as a percentage. Row geometry mirrors the web-prototype
// slider-row: 48px row, 4px side insets, 24px icon column, 12px column gap.
Item {
    id: control

    required property string iconName
    property real value: 0
    property bool iconReactive: false
    property bool iconChecked: false
    // I18n token for the leading icon-button hover tooltip.
    property string iconTooltipKey: ""
    property bool hasDetail: false
    // Muted/inactive: the track fades to disabled opacity so the state
    // reads at a glance (the icon alone is too subtle).
    property bool dimmed: false

    signal moved(real newValue)
    signal iconClicked
    signal detailRequested

    implicitHeight: 48
    implicitWidth: iconSlot.width + slider.implicitWidth + 4 * 2 + 12

    // Non-reactive icons render plain (a disabled button would dim them).
    Item {
        id: iconSlot

        anchors.left: parent.left
        // 4px row inset, then the prototype's 24px icon column; the XS icon
        // button overflows the column symmetrically, keeping glyphs aligned.
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24

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
                // Below the button, like bar-tray tooltips (library default is above).
                y: parent.height + 4
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
        // 12px column gap; the track runs to the prototype's 4px row inset
        // unless a detail chevron takes over the row end.
        anchors.leftMargin: 12
        anchors.right: detailArrow.visible ? detailArrow.left : parent.right
        anchors.rightMargin: detailArrow.visible ? 0 : 4
        anchors.verticalCenter: parent.verticalCenter

        // Desktop-compact: 16dp XS track + short handle instead of the
        // default 44dp expressive slider.
        implicitHeight: 16
        mdState.handleHeight: 24

        // MD3 disabled-content opacity while muted.
        opacity: control.dimmed ? 0.38 : 1

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
            revealValue: wheelRevealTimer.running
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
        // Navigation into the output-device page, not a dropdown.
        icon.name: "chevron_right"

        onClicked: control.detailRequested()
    }

    // Prototype: hovering anywhere on the row adjusts the value with the
    // wheel/touchpad in 5% steps per notch. Topmost, button-less MouseArea:
    // wheel lands here first while presses/drags fall through to the slider
    // (the MouseArea.onWheel pattern is what the Bar's Workspaces widget
    // already proves out on the live compositor; WheelHandler does not
    // receive wheel events there).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        property real acc: 0

        onWheel: function (wheel) {
            const result = QSIcons.wheelNotches(acc, wheel.angleDelta.y, wheel.pixelDelta.y);
            acc = result.acc;
            if (result.steps !== 0) {
                // Wheel has no press/focus, so reveal the value indicator for a
                // beat after each notch (SliderHandle.revealValue).
                wheelRevealTimer.restart();
                const next = Math.max(0, Math.min(100, slider.value + result.steps * 5));
                if (next !== slider.value) {
                    control.moved(next / 100);
                }
            }
            wheel.accepted = true;
        }
    }

    Timer {
        id: wheelRevealTimer
        interval: 800
    }
}
