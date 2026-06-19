#!/usr/bin/env python3
"""Validate the Workspaces widget and current Niri singleton boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "App" / "Shell.qml"
BAR = ROOT / "Modules" / "Bar" / "Bar.qml"
WORKSPACES = ROOT / "Modules" / "Bar" / "Widgets" / "Workspaces.qml"
WORKSPACE_DOT = ROOT / "Modules" / "Bar" / "Widgets" / "WorkspaceDot.qml"
NIRI_QML = ROOT / "Services" / "Niri" / "Niri.qml"
NIRI_PROTOCOL = ROOT / "Services" / "Niri" / "NiriProtocol.js"
NIRI_STATE = ROOT / "Services" / "Niri" / "NiriState.js"
OLD_NIRI = ROOT / "Services" / "Niri.qml"
WORKSPACE_FIXTURES = ROOT / "tests" / "qml" / "WorkspaceFixtures.qml"
WORKSPACES_IPC_HARNESS = ROOT / "tests" / "qml" / "WorkspacesIpcHarness.qml"
WORKSPACES_POINTER_TEST = ROOT / "tests" / "qml" / "tst_workspaces_pointer.qml"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> None:
    app = read(APP)
    bar = read(BAR)
    workspaces = read(WORKSPACES)
    workspace_dot = read(WORKSPACE_DOT)
    niri_qml = read(NIRI_QML)
    niri_protocol = read(NIRI_PROTOCOL)
    niri_state = read(NIRI_STATE)
    workspace_fixtures = read(WORKSPACE_FIXTURES)
    workspaces_ipc_harness = read(WORKSPACES_IPC_HARNESS)
    workspaces_pointer_test = read(WORKSPACES_POINTER_TEST)
    product_qml = "\n".join(
        read(path)
        for path in ROOT.glob("**/*.qml")
        if "tests" not in path.relative_to(ROOT).parts
    )

    assert not OLD_NIRI.exists()
    assert "root.ready ? Quickshell.screens : []" in app

    assert "import qs.Services.Niri" in bar
    assert "Niri.workspacesByOutput[root.screen.name]" in bar
    assert "Niri.focusWorkspaceById(workspaceId)" in bar
    assert "centerContentVisible" in bar

    assert "function focusWorkspaceById(id: string): bool" in niri_qml
    assert "NiriProtocol.focusWorkspaceByIdRequest(id)" in niri_qml
    assert "function focusWorkspaceByIdRequest(id)" in niri_protocol
    assert "Id: requiredIntegerId(id, \"workspace id\")" in niri_protocol
    assert "workspaceReferenceForId" not in niri_state

    assert "required property var workspaceModel" in workspaces
    assert "signal focusRequested(string workspaceId)" in workspaces
    assert "ListModel {" in workspaces
    assert "dynamicRoles: true" in workspaces
    assert "renderedWorkspaces.insert" in workspaces
    assert "renderedWorkspaces.move" in workspaces
    assert "renderedWorkspaces.remove" in workspaces
    assert "workspace.active === true" in workspaces
    assert '"active": workspace.active === true' in workspaces
    assert '"focused": workspace.focused === true' in workspaces
    assert '"urgent": workspace.urgent === true' in workspaces
    assert '"hasWindows": String(workspace.activeWindowId || "").length > 0' in workspaces
    assert "Niri." not in workspaces
    assert "Quickshell.env" not in workspaces

    assert "required property var workspace" in workspace_dot
    assert "signal activated(string workspaceId)" in workspace_dot
    assert "workspace.active || workspace.focused" in workspace_dot
    assert "workspace.urgent && !isFocused" in workspace_dot
    assert "workspace.hasWindows && !isFocused && !isUrgent" in workspace_dot
    assert "urgentInitialized && isUrgent && !wasUrgent" in workspace_dot
    assert "loops: 2" in workspace_dot

    assert "Settings.options.bar.workspaces.reverseScroll" in workspaces
    assert "Settings.options.bar.workspaces.scrollLoop" in workspaces
    assert "Settings.options.bar.workspaces.urgentPulse" in workspaces

    assert "IpcHandler {" in workspaces_ipc_harness
    assert "fixtures.workspacesForScreen(screen)" in workspaces_ipc_harness
    assert "Niri.workspacesByOutput[screen.name]" in workspaces_ipc_harness
    assert "Niri.focusWorkspaceById(workspaceId)" in workspaces_ipc_harness
    assert "function workspacesForScreen(screen)" in workspace_fixtures
    assert "function focusWorkspace(workspaceId)" in workspace_fixtures
    assert "Workspaces {" in workspaces_pointer_test
    assert "tester.mouseWheel(workspaces" in workspaces_pointer_test

    assert "Process" not in "\n".join([niri_qml, niri_protocol, niri_state])
    assert "niri msg" not in product_qml
    assert "Quickshell.Hyprland" not in product_qml
    assert "Quickshell.I3" not in product_qml
    assert "LYINGSHELL_WORKSPACES_" not in product_qml
    assert "IpcHandler {" not in product_qml


if __name__ == "__main__":
    main()
