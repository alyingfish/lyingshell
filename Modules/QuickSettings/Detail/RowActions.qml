import QtQuick

// Action bar for an ExpandoRow body (prototype .wf-actions): danger/cancel
// actions in the left slot, confirming actions right of the gap.
Item {
    property alias leftData: leftRow.data
    property alias rightData: rightRow.data

    width: parent ? parent.width : 0
    implicitHeight: 36

    Row {
        id: leftRow

        anchors.left: parent.left
        height: parent.height
        spacing: 6
    }

    Row {
        id: rightRow

        anchors.right: parent.right
        height: parent.height
        spacing: 6
    }
}
