import QtQuick
import Qcm.Material as MD

// Desktop-compact MD3 slider handle. Upstream QmlMaterial SliderHandle
// hardcodes the 44dp expressive handle line; this wrapper sizes the line from
// `handleHeight` and takes caller-provided indicator text. Value indicator
// shows immediately while pressed/dragged (MD3 LABEL_FLOATING) or keyboard
// focused, and after a `hoverDelay` dwell hovering the handle itself (desktop
// tooltip feel). Drop it when upstream honors handleHeight + label text.
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

    // The value indicator (bubble); constants mirror upstream SliderHandle.
    MD.Control {
        y: root.horizontal ? -height - 4 : (parent.height - height) / 2
        x: root.horizontal ? (parent.width - width) / 2 : -width - 4

        visible: root.handlePressed || root.handleHasFocus || root._hoverRevealed || root.revealValue
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: MD.Token.duration.short2
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: MD.Token.duration.short2
                easing: MD.Token.easing.standard
            }
        }

        contentItem: Item {
            implicitHeight: children[0].implicitHeight
            implicitWidth: children[0].implicitWidth
            MD.Text {
                anchors.centerIn: parent
                text: root.text
                typescale: MD.Token.typescale.label_medium
                color: root.control ? root.control.mdState.ctx.color.inverse_on_surface : "transparent"
            }
        }
        background: MD.ElevationRectangle {
            implicitWidth: 32
            implicitHeight: 32
            radius: 16
            color: root.control ? root.control.mdState.ctx.color.inverse_surface : "transparent"
            elevation: MD.Token.elevation.level2
        }
    }

    // The line handle, sized from handleHeight instead of upstream's 44.
    Rectangle {
        anchors.centerIn: parent

        width: root.horizontal ? root.handleLineWidth : root.handleHeight
        height: root.horizontal ? root.handleHeight : root.handleLineWidth

        radius: 2
        color: root.control ? root.control.mdState.backgroundColor : "transparent"
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
