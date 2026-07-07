import QtQuick
import Qcm.Material as MD
import "Motion.js" as Motion

// Desktop-compact MD3 slider handle. Upstream QmlMaterial SliderHandle
// hardcodes the 44dp expressive handle line; this wrapper sizes the line from
// `handleHeight` and takes caller-provided indicator text. Web-prototype
// styling: the line grows +6px while dragged (spatial spring) and the value
// indicator is a flat inverse-surface pill that pops in above the track
// (scale 0.6 + 4px drop -> rest on the spatial spring) while pressed/dragged,
// keyboard focused, wheel-adjusted, or after a `hoverDelay` dwell on the
// handle itself (desktop tooltip feel). Drop when upstream honors
// handleHeight + label text.
Item {
    id: root

    implicitWidth: horizontal ? handleWidth : handleHeight
    implicitHeight: horizontal ? handleHeight : handleWidth

    property real value: 0
    // Value-indicator text; callers format (e.g. percent).
    property string text: Math.round(root.value).toString()
    property bool handleHasFocus: false
    property bool handlePressed: false
    // Caller-driven reveal (e.g. wheel adjust has no press/focus/hover).
    property bool revealValue: false
    property int handleWidth: 12
    property int handleHeight: 24
    property bool horizontal: true
    property int handleLineWidth: 4
    // Dwell before hovering the handle reveals the indicator (ms).
    property int hoverDelay: 500
    // Distance from the handle's resting top edge up to the indicator's
    // bottom edge; QuickSlider passes 6px so the pill tucks above the handle.
    property real bubbleGap: 10

    readonly property var control: parent

    // Hover the handle itself (not the whole track); reveal after hoverDelay.
    property bool _hoverRevealed: false
    HoverHandler {
        id: handleHover
        onHoveredChanged: if (!hovered)
            root._hoverRevealed = false
    }
    Timer {
        interval: root.hoverDelay
        running: handleHover.hovered && !root._hoverRevealed
        onTriggered: root._hoverRevealed = true
    }

    // The value indicator: prototype `.sval` — a flat inverse-surface pill
    // 6px above the handle that pops from scale .6 / +4px (origin bottom).
    Rectangle {
        id: bubble

        readonly property bool shown: root.handlePressed || root.handleHasFocus || root._hoverRevealed || root.revealValue
        // Prototype clamp: the pill center stays >= 22px from either row
        // edge so it never overflows the panel at the extremes.
        readonly property real centerInControl: root.control ? Math.max(22, Math.min(root.control.width - 22, root.x + root.width / 2)) : root.width / 2

        x: centerInControl - root.x - width / 2
        y: -height - root.bubbleGap
        // Prototype padding 4px 9px around 12px/650 text.
        implicitWidth: bubbleText.implicitWidth + 18
        implicitHeight: bubbleText.implicitHeight + 8
        radius: MD.Token.shape.corner.medium
        color: root.control ? root.control.mdState.ctx.color.inverse_surface : "transparent"

        visible: opacity > 0.001
        opacity: shown ? 1 : 0
        transformOrigin: Item.Bottom
        scale: shown ? 1 : 0.6

        Behavior on opacity {
            MotionAnimation {
                spring: Motion.effectsFast
            }
        }
        Behavior on scale {
            MotionAnimation {}
        }

        MD.Text {
            id: bubbleText

            anchors.centerIn: parent
            text: root.text
            typescale: MD.Token.typescale.label_medium
            // Prototype indicator weight 650 = M3E emphasized type.
            prominent: true
            color: root.control ? root.control.mdState.ctx.color.inverse_on_surface : "transparent"
        }
    }

    // The line handle, sized from handleHeight instead of upstream's 44;
    // dragging stretches it +6px (prototype 24 -> 30) on the spatial spring.
    Rectangle {
        anchors.centerIn: parent

        readonly property real line: root.handleHeight + (root.handlePressed ? 6 : 0)

        width: root.horizontal ? root.handleLineWidth : line
        height: root.horizontal ? line : root.handleLineWidth

        Behavior on width {
            enabled: !root.horizontal
            MotionAnimation {}
        }
        Behavior on height {
            enabled: root.horizontal
            MotionAnimation {}
        }

        radius: 2
        color: root.control ? root.control.mdState.backgroundColor : "transparent"
        // Dim with the track group so a disabled/muted slider reads uniformly
        // (the track background applies the same backgroundOpacity).
        opacity: root.control ? root.control.mdState.backgroundOpacity : 1
    }

    // The "pill" outline shown on keyboard focus, mirrors upstream.
    Rectangle {
        anchors.centerIn: parent
        width: (root.horizontal ? root.handleLineWidth : root.handleHeight) + 12
        height: (root.horizontal ? root.handleHeight : root.handleLineWidth) + 12
        radius: (root.handleLineWidth + 12) / 2
        color: "transparent"
        border.color: root.control ? root.control.mdState.backgroundColor : "transparent"
        border.width: 4
        visible: root.handleHasFocus

        opacity: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: MD.Token.duration.short2
            }
        }
    }
}
