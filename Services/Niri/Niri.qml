pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "NiriState.js" as NiriState
import "NiriProtocol.js" as NiriProtocol

Singleton {
    id: root

    property string errorMessage: ""
    property int lastEventVersion: 0

    readonly property string socketPath: String(Quickshell.env("NIRI_SOCKET") || "")
    readonly property bool available: socketPath.length > 0

    readonly property var workspacesByOutput: _state.workspacesByOutput
    readonly property string focusedOutputName: _state.focusedOutputName
    readonly property var windowsById: _state.windowsById
    readonly property bool overviewOpen: _state.overviewOpen

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
        try {
            return _sendNiriRequest(NiriProtocol.focusWorkspaceByIdRequest(id));
        } catch (error) {
            _setError(NiriProtocol.errorMessageText(error));
            return false;
        }
    }

    // Opens niri's built-in screenshot UI.
    function takeScreenshot(): bool {
        try {
            return _sendNiriRequest(NiriProtocol.takeScreenshotRequest());
        } catch (error) {
            _setError(NiriProtocol.errorMessageText(error));
            return false;
        }
    }

    // Ends the niri session (quick settings "Log Out").
    function quitSession(): bool {
        try {
            return _sendNiriRequest(NiriProtocol.quitSessionRequest());
        } catch (error) {
            _setError(NiriProtocol.errorMessageText(error));
            return false;
        }
    }

    // Picked color as "#rrggbb" (quick-settings color-picker tool).
    signal colorPicked(string hex)

    // Starts niri's interactive color pick. Uses a dedicated socket: the
    // reply only arrives after the user clicks, which would block the shared
    // request socket for the whole aim time.
    function pickColor(): bool {
        if (!available || pickSocket.connected) {
            return false;
        }
        pickSocket.connected = true;
        return true;
    }

    Socket {
        id: pickSocket

        path: root.socketPath
        connected: false

        onConnectedChanged: {
            if (connected) {
                write(NiriProtocol.encodeRequest(NiriProtocol.pickColorRequest()));
                flush();
            }
        }

        onError: function (socketError) {
            root._handleSocketError("pick-color", socketError);
        }

        parser: SplitParser {
            onRead: function (line) {
                root._handlePickColorReply(line);
            }
        }
    }

    function _handlePickColorReply(line) {
        pickSocket.connected = false;
        if (line.length === 0) {
            return;
        }

        var reply = NiriProtocol.parseReplyLine(line);
        // A cancelled pick (Esc) is a user choice, not a service error.
        if (!reply.ok) {
            return;
        }

        var hex = NiriProtocol.pickedColorHex(reply.payload);
        if (hex.length > 0) {
            colorPicked(hex);
        }
    }

    function _handleEventSocketConnected() {
        _eventStreamReady = false;
        errorMessage = "";
        eventSocket.write(NiriProtocol.encodeRequest(NiriProtocol.eventStreamRequest()));
        eventSocket.flush();
    }

    function _handleEventSocketDisconnected() {
        _eventStreamReady = false;
    }

    function _handleEventLine(line) {
        if (line.length === 0) {
            return;
        }

        if (!_eventStreamReady) {
            _handleEventStreamReply(NiriProtocol.parseReplyLine(line));
            return;
        }

        _applyReducerResult(NiriState.applyEventLine(_state, line));
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

        if (!requestSocket.connected) {
            _setError("Niri IPC request socket is not connected");
            return false;
        }

        _requestPending = true;
        requestSocket.write(NiriProtocol.encodeRequest(request));
        requestSocket.flush();
        return true;
    }

    function _applyReducerResult(result) {
        if (result.error.length > 0) {
            _setError(result.error);
            return;
        }

        _state = result.state;
        lastEventVersion += 1;
        errorMessage = "";
    }

    function _handleSocketError(socketName, socketError) {
        _setError("Niri " + socketName + " socket error: " + String(socketError));
    }

    function _setError(message) {
        errorMessage = message;
        if (message.length > 0) {
            console.warn("[Niri] " + message);
        }
    }
}
