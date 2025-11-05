import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

Item {
    Text {
        anchors.centerIn: parent
        text: "Hello World"
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        text: `${NiriService.focusedWorkspace.id}/${NiriService.focusedWindow?.id}`
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        text: "Hello Right"
    }
}
