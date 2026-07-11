import QtQuick
import Qcm.Material as MD
import qs.Commons.Theme

// M3 row-action button (prototype .btn): 36px filled or text variant; the
// destructive text actions (Forget / Remove) read error red.
MD.Button {
    property bool filled: true
    property bool danger: false

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    implicitHeight: 36
    mdState.size: MD.Enum.XS
    mdState.type: filled ? MD.Enum.BtFilled : MD.Enum.BtText
    mdState.textColor: danger ? MD.Token.color.error : filled ? mdState.ctx.color.on_primary : mdState.ctx.color.primary
    font.family: Theme.textTypeface
}
