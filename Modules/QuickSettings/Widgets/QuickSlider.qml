import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Material

// Web-prototype expressive slider row: a 38px row of [32px leading icon
// button | thick-track slider | 32px trailing slot], 10px gaps. The track is
// 13px with a 10px inset gap around the 4x24 line handle (30px while
// dragged), a 4px stop dot at the track end, and a flat value pill above
// while dragging. Value is service-owned: bound in via `value` (0..1), user
// drags emit `moved` and the service loops the state back. The slider runs
// 0..100 internally so the value indicator reads as a percentage.
// `compact` (prototype `.slider.mix`) scales the row down for the sound
// mixer: 26px row, 10px track, 18px handle, inline percent instead of the
// value pill, and the icon/trailing slots become optional.
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
    // Compact variant (prototype `.slider.mix`, the sound mixer's in-row
    // slider): 26px row, 10px track, 18px handle, and no value indicator —
    // the mixer row shows a live inline percent instead.
    property bool compact: false
    // Mixer rows own their leading mute button (it spans the name line too)
    // and have no trailing slot, so both are optional.
    property bool hasIcon: true
    property bool hasTrailing: true

    signal moved(real newValue)
    signal iconClicked()
    signal detailRequested()

    // Prototype slider-row height (`.slider` 38px, 26px compact; the 32px
    // icon buttons center inside it).
    implicitHeight: compact ? 26 : 38
    implicitWidth: 32 + 10 + slider.implicitWidth + 10 + 32

    Item {
        id: iconSlot

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: control.hasIcon
        width: control.hasIcon ? 32 : 0
        height: 32

        // Reactive leading icon (mute / mic): the shared prototype `.ib`
        // morphing icon button.
        ReactiveIconButton {
            anchors.centerIn: parent
            visible: control.iconReactive
            iconName: control.iconName
            checked: control.iconChecked
            tooltipKey: control.iconTooltipKey
            onClicked: control.iconClicked()
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
        anchors.leftMargin: control.hasIcon ? 10 : 0
        anchors.right: trailingSlot.left
        anchors.rightMargin: control.hasTrailing ? 10 : 0
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: control.compact ? 26 : 38
        mdState.handleHeight: control.compact ? 18 : 24
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

        // Prototype expressive track: 13px tall (10px compact), active/
        // inactive split by a 10px gap each side of the handle center, outer
        // corner 8 / inner 2 (7 compact), and a 4px primary stop dot 6px
        // (5px compact) from the track end.
        background: Item {
            id: track

            // Prototype `.mix` metrics vs the main-row ones.
            readonly property int thickness: control.compact ? 10 : 13
            readonly property int outerCorner: control.compact ? 7 : 8
            readonly property int dotMargin: control.compact ? 5 : 6

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
            implicitHeight: control.compact ? 26 : 38

            MD.Rectangle {
                x: 0
                y: (track.height - track.thickness) / 2
                width: Math.max(0, slider.handleCenter - 10)
                height: track.thickness
                corners: MD.Util.corners(track.outerCorner, 2, track.outerCorner, 2)
                color: track.activeColor
                visible: width > 0
            }

            MD.Rectangle {
                x: Math.min(track.width, slider.handleCenter + 10)
                y: (track.height - track.thickness) / 2
                width: Math.max(0, track.width - x)
                height: track.thickness
                corners: MD.Util.corners(2, track.outerCorner, 2, track.outerCorner)
                color: track.inactiveColor
                visible: width > 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: track.dotMargin
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
            // Compact mixer rows show a live inline percent instead.
            bubbleEnabled: !control.compact
        }

    }

    // A Binding object re-asserts service state even after user drags have
    // written slider.value directly.
    Binding {
        target: slider
        property: "value"
        value: control.value * 100
    }

    // Trailing 32px slot: the sound-detail button when a detail page
    // exists, otherwise the prototype's alignment spacer (`.sp40` audit fix:
    // both sliders' right edges align). Compact mixer rows drop it.
    Item {
        id: trailingSlot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: control.hasTrailing
        width: control.hasTrailing ? 32 : 0
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
    // wheel/touchpad. Scroll mirrors GNOME Shell's slider (js/ui/slider.js): a
    // mouse wheel steps in fixed 2% notches, a touchpad scrolls smoothly in
    // proportion to finger travel. Topmost, button-less MouseArea: wheel lands
    // here first while presses/drags fall through to the slider (the
    // MouseArea.onWheel pattern is what the Bar's Workspaces widget already
    // proves out on the live compositor; WheelHandler does not receive wheel
    // events there).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        // Wheel is dead while muted, matching the disabled slider.
        enabled: !control.dimmed
        onWheel: function(wheel) {
            // Device split like GNOME's FLAG_POINTER_EMULATED filter: touchpads
            // emit pixelDelta (Qt's continuous delta), a plain wheel does not.
            // Quickshell's WheelEvent doesn't expose the synthesized-event flag,
            // so pixelDelta presence is the closest test.
            // ponytail: a hi-res mouse wheel also sends pixelDelta and reads as
            // a touchpad; no source()/synthesized flag in WheelEvent to do better.
            // niri owns natural-scroll direction, so deltas are taken at face
            // value: up/left = increase, down/right = decrease.
            const stepPct = 2; // GNOME SLIDER_SCROLL_STEP (0.02)
            let deltaPct;
            if (wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0) {
                // Touchpad: continuous, horizontal axis (GNOME's slider reads
                // dx). ~3px per 1% preserves the previous touchpad sensitivity;
                // this is the feel knob.
                deltaPct = wheel.pixelDelta.x / 3;
            } else {
                // Mouse wheel: one 120-unit notch = one 2% step. Dominant axis
                // so a tilt wheel works too (GNOME's discrete branch is
                // axis-agnostic).
                const angle = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
                deltaPct = angle / 120 * stepPct;
            }
            if (deltaPct !== 0) {
                const next = Math.max(0, Math.min(100, slider.value + deltaPct));
                if (next !== slider.value) {
                    // Wheel has no press/focus, so reveal the value indicator
                    // for a beat after each change (SliderHandle.revealValue).
                    wheelRevealTimer.restart();
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
