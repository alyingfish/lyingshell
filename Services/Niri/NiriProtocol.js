.pragma library

function ok(payload) {
    return {
        ok: true,
        payload: payload,
        error: ""
    };
}

function fail(message) {
    return {
        ok: false,
        payload: null,
        error: message
    };
}

function eventStreamRequest() {
    return "EventStream";
}

function encodeRequest(request) {
    return JSON.stringify(request) + "\n";
}

function parseReplyLine(line) {
    var reply = null;

    try {
        reply = JSON.parse(line);
    } catch (error) {
        return fail("Invalid Niri IPC reply JSON: " + errorMessageText(error));
    }

    if (!reply || typeof reply !== "object" || Array.isArray(reply)) {
        return fail("Invalid Niri IPC reply");
    }

    if (Object.prototype.hasOwnProperty.call(reply, "Ok")) {
        return ok(reply.Ok);
    }

    if (Object.prototype.hasOwnProperty.call(reply, "Err")) {
        return fail(errorMessageText(reply.Err));
    }

    return fail("Invalid Niri IPC reply envelope");
}

function focusWorkspaceByNameRequest(name) {
    return focusWorkspaceByReferenceRequest(workspaceNameReference(name));
}

function focusWorkspaceByIndexRequest(index) {
    return focusWorkspaceByReferenceRequest(workspaceIndexReference(index));
}

function focusWorkspaceByReferenceRequest(reference) {
    return actionRequest("FocusWorkspace", {
        reference: reference
    });
}

function focusWindowRequest(id) {
    return actionRequest("FocusWindow", {
        id: requiredIntegerId(id, "window id")
    });
}

function focusColumnLeftRequest() {
    return actionRequest("FocusColumnLeft", {});
}

function focusColumnRightRequest() {
    return actionRequest("FocusColumnRight", {});
}

function focusWorkspaceUpRequest() {
    return actionRequest("FocusWorkspaceUp", {});
}

function focusWorkspaceDownRequest() {
    return actionRequest("FocusWorkspaceDown", {});
}

function toggleOverviewRequest() {
    return actionRequest("ToggleOverview", {});
}

function setFocusedWorkspaceNameRequest(name) {
    return actionRequest("SetWorkspaceName", {
        name: requiredNonEmptyString(name, "workspace name"),
        workspace: null
    });
}

function unsetFocusedWorkspaceNameRequest() {
    return actionRequest("UnsetWorkspaceName", {
        reference: null
    });
}

function workspaceNameReference(name) {
    return {
        Name: requiredNonEmptyString(name, "workspace name")
    };
}

function workspaceIndexReference(index) {
    return {
        Index: requiredPositiveInteger(index, "workspace index")
    };
}

function actionRequest(actionName, payload) {
    var action = {};
    action[actionName] = payload;
    return {
        Action: action
    };
}

function requiredIntegerId(value, label) {
    var numberValue = typeof value === "string" ? Number(value) : value;
    if (!Number.isSafeInteger(numberValue) || numberValue < 0) {
        throw new Error(label + " must be a safe non-negative integer");
    }

    return numberValue;
}

function requiredPositiveInteger(value, label) {
    if (!Number.isSafeInteger(value) || value < 1) {
        throw new Error(label + " must be a positive integer");
    }

    return value;
}

function requiredNonEmptyString(value, label) {
    if (typeof value !== "string" || value.length === 0) {
        throw new Error(label + " must be a non-empty string");
    }

    return value;
}

function errorMessageText(error) {
    if (error === null || error === undefined) {
        return "unknown error";
    }

    if (typeof error === "string") {
        return error;
    }

    if (error.message) {
        return String(error.message);
    }

    try {
        return JSON.stringify(error);
    } catch (_) {
        return String(error);
    }
}
