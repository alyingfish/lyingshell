import Quickshell
import Quickshell.Io
import QtQuick

Item {
    Text {
        anchors.centerIn: parent
        text: "Hello World"
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        text: "Hello Left"
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        text: "Hello Right"
    }
}
