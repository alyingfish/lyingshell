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

function focusWorkspaceByIdRequest(id) {
    return actionRequest("FocusWorkspace", {
        reference: {
            Id: requiredIntegerId(id, "workspace id")
        }
    });
}

function takeScreenshotRequest() {
    // niri-ipc serde has no field defaults: send the full payload.
    return actionRequest("Screenshot", {
        show_pointer: true,
        path: null
    });
}

function quitSessionRequest() {
    return actionRequest("Quit", {
        skip_confirmation: true
    });
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
