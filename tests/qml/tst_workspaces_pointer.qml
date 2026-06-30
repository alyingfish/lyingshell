import QtQuick
import QtQuick.Window
import QtTest
import "../../Modules/Bar/Widgets"

Window {
    id: root

    visible: true
    width: 120
    height: 80

    property string requestedWorkspaceId: ""
    property int requestCount: 0
    readonly property var workspaceModel: [
        {
            "id": "1",
            "index": 1,
            "outputName": "test-output",
            "name": "",
            "active": false,
            "focused": false,
            "urgent": false,
            "activeWindowId": "10"
        },
        {
            "id": "2",
            "index": 2,
            "outputName": "test-output",
            "name": "",
            "active": true,
            "focused": true,
            "urgent": false,
            "activeWindowId": "20"
        },
        {
            "id": "3",
            "index": 3,
            "outputName": "test-output",
            "name": "",
            "active": false,
            "focused": false,
            "urgent": false,
            "activeWindowId": ""
        }
    ]

    Workspaces {
        id: workspaces

        x: 20
        y: 24
        workspaceModel: root.workspaceModel

        onFocusRequested: function(workspaceId) {
            root.requestedWorkspaceId = workspaceId;
            root.requestCount += 1;
        }
    }

    TestCase {
        id: tester

        name: "WorkspacesPointer"
    }

    Timer {
        interval: 100
        running: true
        repeat: false

        onTriggered: {
            try {
                root.requestCount = 0;
                tester.mouseWheel(workspaces, workspaces.width / 2, workspaces.height / 2, 0, -120);
                root.verifyEqual(root.requestedWorkspaceId, "3", "wheel down over active dot should request next workspace");
                root.verifyEqual(root.requestCount, 1, "wheel down should emit one focus request");

                root.requestedWorkspaceId = "";
                root.requestCount = 0;
                tester.mouseWheel(workspaces, 2, workspaces.height / 2, 0, 120);
                root.verifyEqual(root.requestedWorkspaceId, "1", "wheel up over pill padding should request previous workspace");
                root.verifyEqual(root.requestCount, 1, "wheel up should emit one focus request");

                Qt.exit(0);
            } catch (error) {
                console.log("WorkspacesPointer: failed: " + error);
                Qt.exit(1);
            }
        }
    }

    function verifyEqual(actual, expected, message) {
        if (actual !== expected) {
            throw new Error(message + ": expected " + expected + ", got " + actual);
        }
    }
}
