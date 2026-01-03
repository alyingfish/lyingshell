pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string requestSocketPath: Quickshell.env("NIRI_SOCKET")
    readonly property string eventSocketPath: Quickshell.env("NIRI_SOCKET")

    property var outputs: ({})
    property var workspaces: ([]) // workspace id as key
    property var focusedWorkspace: ({})
    property var windows: ([]) // window id as key
    property var focusedWindow: ({})
    property var keyboardLayouts: ({}) // {"names":["English (US)"],"current_idx":0}
    property bool isOverviewOpened
    property bool isConfigLoaded

    Socket {
        id: requestSocket

        path: root.requestSocketPath
        connected: true

        onConnectedChanged: {
            console.log(`RequestSocket: Connected Changed: ${connected}`);
        }

        onError: {
            console.log("RequestSocket: Connection error:", error);
        }
    }

    function send(data) {
        if (!requestSocket.connected) {
            console.error("requestSocket: Attempted to send data while disconnected.");
            return false;
        }
        const dataStr = typeof data === "string" ? data : JSON.stringify(data);
        const message = dataStr.endsWith("\n") ? dataStr : dataStr + "\n";
        requestSocket.write(message);
        requestSocket.flush();
        console.log(`requestSocket: Send message success: ${message}`);
        return true;
    }

    Socket {
        id: eventSocket

        path: root.eventSocketPath
        connected: true

        onConnectedChanged: {
            console.log(`eventSocket: Connected Changed: ${connected}`);
            if (connected) {
                eventSocket.write('"EventStream"\n');
                eventSocket.flush();
            }
        }

        onError: {
            console.log("eventSocket: Connection error:", error);
        }

        parser: SplitParser {
            onRead: line => {
                try {
                    // console.log(`eventSocket: SplitParser got line: ${line}`);
                    const event = JSON.parse(line);
                    root.handleNiriEvent(event);
                } catch (e) {
                    console.warn("eventSocket: SplitParser failed to parse event:", line, e);
                }
            }
        }
    }

    // --- Niri Event Handling ---

    /**
     * The main event router. It takes a parsed JSON event from Niri,
     * identifies its type, and calls the appropriate handler function.
     * @param {object} event - The parsed event object from Niri.
     */
    function handleNiriEvent(event) {
        // The event object is expected to have a single key, which is the event type.
        // e.g., { "WorkspacesChanged": { ...data... } }
        const eventType = Object.keys(event)[0];
        const eventData = event[eventType];

        switch (eventType) {
        case 'WorkspacesChanged':
            handleWorkspacesChanged(eventData);
            break;
        case 'WorkspaceActivated':
            handleWorkspaceActivated(eventData);
            break;
        case 'WorkspaceActiveWindowChanged':
            handleWorkspaceActiveWindowChanged(eventData);
            break;
        case 'WindowFocusChanged':
            handleWindowFocusChanged(eventData);
            break;
        case 'WindowsChanged':
            handleWindowsChanged(eventData);
            break;
        case 'WindowClosed':
            handleWindowClosed(eventData);
            break;
        case 'WindowOpenedOrChanged':
            handleWindowOpenedOrChanged(eventData);
            break;
        case 'WindowLayoutsChanged':
            handleWindowLayoutsChanged(eventData);
            break;
        case 'OutputsChanged':
            handleOutputsChanged(eventData);
            break;
        case 'OverviewOpenedOrClosed':
            handleOverviewChanged(eventData);
            break;
        case 'ConfigLoaded':
            handleConfigLoaded(eventData);
            break;
        case 'KeyboardLayoutsChanged':
            handleKeyboardLayoutsChanged(eventData);
            break;
        case 'KeyboardLayoutSwitched':
            handleKeyboardLayoutSwitched(eventData);
            break;
        case 'WorkspaceUrgencyChanged':
            handleWorkspaceUrgencyChanged(eventData);
            break;
        }
    }

    function handleWorkspacesChanged(eventData) {
        focusedWorkspace = eventData.workspaces.find(workspace => workspace.is_focused === true);
        workspaces = eventData.workspaces.reduce((acc, workspace) => {
            acc[workspace.id] = workspace;
            return acc;
        }, {});
    }

    function handleWorkspaceActivated(eventData) {
        focusedWorkspace.is_focused = false;
        focusedWorkspace = workspaces[eventData.id];
        focusedWorkspace.is_focused = true;
        workspacesChanged();
    }

    function handleWorkspaceActiveWindowChanged(eventData) {
        const workspace = workspaces[eventData.workspace_id];
        workspace.active_window_id = eventData.active_window_id;
        focusedWorkspaceChanged();
        workspacesChanged();
    }

    function handleWindowFocusChanged(eventData) {
        if (focusedWindow) {
            focusedWindow.is_focused = false;
        }
        if (eventData.id === null) {
            focusedWindow = null;
        } else {
            focusedWindow = windows[eventData.id];
            focusedWindow.is_focused = true;
        }
        windowsChanged();
    }

    function handleWindowsChanged(eventData) {
        focusedWindow = eventData.windows.find(window => window.is_focused === true);
        windows = eventData.windows.reduce((acc, window) => {
            acc[window.id] = window;
            return acc;
        }, {});
    }

    function handleWindowClosed(eventData) {
        delete windows[eventData.id];
    }

    function handleOutputsChanged(eventData) {
        outputs = eventData.outputs;
    }

    function handleWindowOpenedOrChanged(eventData) {
        windows[eventData.window.id] = eventData.window;
        windowsChanged();
        if (eventData.window.is_focused) {
            if (focusedWindow) {
                focusedWindow.is_focused = false;
            }
            focusedWindow = eventData.window;
        }
    }

    function handleWindowLayoutsChanged(eventData) {
        for (const [id, newLayout] of eventData.changes) {
            windows[id].layout = newLayout;
        }
        windowsChanged();
    }

    function handleOverviewChanged(eventData) {
        isOverviewOpened = eventData.is_open;
    }

    function handleConfigLoaded(eventData) {
        isConfigLoaded = !eventData.failed;
    }

    function handleKeyboardLayoutsChanged(eventData) {
        keyboardLayouts = eventData.keyboard_layouts;
    }

    function handleKeyboardLayoutSwitched(eventData) {
        keyboardLayouts.current_idx = eventData.idx;
        keyboardLayoutsChanged();
    }

    function handleWorkspaceUrgencyChanged(eventData) {
        const workspace = workspaces[eventData.id];
        workspace.is_urgent = eventData.urgent;
        workspacesChanged();
    }
}
