import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Material
import "../../../Material/Wheel.js" as Wheel

// Web-prototype expressive slider row: a 38px row of [32px leading icon
// button | thick-track slider | 32px trailing slot], 10px gaps. The track is
// 13px with a 10px inset gap around the 4x24 line handle (30px while
// dragged), a 4px stop dot at the track end, and a flat value pill above
// while dragging. Value is service-owned: bound in via `value` (0..1), user
// drags emit `moved` and the service loops the state back. The slider runs
// 0..100 internally so the value indicator reads as a percentage.
Item {
    id: control

    required property string iconName
    property real value: 0
    property bool iconReactive: false
    property bool iconChecked: false
    // I18n token for the leading icon-button hover tooltip.
    property string iconTooltipKey: ""
    // I18n token for the trailing detail-button hover tooltip.
    property string detailTooltipKey: ""
    property bool hasDetail: false
    // Muted: prototype `.srow.muted` — the whole slider fades to 45%, its
    // active track/handle/dot turn outline, and it stops taking input; the
    // leading icon button stays live as the unmute affordance.
    property bool dimmed: false

    signal moved(real newValue)
    signal iconClicked()
    signal detailRequested()

    // Prototype slider-row height (`.slider` 38px; the 32px icon buttons
    // center inside it).
    implicitHeight: 38
    implicitWidth: 32 + 10 + slider.implicitWidth + 10 + 32

    Item {
        id: iconSlot

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32

        // Reactive leading icon (mute / mic): a standard 32px icon button
        // that fills primary and squares 16 -> 11 while checked, like the
        // prototype `.ib.on` morph.
        MD.IconButton {
            id: iconButton

            // Selection colors cross-fade on the effects spring; `checked`
            // is outside StateButton's state machine so the library never
            // animates these on its own.
            property color animBackground: control.iconChecked ? mdState.ctx.color.primary : MD.Util.transparent(mdState.ctx.color.primary, 0)
            property color animText: control.iconChecked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface_variant
            // Checked morph 16 -> 11 (prototype `.ib.on` border-radius);
            // step the target — the internal Behavior renders the change.
            readonly property real stateCorner: control.iconChecked && !down ? 11 : mdState.corner

            anchors.centerIn: parent
            visible: control.iconReactive
            mdState.type: MD.Enum.IBtStandard
            mdState.size: MD.Enum.XS
            icon.name: control.iconName
            // Prototype `.ib svg` glyph size.
            icon.width: 18
            icon.height: 18
            checked: control.iconChecked
            mdState.backgroundColor: animBackground
            mdState.textColor: animText
            mdState.corners: MD.Util.corners(stateCorner)
            // Prototype `.ib:active{transform:scale(.88)}`.
            scale: down ? 0.88 : 1
            onClicked: control.iconClicked()

            MD.ToolTip {
                // Below the button, like bar-tray tooltips (library default is above).
                y: parent.height + 4
                text: control.iconTooltipKey.length > 0 ? I18n.t(control.iconTooltipKey) : ""
                visible: iconButton.hovered && text.length > 0
            }

            Behavior on animBackground {
                MotionColorAnimation {
                }

            }

            Behavior on animText {
                MotionColorAnimation {
                }

            }

            Behavior on scale {
                MotionAnimation {
                }

            }

        }

        // Non-reactive leading icon (brightness): the prototype renders a
        // plain 32px `.ib` box that is not a button.
        MD.Icon {
            anchors.centerIn: parent
            visible: !control.iconReactive
            name: control.iconName
            size: 18
            color: MD.MProp.color.on_surface_variant
        }

    }

    MD.Slider {
        id: slider

        anchors.left: iconSlot.right
        anchors.leftMargin: 10
        anchors.right: trailingSlot.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 38
        mdState.handleHeight: 24
        // Prototype `.sh` keeps a constant 4px width and only grows in height
        // while dragging; pin the line so MD3's pressed 4->2 narrowing (which
        // thinned the handle mid-drag) doesn't fire.
        mdState.handleLineWidth: 4
        // Muted rows keep rendering (the prototype greys them, it does not
        // use the MD3 disabled treatment) but take no track/wheel input.
        enabled: !control.dimmed
        opacity: control.dimmed ? 0.45 : 1
        from: 0
        to: 100
        onMoved: control.moved(value / 100)

        // Prototype expressive track: 13px tall, active/inactive split by a
        // 10px gap each side of the handle center, outer corner 8 / inner 2,
        // and a 4px primary stop dot 6px from the track end.
        background: Item {
            id: track

            // Muted rows swap the primary group to outline (prototype
            // `.srow.muted` recolor).
            readonly property color activeColor: control.dimmed ? MD.Token.color.outline : MD.Token.color.primary
            // Prototype `--track-i` audit fix: primary 30% over
            // surface-container-low so the inactive track clears contrast.
            readonly property color inactiveColor: {
                const p = MD.Token.color.primary;
                const s = MD.Token.color.surface_container_low;
                return Qt.rgba(p.r * 0.3 + s.r * 0.7, p.g * 0.3 + s.g * 0.7, p.b * 0.3 + s.b * 0.7, 1);
            }

            implicitWidth: 200
            implicitHeight: 38

            MD.Rectangle {
                x: 0
                y: (track.height - 13) / 2
                width: Math.max(0, slider.handleCenter - 10)
                height: 13
                corners: MD.Util.corners(8, 2, 8, 2)
                color: track.activeColor
                visible: width > 0
            }

            MD.Rectangle {
                x: Math.min(track.width, slider.handleCenter + 10)
                y: (track.height - 13) / 2
                width: Math.max(0, track.width - x)
                height: 13
                corners: MD.Util.corners(2, 8, 2, 8)
                color: track.inactiveColor
                visible: width > 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    width: 4
                    height: 4
                    radius: 2
                    color: track.activeColor
                }

            }

        }

        // Prototype handle: 4x24 line growing to 30 while dragged, with the
        // flat value pill tucked 6px above the resting handle.
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
            // 6px above the handle's resting top edge (was 6px above the whole
            // 38px row, which floated the pill too far off the thin handle).
            bubbleGap: 6
        }

    }

    // A Binding object re-asserts service state even after user drags have
    // written slider.value directly.
    Binding {
        target: slider
        property: "value"
        value: control.value * 100
    }

    // Trailing 32px slot: the output-device button when a detail page
    // exists, otherwise the prototype's alignment spacer (`.sp40` audit fix:
    // both sliders' right edges align).
    Item {
        id: trailingSlot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32

        MD.IconButton {
            id: detailArrow

            anchors.centerIn: parent
            visible: control.hasDetail
            mdState.type: MD.Enum.IBtStandard
            mdState.size: MD.Enum.XS
            // Prototype `#btnOutput` mixer glyph, not a chevron.
            icon.name: "tune"
            icon.width: 18
            icon.height: 18
            scale: down ? 0.88 : 1
            // Hide the tooltip on click (pointer stays over the button as the
            // detail page opens); reset once the pointer leaves.
            onClicked: {
                tooltipSuppressed = true;
                control.detailRequested();
            }
            onHoveredChanged: if (!hovered)
                tooltipSuppressed = false

            property bool tooltipSuppressed: false

            MD.ToolTip {
                // Below the button, like bar-tray tooltips (library default is above).
                y: parent.height + 4
                text: control.detailTooltipKey.length > 0 ? I18n.t(control.detailTooltipKey) : ""
                visible: detailArrow.hovered && !detailArrow.tooltipSuppressed && text.length > 0
            }

            Behavior on scale {
                MotionAnimation {
                }

            }

        }

    }

    // Prototype: hovering anywhere on the row adjusts the value with the
    // wheel/touchpad in 5% steps per notch. Topmost, button-less MouseArea:
    // wheel lands here first while presses/drags fall through to the slider
    // (the MouseArea.onWheel pattern is what the Bar's Workspaces widget
    // already proves out on the live compositor; WheelHandler does not
    // receive wheel events there).
    MouseArea {
        property real acc: 0

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        // Wheel is dead while muted, matching the disabled slider.
        enabled: !control.dimmed
        onWheel: function(wheel) {
            // Touchpad left-right roll moves the slider too: take whichever axis
            // dominates. Base orientation is scroll-up / roll-right = increase;
            // Settings.quickSettings.sliders.reverseScroll (default false) flips
            // both axes to scroll-down / roll-right = increase.
            // wheel.inverted is set when the platform reports natural scrolling
            // (touchpad), so the same physical direction agrees with the mouse
            // wheel instead of moving the opposite way.
            const dir = Settings.options.quickSettings.sliders.reverseScroll ? -1 : 1;
            const invert = wheel.inverted ? -1 : 1;
            const angle = dir * invert * (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? -wheel.angleDelta.x : wheel.angleDelta.y);
            const pixel = dir * invert * (Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y) ? -wheel.pixelDelta.x : wheel.pixelDelta.y);
            const result = Wheel.wheelNotches(acc, angle, pixel);
            acc = result.acc;
            if (result.steps !== 0) {
                // Wheel has no press/focus, so reveal the value indicator for a
                // beat after each notch (SliderHandle.revealValue).
                wheelRevealTimer.restart();
                const next = Math.max(0, Math.min(100, slider.value + result.steps * 5));
                if (next !== slider.value)
                    control.moved(next / 100);

            }
            wheel.accepted = true;
        }
    }

    Timer {
        id: wheelRevealTimer

        interval: 800
    }

}
