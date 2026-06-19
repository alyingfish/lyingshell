pragma Singleton

import Quickshell
import Quickshell.Io
import "NiriState.js" as NiriState
import "NiriProtocol.js" as NiriProtocol

Singleton {
    id: root

    property string errorMessage: ""
    property bool stale: available
    property int lastEventVersion: 0

    readonly property string socketPath: String(Quickshell.env("NIRI_SOCKET") || "")
    readonly property bool available: socketPath.length > 0
    readonly property bool connected: eventSocket.connected
    readonly property bool ready: connected && _eventStreamReady && !stale
    readonly property bool hasError: errorMessage.length > 0

    readonly property var workspaces: _state.workspaces
    readonly property var workspacesById: _state.workspacesById
    readonly property var workspacesByOutput: _state.workspacesByOutput
    readonly property string focusedOutputName: _state.focusedOutputName
    readonly property string focusedWorkspaceId: _state.focusedWorkspaceId
    readonly property var focusedWorkspace: _state.focusedWorkspace
    readonly property var currentOutputWorkspaces: _state.currentOutputWorkspaces

    readonly property var windows: _state.windows
    readonly property var windowsById: _state.windowsById
    readonly property string focusedWindowId: _state.focusedWindowId
    readonly property var focusedWindow: _state.focusedWindow

    readonly property var outputsByName: _state.outputsByName
    readonly property var outputs: _state.outputs
    readonly property bool overviewOpen: _state.overviewOpen
    readonly property var keyboardLayoutNames: _state.keyboardLayoutNames
    readonly property int currentKeyboardLayoutIndex: _state.currentKeyboardLayoutIndex
    readonly property string currentKeyboardLayoutName: _state.currentKeyboardLayoutName

    property var _state: NiriState.initialState()
    property bool _requestPending: false
    property bool _eventStreamReady: false

    Component.onCompleted: {
        if (!available) {
            _setError("NIRI_SOCKET is not set");
        }
    }

    Socket {
        id: eventSocket

        path: root.socketPath
        connected: root.available

        onConnectedChanged: {
            if (connected) {
                root._handleEventSocketConnected();
            } else {
                root._handleEventSocketDisconnected();
            }
        }

        onError: function(socketError) {
            root._handleSocketError("event", socketError);
        }

        parser: SplitParser {
            onRead: function(line) {
                root._handleEventLine(line);
            }
        }
    }

    Socket {
        id: requestSocket

        path: root.socketPath
        connected: root.available

        onConnectedChanged: {
            if (!connected) {
                root._requestPending = false;
            }
        }

        onError: function(socketError) {
            root._requestPending = false;
            root._handleSocketError("request", socketError);
        }

        parser: SplitParser {
            onRead: function(line) {
                root._handleRequestReplyLine(line);
            }
        }
    }

    function focusWorkspaceById(id: string): bool {
        var resolved = NiriState.workspaceReferenceForId(_state, id);
        if (!resolved.ok) {
            _setError(resolved.error);
            return false;
        }

        return _sendBuiltAction(function() {
            return NiriProtocol.focusWorkspaceByReferenceRequest(resolved.reference);
        });
    }

    function focusWorkspaceByName(name: string): bool {
        return _sendBuiltAction(function() {
            return NiriProtocol.focusWorkspaceByNameRequest(name);
        });
    }

    function focusWorkspaceByIndex(index: int): bool {
        return _sendBuiltAction(function() {
            return NiriProtocol.focusWorkspaceByIndexRequest(index);
        });
    }

    function focusWindow(id: string): bool {
        return _sendBuiltAction(function() {
            return NiriProtocol.focusWindowRequest(id);
        });
    }

    function focusColumnLeft(): bool {
        return _sendNiriRequest(NiriProtocol.focusColumnLeftRequest());
    }

    function focusColumnRight(): bool {
        return _sendNiriRequest(NiriProtocol.focusColumnRightRequest());
    }

    function focusWorkspaceUp(): bool {
        return _sendNiriRequest(NiriProtocol.focusWorkspaceUpRequest());
    }

    function focusWorkspaceDown(): bool {
        return _sendNiriRequest(NiriProtocol.focusWorkspaceDownRequest());
    }

    function toggleOverview(): bool {
        return _sendNiriRequest(NiriProtocol.toggleOverviewRequest());
    }

    function setFocusedWorkspaceName(name: string): bool {
        return _sendBuiltAction(function() {
            return NiriProtocol.setFocusedWorkspaceNameRequest(name);
        });
    }

    function unsetFocusedWorkspaceName(): bool {
        return _sendNiriRequest(NiriProtocol.unsetFocusedWorkspaceNameRequest());
    }

    function _sendBuiltAction(buildRequest) {
        try {
            return _sendNiriRequest(buildRequest());
        } catch (error) {
            _setError(NiriProtocol.errorMessageText(error));
            return false;
        }
    }

    function _handleEventSocketConnected() {
        _eventStreamReady = false;
        stale = true;
        errorMessage = "";
        eventSocket.write(NiriProtocol.encodeRequest(NiriProtocol.eventStreamRequest()));
        eventSocket.flush();
    }

    function _handleEventSocketDisconnected() {
        _eventStreamReady = false;
        stale = available;
    }

    function _handleEventLine(line) {
        if (line.length === 0) {
            return;
        }

        if (!_eventStreamReady) {
            _handleEventStreamReply(NiriProtocol.parseReplyLine(line));
            return;
        }

        _applyReducerResult(NiriState.applyEventLine(_state, line), true);
    }

    function _handleEventStreamReply(reply) {
        if (!reply.ok) {
            _setError("Niri event stream request failed: " + reply.error);
            eventSocket.connected = false;
            return;
        }

        if (reply.payload !== "Handled") {
            _setError("Unexpected Niri event stream reply");
            eventSocket.connected = false;
            return;
        }

        _eventStreamReady = true;
    }

    function _handleRequestReplyLine(line) {
        if (line.length === 0) {
            return;
        }

        _requestPending = false;

        var reply = NiriProtocol.parseReplyLine(line);
        if (!reply.ok) {
            _setError(reply.error);
            return;
        }

        errorMessage = "";
    }

    function _sendNiriRequest(request) {
        if (_requestPending) {
            _setError("Niri IPC request already pending");
            return false;
        }

        var prepared = NiriProtocol.prepareRequest(requestSocket.connected, request);
        if (!prepared.ok) {
            _setError(prepared.error);
            return false;
        }

        _requestPending = true;
        requestSocket.write(prepared.line);
        requestSocket.flush();
        return true;
    }

    function _applyReducerResult(result, eventResult) {
        if (result.error.length > 0) {
            _setError(result.error);
            return;
        }

        _state = result.state;
        if (eventResult) {
            lastEventVersion += 1;
            if (result.changed) {
                stale = false;
            }
        }

        errorMessage = "";
    }

    function _handleSocketError(socketName, socketError) {
        stale = true;
        _setError("Niri " + socketName + " socket error: " + String(socketError));
    }

    function _setError(message) {
        errorMessage = message;
        if (message.length > 0) {
            console.warn("[Niri] " + message);
        }
    }
}
