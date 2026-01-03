pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common

RowLayout {
    id: root
    spacing: Config.options.bar.systemTray.spacing

    property int iconSize: Config.options.bar.systemTray.iconSize
    property int buttonSize: Config.options.bar.systemTray.buttonSize
    property int radius: Config.options.bar.systemTray.buttonRadius
    property color hoverColor: Theme.colors.bar.systemTray.hoverColor
    property color pressedColor: Theme.colors.bar.systemTray.pressedColor

    property bool hidePassive: Config.options.bar.systemTray.hidePassive

    LazyLoader {
        id: sharedMenuLoader // Using by all tray items

        TrayMenuWindow {
            id: menuInstance
        }
    }

    Repeater {
        model: SystemTray.items.values // Use .values to get the list

        delegate: Item {
            id: trayDelegate
            required property var modelData
            readonly property alias item: trayDelegate.modelData
            property bool isPassive: item && item.status === Status.Passive

            Layout.preferredWidth: visible ? root.buttonSize : 0
            Layout.preferredHeight: visible ? root.buttonSize : 0
            visible: item && (!root.hidePassive || !isPassive)

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                // Set hoverColor if this specific item is the one with the open menu
                color: mouseArea.pressed ? root.pressedColor : (mouseArea.containsMouse || (sharedMenuLoader.active && sharedMenuLoader.item.currentId === item.id)) ? root.hoverColor : "transparent"

                IconImage {
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    source: trayDelegate.item.icon || ""
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            trayDelegate.item.activate();
                        } else if (mouse.button === Qt.RightButton) {
                            // 1. Activate the loader
                            sharedMenuLoader.active = true;
                            // 2. Open the menu (accessing .item which is the TrayMenuWindow)
                            sharedMenuLoader.item.open(trayDelegate, item);
                        } else if (mouse.button === Qt.MiddleButton) {
                            trayDelegate.item.secondaryActivate();
                        }
                    }
                }
            }

            // Custom Tooltip
            TooltipWindow {
                target: trayDelegate
                text: trayDelegate.item.tooltipTitle || trayDelegate.item.id || ""
                // Hide tooltip if the menu for THIS item is open
                visible: mouseArea.containsMouse && (!sharedMenuLoader.active || sharedMenuLoader.item.currentId !== trayDelegate.item.id)
            }
        }
    }
}
