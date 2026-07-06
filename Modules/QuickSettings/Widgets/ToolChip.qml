import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Material
import "../../../Material/Motion.js" as Motion

// Tools-row chip (prototype .tools-row .ib): a 40px tonal chip in an M3E
// round/square rhythm; hover morphs the shape only. The background is
// overridden so the corner spring bypasses MState's internal 100ms corner
// Behavior (which cannot render a hover spring).
MD.Button {
    id: chip

    // Alternate chips invert the round/square hover rhythm.
    property bool alt: false
    property string tooltipKey: ""

    readonly property real targetCorner: (alt ? chip.hovered : !chip.hovered) ? 20 : 12
    property real renderCorner: targetCorner

    Behavior on renderCorner {
        MotionAnimation {
            spring: Motion.spatialDefault
        }
    }

    implicitHeight: 40
    checkable: false
    flat: true
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    mdState.size: MD.Enum.XS
    mdState.type: MD.Enum.BtFilledTonal
    mdState.backgroundColor: mdState.ctx.color.surface_container_high
    mdState.textColor: mdState.ctx.color.on_surface_variant
    scale: down ? 0.88 : 1

    Behavior on scale {
        MotionAnimation {
            spring: Motion.spatialDefault
        }
    }

    contentItem: Item {
        implicitWidth: 18
        implicitHeight: 18
        opacity: chip.mdState.contentOpacity

        MD.Icon {
            anchors.centerIn: parent
            name: chip.icon.name
            size: 18
            color: chip.mdState.textColor
        }
    }

    background: MD.ElevationRectangle {
        implicitHeight: 40
        corners: MD.Util.corners(chip.renderCorner)
        color: chip.mdState.backgroundColor
        elevationVisible: false

        MD.Ripple {
            anchors.fill: parent
            corners: parent.corners
            pressX: chip.pressX
            pressY: chip.pressY
            pressed: chip.pressed
            stateOpacity: chip.mdState.stateLayerOpacity
            color: chip.mdState.stateLayerColor
        }

        MD.FocusIndicator {
            corners: parent.corners
            active: chip.visualFocus
        }
    }

    MD.ToolTip {
        y: parent.height + 4
        text: chip.tooltipKey.length > 0 ? I18n.t(chip.tooltipKey) : ""
        visible: chip.hovered && text.length > 0
    }
}
