import QtQuick
import Qcm.Material as MD
import qs.Commons.Theme

// Connection / device property list (prototype .wf-props): key/value rows,
// values emphasized and right-aligned with tabular numerals. Lives inside an
// ExpandoRow body; `onCurrent` follows the selected row's container colors.
Column {
    id: props

    // Array of [key, value] pairs.
    property var entries: []
    property bool onCurrent: false

    readonly property color keyColor: onCurrent ? MD.Util.transparent(MD.Token.color.on_secondary_container, 0.88) : MD.Token.color.on_surface_variant
    readonly property color valueColor: onCurrent ? MD.Token.color.on_secondary_container : MD.Token.color.on_surface

    width: parent ? parent.width : 0
    topPadding: 2
    spacing: 7

    Repeater {
        model: props.entries

        Item {
            id: propRow

            required property var modelData

            width: parent.width
            implicitHeight: keyText.implicitHeight

            MD.Text {
                id: keyText

                anchors.left: parent.left
                text: propRow.modelData[0]
                color: props.keyColor
                typescale: MD.Token.typescale.body_small
                font.family: Theme.textTypeface
            }

            MD.Text {
                anchors.right: parent.right
                anchors.left: keyText.right
                anchors.leftMargin: 12
                horizontalAlignment: Text.AlignRight
                text: propRow.modelData[1]
                color: props.valueColor
                typescale: MD.Token.typescale.body_small
                prominent: true
                font.family: Theme.textTypeface
                elide: Text.ElideMiddle
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }
        }
    }
}
