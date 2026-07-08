.pragma library

function initialState() {
    return derive({
        workspaces: [],
        focusedOutputName: "",
        windows: [],
        overviewOpen: false
    });
}

function applyEventLine(state, line) {
    var event = null;

    try {
        event = JSON.parse(line);
    } catch (error) {
        return result(state, false, "Invalid Niri event JSON: " + errorMessageText(error));
    }

    try {
        return applyEvent(state, event);
    } catch (error) {
        return result(state, false, "Invalid Niri event payload: " + errorMessageText(error));
    }
}

function applyEvent(state, event) {
    if (!event || typeof event !== "object" || Array.isArray(event)) {
        return result(state, false, "Invalid Niri event");
    }

    var keys = Object.keys(event);
    if (keys.length !== 1) {
        return result(state, false, "Invalid Niri event envelope");
    }

    var variant = keys[0];
    var payload = event[variant];

    switch (variant) {
    case "WorkspacesChanged":
        return applyWorkspacesChanged(state, payload);
    case "WorkspaceActivated":
        return applyWorkspaceActivated(state, payload);
    case "WorkspaceActiveWindowChanged":
        return applyWorkspaceActiveWindowChanged(state, payload);
    case "WorkspaceUrgencyChanged":
        return applyWorkspaceUrgencyChanged(state, payload);
    case "WindowsChanged":
        return applyWindowsChanged(state, payload);
    case "WindowOpenedOrChanged":
        return applyWindowOpenedOrChanged(state, payload);
    case "WindowClosed":
        return applyWindowClosed(state, payload);
    case "WindowLayoutsChanged":
        return applyWindowLayoutsChanged(state, payload);
    case "WindowUrgencyChanged":
        return applyWindowUrgencyChanged(state, payload);
    case "OverviewOpenedOrClosed":
        return applyOverview(state, payload);
    default:
        return result(state, false, "");
    }
}

function applyWorkspacesChanged(state, payload) {
    if (!payload || !Array.isArray(payload.workspaces)) {
        return result(state, false, "Invalid WorkspacesChanged event");
    }

    var next = copyState(state);
    next.workspaces = normalizeWorkspaceList(payload.workspaces);
    return result(derive(next), true, "");
}

function applyWorkspaceActivated(state, payload) {
    if (!payload || idText(payload.id).length === 0 || typeof payload.focused !== "boolean") {
        return result(state, false, "Invalid WorkspaceActivated event");
    }

    var idKey = idText(payload.id);
    var activated = state.workspacesById[idKey];
    if (!activated) {
        return result(state, false, "");
    }

    var next = copyState(state);
    var workspaces = [];
    for (var i = 0; i < next.workspaces.length; i += 1) {
        var workspace = Object.assign({}, next.workspaces[i]);
        if (workspace.outputName === activated.outputName) {
            workspace.active = workspace.id === idKey;
        }
        if (payload.focused) {
            workspace.focused = workspace.id === idKey;
        }
        workspaces.push(workspace);
    }
    next.workspaces = workspaces;
    return result(derive(next), true, "");
}

function applyWorkspaceActiveWindowChanged(state, payload) {
    if (!payload || idText(payload.workspace_id).length === 0) {
        return result(state, false, "Invalid WorkspaceActiveWindowChanged event");
    }

    var workspaceId = idText(payload.workspace_id);
    if (!state.workspacesById[workspaceId]) {
        return result(state, false, "");
    }

    var activeWindowId = idText(payload.active_window_id);
    var next = copyState(state);
    next.workspaces = mapReplace(next.workspaces, workspaceId, function(workspace) {
        workspace.activeWindowId = activeWindowId;
        return workspace;
    });
    return result(derive(next), true, "");
}

function applyWorkspaceUrgencyChanged(state, payload) {
    if (!payload || idText(payload.id).length === 0 || typeof payload.urgent !== "boolean") {
        return result(state, false, "Invalid WorkspaceUrgencyChanged event");
    }

    var idKey = idText(payload.id);
    if (!state.workspacesById[idKey]) {
        return result(state, false, "");
    }

    var next = copyState(state);
    next.workspaces = mapReplace(next.workspaces, idKey, function(workspace) {
        workspace.urgent = payload.urgent;
        return workspace;
    });
    return result(derive(next), true, "");
}

