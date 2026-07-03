import QtQuick
import QtQuick.Window
import QtTest
import "../../Modules/Bar/Widgets"

Window {
    id: root

    visible: true
    width: 120
    height: 120

    property int activatedCount: 0
    property int secondaryCount: 0
    property int menuCount: 0
    property real wheelDelta: 0
    property int dragStartCount: 0
    property int dragEndCount: 0
    property real lastDragX: -1
    property real lastDragY: -1

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    TrayItemButton {
        id: button

        x: 40
        y: 40
        trayItemId: "test-item"

        onActivated: root.activatedCount++
        onSecondaryActivated: root.secondaryCount++
        onMenuRequested: root.menuCount++
        onScrolled: function (delta) {
            root.wheelDelta = delta;
        }
        onDragStarted: root.dragStartCount++
        onDragFinished: root.dragEndCount++
        onDragMoved: function (dragX, dragY) {
            root.lastDragX = dragX;
            root.lastDragY = dragY;
        }
    }

    TestCase {
        id: tester

        name: "TrayItemPointer"
    }

    Timer {
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            try {
                const cx = button.width / 2;
                const cy = button.height / 2;

                // Left click activates, no drag.
                tester.mouseClick(button, cx, cy, Qt.LeftButton);
                tester.wait(20);
                root.verify(root.activatedCount === 1, "left click should activate");
                root.verify(root.dragStartCount === 0, "plain click should not start a drag");

                // Right click requests the context menu, does not activate.
                tester.mouseClick(button, cx, cy, Qt.RightButton);
                tester.wait(20);
                root.verify(root.menuCount === 1, "right click should request menu");
                root.verify(root.activatedCount === 1, "right click should not activate");

                // Middle click triggers the secondary action.
                tester.mouseClick(button, cx, cy, Qt.MiddleButton);
                tester.wait(20);
                root.verify(root.secondaryCount === 1, "middle click should secondary-activate");

                // Wheel forwards the vertical delta.
                tester.mouseWheel(button, cx, cy, 0, -120);
                tester.wait(20);
                root.verify(root.wheelDelta === -120, "wheel should forward angle delta");

                // Drag: press, move past the threshold, release.
                tester.mousePress(button, cx, cy, Qt.LeftButton);
                for (let step = 1; step <= 6; step++) {
                    tester.mouseMove(button, cx + step * 6, cy + step * 2);
                    tester.wait(10);
                }
                root.verify(root.dragStartCount === 1, "drag past threshold should start");
                root.verify(root.lastDragX > cx, "drag should report moved x in item coords");
                tester.mouseRelease(button, cx + 36, cy + 12, Qt.LeftButton);
                tester.wait(20);
                root.verify(root.dragEndCount === 1, "release should finish drag");
                root.verify(root.activatedCount === 1, "drag should not fire a click");

                // Ghosted mode only dims content, still present for layout.
                button.ghosted = true;
                tester.wait(250);
                root.verify(button.contentItem.opacity < 0.5, "ghosted button should dim its content");
                root.verify(button.visible, "ghosted button should keep its slot");

                console.log("tst_tray_item_pointer: all assertions passed");
                Qt.exit(0);
            } catch (error) {
                console.log("tst_tray_item_pointer: failed: " + error);
                Qt.exit(1);
            }
        }
    }
}
