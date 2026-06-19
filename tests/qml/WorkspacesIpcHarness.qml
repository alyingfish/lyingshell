import QtQuick
import Quickshell
import Quickshell.Io
import Qcm.Material as MD
import qs.Modules.Bar.Widgets
import qs.Services.Niri

PanelWindow {
    id: root

    readonly property bool liveMode: String(Quickshell.env("LYINGSHELL_WORKSPACES_IPC_LIVE") || "") === "1"
    readonly property string ipcTarget: "workspaces-" + (screen && screen.name ? screen.name : "unknown")
    readonly property var workspaceModel: liveMode
        ? (screen && screen.name ? Niri.workspacesByOutput[screen.name] || [] : [])
        : fixtures.workspacesForScreen(screen)

    anchors {
        top: true
        left: true
    }

    implicitWidth: workspaces.implicitWidth
    implicitHeight: workspaces.implicitHeight
    exclusiveZone: 0
    color: MD.Token.color.surface_container

    WorkspaceFixtures {
        id: fixtures
    }

    Workspaces {
        id: workspaces

        workspaceModel: root.workspaceModel
        reducedMotion: fixtures.reducedMotion

        onFocusRequested: function(workspaceId) {
            root.focusWorkspace(workspaceId);
        }
    }

    IpcHandler {
        target: root.ipcTarget

        function workspaceIds(): string {
            return root.workspaceIdsText();
        }

        function activeWorkspaceId(): string {
            return root.activeWorkspaceId();
        }

        function focusedWorkspaceId(): string {
            return root.focusedWorkspaceId();
        }

        function wheelTarget(delta: real): string {
            return workspaces.workspaceIdForWheel(delta);
        }

        function wheel(delta: real): string {
            var workspaceId = workspaces.workspaceIdForWheel(delta);
            if (workspaceId.length > 0) {
                root.focusWorkspace(workspaceId);
            }
            return workspaceId;
        }

        function focus(workspaceId: string): bool {
            return root.focusWorkspace(workspaceId);
        }
    }

    function focusWorkspace(workspaceId) {
        if (liveMode) {
            return Niri.focusWorkspaceById(workspaceId);
        }

        return fixtures.focusWorkspace(workspaceId);
    }

    function workspaceIdsText() {
        var result = [];
        for (var index = 0; index < workspaceModel.length; index++) {
            result.push(String(workspaceModel[index].id));
        }
        return result.join(",");
    }

    function activeWorkspaceId() {
        for (var index = 0; index < workspaceModel.length; index++) {
            if (workspaceModel[index].active) {
                return String(workspaceModel[index].id);
            }
        }
        return "";
    }

    function focusedWorkspaceId() {
        for (var index = 0; index < workspaceModel.length; index++) {
            if (workspaceModel[index].focused) {
                return String(workspaceModel[index].id);
            }
        }
        return "";
    }
}