function applyWindowsChanged(state, payload) {
    if (!payload || !Array.isArray(payload.windows)) {
        return result(state, false, "Invalid WindowsChanged event");
    }

    var next = copyState(state);
    next.windows = normalizeWindowList(payload.windows, state.workspacesById);
    return result(derive(next), true, "");
}

function applyWindowOpenedOrChanged(state, payload) {
    if (!payload || !payload.window) {
        return result(state, false, "Invalid WindowOpenedOrChanged event");
    }

    var window = normalizeWindow(payload.window, state.workspacesById);
    var next = copyState(state);
    var found = false;
    var windows = [];
    for (var i = 0; i < next.windows.length; i += 1) {
        var current = next.windows[i];
        if (current.id === window.id) {
            windows.push(window);
            found = true;
        } else {
            windows.push(current);
        }
    }
    if (!found) {
        windows.push(window);
    }
    next.windows = windows;
    return result(derive(next), true, "");
}

function applyWindowClosed(state, payload) {
    if (!payload || idText(payload.id).length === 0) {
        return result(state, false, "Invalid WindowClosed event");
    }

    var idKey = idText(payload.id);
    var next = copyState(state);
    next.windows = next.windows.filter(function(window) {
        return window.id !== idKey;
    });
    return result(derive(next), true, "");
}

function applyWindowLayoutsChanged(state, payload) {
    if (!payload || !Array.isArray(payload.changes)) {
        return result(state, false, "Invalid WindowLayoutsChanged event");
    }

    var next = copyState(state);
    for (var i = 0; i < payload.changes.length; i += 1) {
        var change = payload.changes[i];
        if (!Array.isArray(change) || change.length < 2) {
            continue;
        }
        var idKey = idText(change[0]);
        next.windows = mapReplace(next.windows, idKey, function(window) {
            window.layout = change[1];
            return window;
        });
    }
    return result(derive(next), true, "");
}

function applyWindowUrgencyChanged(state, payload) {
    if (!payload || idText(payload.id).length === 0 || typeof payload.urgent !== "boolean") {
        return result(state, false, "Invalid WindowUrgencyChanged event");
    }

    var idKey = idText(payload.id);
    if (!state.windowsById[idKey]) {
        return result(state, false, "");
    }

    var next = copyState(state);
    next.windows = mapReplace(next.windows, idKey, function(window) {
        window.urgent = payload.urgent;
        return window;
    });
    return result(derive(next), true, "");
}

function applyOverview(state, payload) {
    if (!payload || typeof payload.is_open !== "boolean") {
        return result(state, false, "Invalid OverviewOpenedOrClosed event");
    }

    var next = copyState(state);
    next.overviewOpen = payload.is_open;
    return result(derive(next), true, "");
}

