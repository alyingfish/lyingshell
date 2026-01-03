pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

PopupWindow {
    id: root

    property var currentItem: null
    property string currentId: currentItem ? currentItem.id : ""

    function open(anchorItem, trayItem) {
        if (!trayItem || !trayItem.menu)
            return;

        root.currentItem = trayItem;

        root.anchor.item = anchorItem;
        root.anchor.edges = Edges.Bottom | Edges.Right;
        root.anchor.gravity = Edges.Bottom | Edges.Left;
        root.anchor.margins.top = 5;

        root.visible = true;
    }

    implicitWidth: 220
    implicitHeight: menuLayout.implicitHeight + 10

    color: "transparent"

    mask: Region {
        item: menuRect
    }

    onVisibleChanged: {
        if (!visible) {
            currentItem = null;
        }
    }

    HoverHandler {
        id: mouseTracker
    }

    Timer {
        id: closeTimer
        interval: 1000
        repeat: false
        // Timer runs ONLY when window is visible AND mouse is NOT inside the window.
        // This handles opening, moving between items, and leaving automatically.
        running: root.visible && !mouseTracker.hovered
        onTriggered: root.visible = false
    }

    Rectangle {
        id: menuRect
        anchors.fill: parent
        color: "#202020"
        border.color: "#303030"
        border.width: 1
        radius: 8
        clip: true

        QsMenuOpener {
            id: menuOpener
            menu: root.currentItem ? root.currentItem.menu : null
        }

        ColumnLayout {
            id: menuLayout
            width: parent.width
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: menuOpener.children

                delegate: Rectangle {
                    id: menuItemRect
                    required property var modelData
                    property var menuItem: modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: menuItem.isSeparator ? 1 : 36
                    Layout.topMargin: menuItem.isSeparator ? 4 : 0
                    Layout.bottomMargin: menuItem.isSeparator ? 4 : 0

                    // Highlight logic remains
                    color: menuItem.isSeparator ? "#303030" : (menuMouse.containsMouse ? "#1FFFFFFF" : "transparent")
                    visible: !menuItem.isSeparator || true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        visible: !menuItem.isSeparator
                        spacing: 12

                        IconImage {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: menuItem.icon || ""
                            visible: menuItem.icon !== "" && menuItem.buttonType === QsMenuButtonType.None
                        }

                        Rectangle {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            color: "transparent"
                            border.color: "#99FFFFFF"
                            radius: 2
                            visible: menuItem.buttonType === QsMenuButtonType.CheckBox

                            Rectangle {
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                color: "#3C96FF"
                                radius: 1
                                visible: menuItem.checkState === Qt.Checked
                            }
                        }

                        Text {
                            text: menuItem.text.replace("&", "")
                            color: "#E0E0E0"
                            font.pixelSize: 13
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: ">"
                            color: "#808080"
                            visible: menuItem.hasChildren
                        }
                    }

                    MouseArea {
                        id: menuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        enabled: !menuItem.isSeparator && menuItem.enabled

                        // Logic for timer removed from here to avoid conflicts

                        onClicked: {
                            if (menuItem.hasChildren) {
                                menuItem.display(root, 0, 0);
                            } else {
                                menuItem.triggered();
                                root.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
