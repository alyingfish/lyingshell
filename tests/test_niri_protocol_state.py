#!/usr/bin/env python3
"""Validate the Niri IPC protocol builders and reducer contract."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
NIRI_DIR = ROOT / "Services" / "Niri"
PROTOCOL_JS = NIRI_DIR / "NiriProtocol.js"
STATE_JS = NIRI_DIR / "NiriState.js"

NODE_SCRIPT = r"""
const fs = require("fs");
const vm = require("vm");

function loadSource(path) {
    return fs.readFileSync(path, "utf8")
        .split(/\r?\n/)
        .filter(line => !/^\s*\.(pragma|import)\b/.test(line))
        .join("\n");
}

function loadModule(path) {
    const context = {
        Array,
        Error,
        JSON,
        Number,
        Object,
        RegExp,
        String,
        console
    };
    vm.createContext(context);
    vm.runInContext(loadSource(path), context, { filename: path });
    return context;
}

const protocol = loadModule(process.argv[2]);
const state = loadModule(process.argv[3]);

function assert(condition, message) {
    if (!condition) {
        throw new Error(message);
    }
}

function same(actual, expected, message) {
    const actualText = JSON.stringify(actual);
    const expectedText = JSON.stringify(expected);
    if (actualText !== expectedText) {
        throw new Error(`${message}\nactual:   ${actualText}\nexpected: ${expectedText}`);
    }
}

same(protocol.eventStreamRequest(), "EventStream", "event stream request");
same(JSON.parse(protocol.encodeRequest(protocol.focusWorkspaceByIndexRequest(2))), {
    Action: { FocusWorkspace: { reference: { Index: 2 } } }
}, "focus workspace by index action");
same(JSON.parse(protocol.encodeRequest(protocol.focusWorkspaceByNameRequest("chat"))), {
    Action: { FocusWorkspace: { reference: { Name: "chat" } } }
}, "focus workspace by name action");
same(JSON.parse(protocol.encodeRequest(protocol.focusWindowRequest("42"))), {
    Action: { FocusWindow: { id: 42 } }
}, "focus window action");
same(JSON.parse(protocol.encodeRequest(protocol.toggleOverviewRequest())), {
    Action: { ToggleOverview: {} }
}, "toggle overview action");
same(JSON.parse(protocol.encodeRequest(protocol.setFocusedWorkspaceNameRequest("ops"))), {
    Action: { SetWorkspaceName: { name: "ops", workspace: null } }
}, "set focused workspace name action");

let reply = protocol.parseReplyLine('{"Ok":{"Outputs":{}}}');
assert(reply.ok && reply.payload.Outputs, "Ok reply parses");
reply = protocol.parseReplyLine('{"Err":"nope"}');
assert(!reply.ok && reply.error === "nope", "Err reply parses");
assert(!protocol.prepareRequest(false, "Outputs").ok, "disconnected request is rejected");

let current = state.initialState();
let reduced = state.applyEventLine(current, JSON.stringify({
    OutputsChanged: {
        outputs: {
            "HDMI-A-1": {
                name: "HDMI-A-1",
                make: "Test",
                model: "Wide",
                logical: { x: 1920, y: 0 },
                vrr_supported: true,
                vrr_enabled: false
            },
            "eDP-1": {
                name: "eDP-1",
                make: "Test",
                model: "Panel",
                logical: { x: 0, y: 0 },
                vrr_supported: false,
                vrr_enabled: false
            }
        }
    }
}));
assert(reduced.changed && reduced.error === "", "outputs event applies");
current = reduced.state;
same(current.outputs.map(output => output.name), ["eDP-1", "HDMI-A-1"], "outputs sort by logical position");

reduced = state.applyEventLine(current, JSON.stringify({
    WorkspacesChanged: {
        workspaces: [
            {
                id: 7,
                idx: 2,
                name: null,
                output: "eDP-1",
                is_urgent: false,
                is_active: false,
                is_focused: false,
                active_window_id: null
            },
            {
                id: 5,
                idx: 1,
                name: "chat",
                output: "eDP-1",
                is_urgent: false,
                is_active: true,
                is_focused: true,
                active_window_id: 42
            },
            {
                id: 9,
                idx: 1,
                name: null,
                output: "HDMI-A-1",
                is_urgent: false,
                is_active: true,
                is_focused: false,
                active_window_id: null
            }
        ]
    }
}));
assert(reduced.changed && reduced.error === "", "workspaces event applies");
current = reduced.state;
assert(current.focusedWorkspaceId === "5", "focused workspace id derives");
assert(current.focusedOutputName === "eDP-1", "focused output derives");
same(current.currentOutputWorkspaces.map(workspace => workspace.id), ["5", "7"], "current output workspaces derive");

reduced = state.applyEventLine(current, JSON.stringify({
    WindowsChanged: {
        windows: [
            { id: 42, title: "Terminal", app_id: "foot", workspace_id: 5, is_focused: true },
            { id: 43, title: "Browser", app_id: "firefox", workspace_id: 9, is_focused: false }
        ]
    }
}));
assert(reduced.changed && reduced.error === "", "windows event applies");
current = reduced.state;
assert(current.focusedWindowId === "42", "focused window derives");
assert(current.windowsById["43"].outputName === "HDMI-A-1", "window output derives through workspace");

reduced = state.applyEventLine(current, JSON.stringify({
    KeyboardLayoutsChanged: {
        keyboard_layouts: { names: ["us", "de"], current_idx: 1 }
    }
}));
current = reduced.state;
assert(current.currentKeyboardLayoutName === "de", "keyboard layout derives");

reduced = state.applyEventLine(current, JSON.stringify({ FutureEvent: { value: true } }));
assert(!reduced.changed && reduced.error === "", "unknown events are ignored");

same(state.workspaceReferenceForId(current, "5"), {
    ok: true,
    reference: { Name: "chat" },
    error: ""
}, "named workspace id resolves to name reference");
same(state.workspaceReferenceForId(current, "7"), {
    ok: true,
    reference: { Index: 2 },
    error: ""
}, "current-output workspace id resolves to index reference");
assert(!state.workspaceReferenceForId(current, "9").ok, "cross-output unnamed workspace id is deferred");

process.stdout.write(JSON.stringify({ ok: true }));
"""


def run_node() -> Any:
    result = subprocess.run(
        ["node", "-", str(PROTOCOL_JS), str(STATE_JS)],
        input=NODE_SCRIPT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        details = result.stderr.strip() or result.stdout.strip()
        raise AssertionError(details)

    return json.loads(result.stdout)


def main() -> None:
    assert PROTOCOL_JS.exists()
    assert STATE_JS.exists()
    assert run_node() == {"ok": True}


if __name__ == "__main__":
    main()
