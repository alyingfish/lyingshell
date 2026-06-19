import QtQml
import Quickshell

QtObject {
    id: root

    readonly property bool reducedMotion: String(Quickshell.env("LYINGSHELL_WORKSPACES_TEST_REDUCED_MOTION") || "") === "1"
    readonly property string scenario: String(Quickshell.env("LYINGSHELL_WORKSPACES_TEST_SCENARIO") || "default")

    property int revision: 0
    property string focusedOutputName: ""
    property string focusedWorkspaceId: ""
    property var activeByOutput: ({})

    function workspacesForScreen(screen) {
        var outputName = screen !== null && screen !== undefined && screen.name !== undefined
            ? String(screen.name)
            : "test-output";
        var unusedRevision = revision;
        var outputIndex = outputIndexForName(outputName);
        var baseId = (outputIndex + 1) * 100;
        var focusedOutput = effectiveFocusedOutputName(outputName);
        var activeIndex = activeByOutput[outputName] === undefined
            ? defaultActiveIndex(outputIndex)
            : activeByOutput[outputName];

        return [
            workspace(baseId + 1, 1, outputName, activeIndex, focusedOutput, false, false),
            workspace(baseId + 2, 2, outputName, activeIndex, focusedOutput, false, true),
            workspace(baseId + 3, 3, outputName, activeIndex, focusedOutput, false, true),
            workspace(baseId + 4, 4, outputName, activeIndex, focusedOutput, true, true),
            workspace(baseId + 5, 5, outputName, activeIndex, focusedOutput, false, true)
        ];
    }

    function focusWorkspace(workspaceId) {
        var outputName = outputNameForWorkspaceId(workspaceId);
        var workspaceIndex = Number(workspaceId) % 100;
        if (outputName.length === 0 || workspaceIndex < 1 || workspaceIndex > 5) {
            return false;
        }

        var nextActiveByOutput = ({});
        for (var output in activeByOutput) {
            nextActiveByOutput[output] = activeByOutput[output];
        }
        nextActiveByOutput[outputName] = workspaceIndex;
        activeByOutput = nextActiveByOutput;
        focusedOutputName = outputName;
        focusedWorkspaceId = String(workspaceId);
        revision += 1;
        return true;
    }

    function defaultActiveIndex(outputIndex) {
        if (scenario === "active-not-focused" || scenario === "unfocused-output") {
            return 3;
        }
        if (scenario === "multi-output" && outputIndex > 0) {
            return 3;
        }
        return 2;
    }

    function outputIndexForName(outputName) {
        var screens = Quickshell.screens;
        if (screens !== undefined && screens.length !== undefined) {
            for (var index = 0; index < screens.length; index++) {
                if (screens[index] && screens[index].name === outputName) {
                    return index;
                }
            }
        }

        return 0;
    }

    function outputNameForWorkspaceId(workspaceId) {
        var outputIndex = Math.floor(Number(workspaceId) / 100) - 1;
        var screens = Quickshell.screens;
        if (screens !== undefined && screens.length !== undefined
                && outputIndex >= 0 && outputIndex < screens.length
                && screens[outputIndex] && screens[outputIndex].name !== undefined) {
            return String(screens[outputIndex].name);
        }

        return outputIndex === 0 ? "test-output" : "";
    }

    function effectiveFocusedOutputName(fallbackOutputName) {
        if (scenario === "active-not-focused" || scenario === "unfocused-output") {
            return "__test_other_output__";
        }
        if (focusedOutputName.length > 0) {
            return focusedOutputName;
        }
        return fallbackOutputName;
    }

    function workspace(id, index, outputName, activeIndex, focusedOutput, urgent, hasWindows) {
        var active = index === activeIndex;
        var focused = active && outputName === focusedOutput;
        return {
            "id": String(id),
            "index": index,
            "outputName": outputName,
            "name": "",
            "active": active,
            "focused": focused,
            "urgent": urgent && !focused,
            "activeWindowId": hasWindows ? String(id * 10) : ""
        };
    }
}
