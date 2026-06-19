import QtQuick
import QtQuick.Window
import QtTest
import "../../Modules/Bar/Widgets"

Window {
    id: root

    visible: true
    width: 80
    height: 80

    property string activatedWorkspaceId: ""
    property real requestedWheelDelta: 0
    readonly property var inactiveWorkspace: ({
        "id": "42",
        "index": 1,
        "outputName": "test-output",
        "name": "",
        "active": false,
        "focused": false,
        "urgent": false,
        "hasWindows": true
    })
    readonly property var focusedWorkspace: ({
        "id": "42",
        "index": 1,
        "outputName": "test-output",
        "name": "",
        "active": true,
        "focused": true,
        "urgent": false,
        "hasWindows": true
    })

    WorkspaceDot {
        id: dot

        x: 24
        y: 24
        workspace: root.inactiveWorkspace
        pulseEnabled: false
        reducedMotion: true

        onActivated: function(workspaceId) {
            root.activatedWorkspaceId = workspaceId;
        }

        onWheelRequested: function(delta) {
            root.requestedWheelDelta = delta;
        }
    }

    TestCase {
        id: tester

        name: "WorkspaceDotPointer"
    }

    Timer {
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            try {
                root.activatedWorkspaceId = "";
                tester.mousePress(dot, dot.width / 2, dot.height / 2, Qt.LeftButton);
                tester.wait(20);
                root.verify(dot.pressed, "mouse press should set pressed state");
                tester.mouseRelease(dot, dot.width / 2, dot.height / 2, Qt.LeftButton);
                root.verifyEqual(root.activatedWorkspaceId, "42", "click should emit activated workspace id");
                root.verify(!dot.pressed, "mouse release should clear pressed state");

                root.requestedWheelDelta = 0;
                tester.mouseWheel(dot, dot.width / 2, dot.height / 2, 0, -120);
                root.verifyEqual(root.requestedWheelDelta, -120, "wheel should emit requested delta");

                dot.workspace = root.inactiveWorkspace;
                tester.mouseMove(dot, dot.width / 2, dot.height / 2);
                tester.wait(180);
                root.verify(dot.hovered, "mouse move should hover dot");

                var halo = dot.children[0];
                var body = dot.children[2];
                root.verifyClose(halo.width, body.width + dot.haloExtension, 0.5,
                    "settled hover halo should match dot width plus extension");

                dot.workspace = root.focusedWorkspace;
                tester.wait(50);
                root.verify(dot.width > dot.dotSize && dot.width < dot.activeWidth,
                    "focused dot should be mid width morph");
                root.verifyClose(halo.width, body.width + dot.haloExtension, 0.75,
                    "hover halo should track dot width during morph");

                Qt.exit(0);
            } catch (error) {
                console.log("WorkspaceDotPointer: failed: " + error);
                Qt.exit(1);
            }
        }
    }

    function verifyEqual(actual, expected, message) {
        if (actual !== expected) {
            throw new Error(message + ": expected " + expected + ", got " + actual);
        }
    }

    function verify(condition, message) {
        if (!condition) {
            throw new Error(message);
        }
    }

    function verifyClose(actual, expected, tolerance, message) {
        if (Math.abs(actual - expected) > tolerance) {
            throw new Error(message + ": expected " + expected + " +/- " + tolerance + ", got " + actual);
        }
    }
}
