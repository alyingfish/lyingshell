.pragma library

function initialState() {
    return derive({
        outputs: [],
        outputsByName: {},
        workspaces: [],
        workspacesById: {},
        workspacesByOutput: {},
        focusedOutputName: "",
        focusedWorkspaceId: "",
        focusedWorkspace: null,
        currentOutputWorkspaces: [],
        windows: [],
        windowsById: {},
        focusedWindowId: "",
        focusedWindow: null,
        overviewOpen: false,
        keyboardLayoutNames: [],
        currentKeyboardLayoutIndex: -1,
        currentKeyboardLayoutName: ""
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
        return updateWorkspaceFlag(state, payload, "urgent");
    case "WindowsChanged":
        return applyWindowsChanged(state, payload);
    case "WindowOpenedOrChanged":
        return applyWindowOpenedOrChanged(state, payload);
    case "WindowClosed":
        return applyWindowClosed(state, payload);
    case "WindowFocusChanged":
        return applyWindowFocusChanged(state, payload);
    case "WindowLayoutsChanged":
        return applyWindowLayoutsChanged(state, payload);
    case "WindowUrgencyChanged":
        return updateWindowFlag(state, payload, "urgent");
    case "OutputsChanged":
        return applyOutputs(state, payload ? payload.outputs : null);
    case "OverviewOpenedOrClosed":
        return applyOverview(state, payload);
    case "KeyboardLayoutsChanged":
        return applyKeyboardLayoutsChanged(state, payload);
    case "KeyboardLayoutSwitched":
        return applyKeyboardLayoutSwitched(state, payload);
    default:
        return result(state, false, "");
    }
}

function workspaceReferenceForId(state, id) {
    var idKey = idText(id);
    if (idKey.length === 0) {
        return {
            ok: false,
            reference: null,
            error: "workspace id is required"
        };
    }

    var workspace = state.workspacesById[idKey];
    if (!workspace) {
        return {
            ok: false,
            reference: null,
            error: "Unknown Niri workspace id: " + idKey
        };
    }

    if (workspace.name.length > 0) {
        return {
            ok: true,
            reference: {
                Name: workspace.name
            },
            error: ""
        };
    }

    if (workspace.index > 0 && workspace.outputName.length > 0 && workspace.outputName === state.focusedOutputName) {
        return {
            ok: true,
            reference: {
                Index: workspace.index
            },
            error: ""
        };
    }

    // ponytail: ceiling is by-id focus only for named workspaces or current-output indexes; upgrade path is a verified FocusMonitor + FocusWorkspace sequence if cross-output by-id focus becomes a real UI need.
    return {
        ok: false,
        reference: null,
        error: "Niri cannot focus this workspace by id without changing monitor focus first"
    };
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
        var workspace = copyObject(next.workspaces[i]);
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

function updateWorkspaceFlag(state, payload, propertyName) {
    if (!payload || idText(payload.id).length === 0 || typeof payload.urgent !== "boolean") {
        return result(state, false, "Invalid WorkspaceUrgencyChanged event");
    }

    var idKey = idText(payload.id);
    if (!state.workspacesById[idKey]) {
        return result(state, false, "");
    }

    var next = copyState(state);
    next.workspaces = mapReplace(next.workspaces, idKey, function(workspace) {
        workspace[propertyName] = payload.urgent;
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
            var copied = copyObject(current);
            if (window.focused) {
                copied.focused = false;
            }
            windows.push(copied);
        }
    }
    if (!found) {
        windows.push(window);
    }
    next.windows = sortWindows(windows, state.workspacesById);
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

function applyWindowFocusChanged(state, payload) {
    if (!payload || (!Object.prototype.hasOwnProperty.call(payload, "id"))) {
        return result(state, false, "Invalid WindowFocusChanged event");
    }

    var idKey = idText(payload.id);
    var next = copyState(state);
    next.windows = next.windows.map(function(window) {
        var copy = copyObject(window);
        copy.focused = idKey.length > 0 && copy.id === idKey;
        return copy;
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

function updateWindowFlag(state, payload, propertyName) {
    if (!payload || idText(payload.id).length === 0 || typeof payload.urgent !== "boolean") {
        return result(state, false, "Invalid WindowUrgencyChanged event");
    }

    var idKey = idText(payload.id);
    if (!state.windowsById[idKey]) {
        return result(state, false, "");
    }

    var next = copyState(state);
    next.windows = mapReplace(next.windows, idKey, function(window) {
        window[propertyName] = payload.urgent;
        return window;
    });
    return result(derive(next), true, "");
}

function applyOutputs(state, payload) {
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
        return result(state, false, "Invalid Niri outputs payload");
    }

    var outputs = [];
    var keys = Object.keys(payload);
    for (var i = 0; i < keys.length; i += 1) {
        outputs.push(normalizeOutput(payload[keys[i]], keys[i]));
    }

    var next = copyState(state);
    next.outputs = sortOutputs(outputs);
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

function applyKeyboardLayoutsChanged(state, payload) {
    if (!payload || !payload.keyboard_layouts || !Array.isArray(payload.keyboard_layouts.names)) {
        return result(state, false, "Invalid KeyboardLayoutsChanged event");
    }

    var next = copyState(state);
    next.keyboardLayoutNames = payload.keyboard_layouts.names.slice();
    next.currentKeyboardLayoutIndex = safeInteger(payload.keyboard_layouts.current_idx, -1);
    return result(derive(next), true, "");
}

function applyKeyboardLayoutSwitched(state, payload) {
    if (!payload || !Number.isSafeInteger(payload.idx)) {
        return result(state, false, "Invalid KeyboardLayoutSwitched event");
    }

    var next = copyState(state);
    next.currentKeyboardLayoutIndex = payload.idx;
    return result(derive(next), true, "");
}

function derive(state) {
    var next = copyState(state);
    next.outputsByName = {};
    for (var i = 0; i < next.outputs.length; i += 1) {
        next.outputsByName[next.outputs[i].name] = next.outputs[i];
    }

    next.workspacesById = {};
    next.workspacesByOutput = {};
    next.focusedWorkspaceId = "";
    next.focusedWorkspace = null;
    for (var j = 0; j < next.workspaces.length; j += 1) {
        var workspace = next.workspaces[j];
        next.workspacesById[workspace.id] = workspace;
        var outputName = workspace.outputName;
        if (!next.workspacesByOutput[outputName]) {
            next.workspacesByOutput[outputName] = [];
        }
        next.workspacesByOutput[outputName].push(workspace);
        if (workspace.focused) {
            next.focusedWorkspaceId = workspace.id;
            next.focusedWorkspace = workspace;
        }
    }

    var outputKeys = Object.keys(next.workspacesByOutput);
    for (var k = 0; k < outputKeys.length; k += 1) {
        next.workspacesByOutput[outputKeys[k]].sort(compareWorkspace);
    }

    next.focusedOutputName = next.focusedWorkspace ? next.focusedWorkspace.outputName : next.focusedOutputName;
    next.currentOutputWorkspaces = next.workspacesByOutput[next.focusedOutputName] || [];

    next.windowsById = {};
    next.focusedWindowId = "";
    next.focusedWindow = null;
    for (var w = 0; w < next.windows.length; w += 1) {
        var windowItem = copyObject(next.windows[w]);
        var owningWorkspace = next.workspacesById[windowItem.workspaceId];
        windowItem.outputName = owningWorkspace ? owningWorkspace.outputName : windowItem.outputName;
        next.windows[w] = windowItem;
        next.windowsById[windowItem.id] = windowItem;
        if (windowItem.focused) {
            next.focusedWindowId = windowItem.id;
            next.focusedWindow = windowItem;
        }
    }

    next.currentKeyboardLayoutName = "";
    if (next.currentKeyboardLayoutIndex >= 0 && next.currentKeyboardLayoutIndex < next.keyboardLayoutNames.length) {
        next.currentKeyboardLayoutName = next.keyboardLayoutNames[next.currentKeyboardLayoutIndex];
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
    return sortWindows(windows.map(function(window) {
        return normalizeWindow(window, workspacesById);
    }), workspacesById);
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
        focused: window.is_focused === true,
        urgent: window.is_urgent === true,
        layout: window.layout || null
    };
}

function normalizeOutput(output, fallbackName) {
    var source = output || {};
    var name = source.name ? String(source.name) : String(fallbackName || "");
    if (name.length === 0) {
        throw new Error("output name is required");
    }

    return {
        name: name,
        make: optionalString(source.make),
        model: optionalString(source.model),
        serial: optionalString(source.serial),
        logical: source.logical || null,
        currentModeIndex: source.current_mode === null || source.current_mode === undefined ? -1 : safeInteger(source.current_mode, -1),
        vrrSupported: source.vrr_supported === true,
        vrrEnabled: source.vrr_enabled === true
    };
}

function sortWindows(windows, workspacesById) {
    return windows.slice().sort(function(a, b) {
        var aWorkspace = workspacesById[a.workspaceId];
        var bWorkspace = workspacesById[b.workspaceId];
        var outputCompare = compareString(a.outputName, b.outputName);
        if (outputCompare !== 0) {
            return outputCompare;
        }
        var aIndex = aWorkspace ? aWorkspace.index : 999999;
        var bIndex = bWorkspace ? bWorkspace.index : 999999;
        if (aIndex !== bIndex) {
            return aIndex - bIndex;
        }
        return numericId(a.id) - numericId(b.id);
    });
}

function sortOutputs(outputs) {
    return outputs.slice().sort(function(a, b) {
        var ax = a.logical && Number.isFinite(a.logical.x) ? a.logical.x : 999999;
        var bx = b.logical && Number.isFinite(b.logical.x) ? b.logical.x : 999999;
        if (ax !== bx) {
            return ax - bx;
        }

        var ay = a.logical && Number.isFinite(a.logical.y) ? a.logical.y : 999999;
        var by = b.logical && Number.isFinite(b.logical.y) ? b.logical.y : 999999;
        if (ay !== by) {
            return ay - by;
        }

        return compareString(a.name, b.name);
    });
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

        return replacer(copyObject(item));
    });
}

function copyState(state) {
    return {
        outputs: state.outputs ? state.outputs.slice() : [],
        outputsByName: copyObject(state.outputsByName),
        workspaces: state.workspaces ? state.workspaces.slice() : [],
        workspacesById: copyObject(state.workspacesById),
        workspacesByOutput: copyObject(state.workspacesByOutput),
        focusedOutputName: optionalString(state.focusedOutputName),
        focusedWorkspaceId: optionalString(state.focusedWorkspaceId),
        focusedWorkspace: state.focusedWorkspace || null,
        currentOutputWorkspaces: state.currentOutputWorkspaces ? state.currentOutputWorkspaces.slice() : [],
        windows: state.windows ? state.windows.slice() : [],
        windowsById: copyObject(state.windowsById),
        focusedWindowId: optionalString(state.focusedWindowId),
        focusedWindow: state.focusedWindow || null,
        overviewOpen: state.overviewOpen === true,
        keyboardLayoutNames: state.keyboardLayoutNames ? state.keyboardLayoutNames.slice() : [],
        currentKeyboardLayoutIndex: safeInteger(state.currentKeyboardLayoutIndex, -1),
        currentKeyboardLayoutName: optionalString(state.currentKeyboardLayoutName)
    };
}

function copyObject(source) {
    var copy = {};
    if (!source || typeof source !== "object") {
        return copy;
    }

    var keys = Object.keys(source);
    for (var i = 0; i < keys.length; i += 1) {
        copy[keys[i]] = source[keys[i]];
    }
    return copy;
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