function derive(state) {
    var next = copyState(state);

    next.workspacesById = {};
    next.workspacesByOutput = {};
    var focusedWorkspace = null;
    for (var j = 0; j < next.workspaces.length; j += 1) {
        var workspace = next.workspaces[j];
        next.workspacesById[workspace.id] = workspace;
        var outputName = workspace.outputName;
        if (!next.workspacesByOutput[outputName]) {
            next.workspacesByOutput[outputName] = [];
        }
        next.workspacesByOutput[outputName].push(workspace);
        if (workspace.focused) {
            focusedWorkspace = workspace;
        }
    }

    var outputKeys = Object.keys(next.workspacesByOutput);
    for (var k = 0; k < outputKeys.length; k += 1) {
        next.workspacesByOutput[outputKeys[k]].sort(compareWorkspace);
    }

    next.focusedOutputName = focusedWorkspace ? focusedWorkspace.outputName : next.focusedOutputName;

    next.windowsById = {};
    for (var w = 0; w < next.windows.length; w += 1) {
        var windowItem = Object.assign({}, next.windows[w]);
        var owningWorkspace = next.workspacesById[windowItem.workspaceId];
        windowItem.outputName = owningWorkspace ? owningWorkspace.outputName : windowItem.outputName;
        next.windows[w] = windowItem;
        next.windowsById[windowItem.id] = windowItem;
    }

    // Active window (or null) on each output's active workspace. Same objects as
    // windowsById, so consumers (e.g. Bar autoShape) read window state without
    // re-walking workspacesByOutput + windowsById themselves.
    next.activeWindowByOutput = {};
    var outKeys = Object.keys(next.workspacesByOutput);
    for (var a = 0; a < outKeys.length; a += 1) {
        var wsList = next.workspacesByOutput[outKeys[a]];
        var win = null;
        for (var b = 0; b < wsList.length; b += 1) {
            if (wsList[b].active) {
                var wid = wsList[b].activeWindowId;
                win = wid ? (next.windowsById[wid] || null) : null;
                break;
            }
        }
        next.activeWindowByOutput[outKeys[a]] = win;
    }

    return next;
}

function normalizeWorkspaceList(workspaces) {
    return workspaces.map(normalizeWorkspace).sort(compareWorkspace);
}

function normalizeWorkspace(workspace) {
    var id = idText(workspace.id);
    if (id.length === 0) {
        throw new Error("workspace id is required");
    }

    return {
        id: id,
        index: safeInteger(workspace.idx, 0),
        name: optionalString(workspace.name),
        outputName: optionalString(workspace.output),
        urgent: workspace.is_urgent === true,
        active: workspace.is_active === true,
        focused: workspace.is_focused === true,
        activeWindowId: idText(workspace.active_window_id)
    };
}

function normalizeWindowList(windows, workspacesById) {
    return windows.map(function(window) {
        return normalizeWindow(window, workspacesById);
    });
}

function normalizeWindow(window, workspacesById) {
    var id = idText(window.id);
    if (id.length === 0) {
        throw new Error("window id is required");
    }

    var workspaceId = idText(window.workspace_id);
    var workspace = workspacesById[workspaceId];
    return {
        id: id,
        title: optionalString(window.title),
        appId: optionalString(window.app_id),
        workspaceId: workspaceId,
        outputName: workspace ? workspace.outputName : "",
        urgent: window.is_urgent === true,
        isFloating: window.is_floating === true,
        layout: window.layout || null
    };
}

function compareWorkspace(a, b) {
    var outputCompare = compareString(a.outputName, b.outputName);
    if (outputCompare !== 0) {
        return outputCompare;
    }
    if (a.index !== b.index) {
        return a.index - b.index;
    }
    return numericId(a.id) - numericId(b.id);
}

function mapReplace(items, id, replacer) {
    return items.map(function(item) {
        if (item.id !== id) {
            return item;
        }

        return replacer(Object.assign({}, item));
    });
}

function copyState(state) {
    return {
        workspaces: state.workspaces ? state.workspaces.slice() : [],
        focusedOutputName: optionalString(state.focusedOutputName),
        windows: state.windows ? state.windows.slice() : [],
        overviewOpen: state.overviewOpen === true
    };
}

function result(state, changed, error) {
    return {
        state: state,
        changed: changed,
        error: error
    };
}

function idText(value) {
    if (value === null || value === undefined) {
        return "";
    }

    if (typeof value === "number") {
        if (!Number.isSafeInteger(value) || value < 0) {
            return "";
        }
        return String(value);
    }

    if (typeof value === "string" && /^\d+$/.test(value)) {
        return value;
    }

    return "";
}

function numericId(value) {
    var parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 999999999;
}

function optionalString(value) {
    return value === null || value === undefined ? "" : String(value);
}

function safeInteger(value, fallback) {
    return Number.isSafeInteger(value) ? value : fallback;
}

function compareString(a, b) {
    return String(a).localeCompare(String(b));
}

function errorMessageText(error) {
    return error && error.message ? String(error.message) : String(error);
}
