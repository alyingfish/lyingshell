import QtQuick
import qs.services
import qs.widgets

Item {

    ClockWidget {
        anchors.centerIn: parent
    }

    WorkspaceWidget {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        text: "Hello Right"
    }
}
