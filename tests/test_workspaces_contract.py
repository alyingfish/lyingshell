#!/usr/bin/env python3
"""Validate the Workspaces widget and current Niri singleton boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "App" / "Shell.qml"
BAR = ROOT / "Modules" / "Bar" / "Bar.qml"
DATE_TIME = ROOT / "Modules" / "Bar" / "Widgets" / "DateTime.qml"
WORKSPACES = ROOT / "Modules" / "Bar" / "Widgets" / "Workspaces.qml"
WORKSPACE_DOT = ROOT / "Modules" / "Bar" / "Widgets" / "WorkspaceDot.qml"
NIRI_QML = ROOT / "Services" / "Niri" / "Niri.qml"
NIRI_PROTOCOL = ROOT / "Services" / "Niri" / "NiriProtocol.js"
NIRI_STATE = ROOT / "Services" / "Niri" / "NiriState.js"
OLD_NIRI = ROOT / "Services" / "Niri.qml"
REMOVED_IPC_TEST_FILES = [
    ROOT / "tests" / ("test_" + "workspaces_ipc.py"),
    ROOT / "tests" / "qml" / ("Workspaces" + "IpcShell.qml"),
    ROOT / "tests" / "qml" / ("Workspaces" + "IpcHarness.qml"),
    ROOT / "tests" / "qml" / ("Workspace" + "Fixtures.qml"),
]
WORKSPACES_POINTER_TEST = ROOT / "tests" / "qml" / "tst_workspaces_pointer.qml"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> None:
    app = read(APP)
    bar = read(BAR)
    date_time = read(DATE_TIME)
    workspaces = read(WORKSPACES)
    workspace_dot = read(WORKSPACE_DOT)
    niri_qml = read(NIRI_QML)
    niri_protocol = read(NIRI_PROTOCOL)
    niri_state = read(NIRI_STATE)
    workspaces_pointer_test = read(WORKSPACES_POINTER_TEST)
    product_qml = "\n".join(
        read(path)
        for path in ROOT.glob("**/*.qml")
        if "tests" not in path.relative_to(ROOT).parts
    )

    assert not OLD_NIRI.exists()
    assert all(not path.exists() for path in REMOVED_IPC_TEST_FILES)

    assert "root.ready ? Quickshell.screens : []" in app

    assert "import qs.Services.Niri" in bar
    assert "Niri.workspacesByOutput[root.screen.name]" in bar
    assert "Niri.focusWorkspaceById(workspaceId)" in bar
    assert "centerContentVisible" in bar
    # Edge inset keeps an 8px baseline but grows to clear the active shape's
    # rounded corners.
    assert "readonly property int edgeMargin: Math.max(8," in bar
    assert "readonly property int rowSpacing: 8" in bar

    assert "spacing: 12" in date_time
    assert "spacing: 4" in date_time
    assert "icon.size: 16" in date_time

    assert "function focusWorkspaceById(id: string): bool" in niri_qml
    assert "NiriProtocol.focusWorkspaceByIdRequest(id)" in niri_qml
    assert "function focusWorkspaceByIdRequest(id)" in niri_protocol
    assert "Id: requiredIntegerId(id, \"workspace id\")" in niri_protocol
    assert "workspaceReferenceForId" not in niri_state

    assert "required property var workspaceModel" in workspaces
    assert "signal focusRequested(string workspaceId)" in workspaces
    assert "ScriptModel {" in workspaces
    assert 'objectProp: "id"' in workspaces
    assert "values: root.renderedWorkspaceValues" in workspaces
    assert "ListModel {" not in workspaces
    assert "dynamicRoles" not in workspaces
    assert "renderedWorkspaces.insert" not in workspaces
    assert "renderedWorkspaces.move" not in workspaces
    assert "renderedWorkspaces.remove" not in workspaces
    assert "workspace.active === true" in workspaces
    assert '"active": workspace.active === true' in workspaces
    assert '"focused": workspace.focused === true' in workspaces
    assert '"urgent": workspace.urgent === true' in workspaces
    assert '"hasWindows": String(workspace.activeWindowId || "").length > 0' in workspaces
    assert "Niri." not in workspaces
    assert "Quickshell.env" not in workspaces

    assert "required property var workspace" in workspace_dot
    assert "property bool pulseEnabled: true" in workspace_dot
    assert "signal activated(string workspaceId)" in workspace_dot
    assert "workspace.active || workspace.focused" in workspace_dot
    assert "workspace.urgent && !isFocused" in workspace_dot
    assert "workspace.hasWindows && !isFocused && !isUrgent" in workspace_dot
    assert "urgentInitialized && isUrgent && !wasUrgent" in workspace_dot
    assert "readonly property int dotSize: 8" in workspace_dot
    assert "readonly property int activeWidth: 24" in workspace_dot
    assert "readonly property int hoverHaloExtension: 8" in workspace_dot
    assert "readonly property int pressedHaloExtension: 10" in workspace_dot
    assert "readonly property int morphDuration: 220" in workspace_dot
    assert "readonly property int pulseDuration: 600" in workspace_dot
    assert "loops: 2" in workspace_dot

    assert "readonly property int horizontalPadding: 8" in workspaces
    assert "readonly property int controlHeight: 24" in workspaces
    assert "readonly property int dotGap: 6" in workspaces
    assert "Settings.options.bar.workspaces.reverseScroll" in workspaces
    assert "Settings.options.bar.workspaces.scrollLoop" in workspaces
    assert "Settings.options.bar.workspaces.urgentPulse" in workspaces
    assert "Workspaces {" in workspaces_pointer_test
    assert "tester.mouseWheel(workspaces" in workspaces_pointer_test

    assert "Process" not in "\n".join([niri_qml, niri_protocol, niri_state])
    assert "niri msg" not in product_qml
    assert "Quickshell.Hyprland" not in product_qml
    assert "Quickshell.I3" not in product_qml
    assert "LYINGSHELL_" + "WORKSPACES_" not in product_qml
    assert "IpcHandler {" not in product_qml


if __name__ == "__main__":
    main()
