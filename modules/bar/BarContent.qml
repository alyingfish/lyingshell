import QtQuick
import qs.services
import qs.modules.bar.widgets
import qs.modules.bar.widgets.systemTray

Item {
    WorkspaceWidget {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
    }

    ClockWidget {
        anchors.centerIn: parent
    }

    SystemTrayWidget {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
    }
}
