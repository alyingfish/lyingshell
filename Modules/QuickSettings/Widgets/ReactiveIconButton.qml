import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Material

// Prototype `.ib` reactive icon button (mute / mic): a standard 32px icon
// button that fills primary and squares its corner 16 -> 11 while `checked`,
// like the prototype `.ib.on` morph. Shared by the slider rows and the sound
// mixer; display state is caller-owned (`checked` is bound in, clicks only
// emit).
MD.IconButton {
    id: control

    property string iconName: ""
    // I18n token for the hover tooltip ("" = no tooltip).
    property string tooltipKey: ""

    // Selection colors cross-fade on the effects spring; `checked` is
    // outside StateButton's state machine so the library never animates
    // these on its own.
    property color animBackground: checked ? mdState.ctx.color.primary : MD.Util.transparent(mdState.ctx.color.primary, 0)
    property color animText: checked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface_variant
    // Checked morph 16 -> 11 (prototype `.ib.on` border-radius); step the
    // target — the internal Behavior renders the change.
    readonly property real stateCorner: checked && !down ? 11 : mdState.corner

    mdState.type: MD.Enum.IBtStandard
    mdState.size: MD.Enum.XS
    icon.name: control.iconName
    // Prototype `.ib svg` glyph size.
    icon.width: 18
    icon.height: 18
    mdState.backgroundColor: animBackground
    mdState.textColor: animText
    mdState.corners: MD.Util.corners(stateCorner)
    // Prototype `.ib:active{transform:scale(.88)}`.
    scale: down ? 0.88 : 1

    MD.ToolTip {
        // Below the button, like bar-tray tooltips (library default is above).
        y: parent.height + 4
        text: control.tooltipKey.length > 0 ? I18n.t(control.tooltipKey) : ""
        visible: control.hovered && text.length > 0
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
