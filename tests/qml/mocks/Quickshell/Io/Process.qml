import QtQml

// Test stand-in for Quickshell.Io.Process under plain qml6: inert. Nothing
// is spawned and `exited` never fires, so a service that shells out at
// construction (Lock's AccountsService portrait lookup) loads and then sits
// at its empty default — which is the same state a machine without the
// daemon reaches.
QtObject {
    property bool running: false
    property var command: []
    property var stdout: null
    property var stderr: null
    property string workingDirectory: ""

    signal exited(int exitCode, int exitStatus)
    signal started

    function startDetached() {
    }

    function signal(sig) {
    }
}
