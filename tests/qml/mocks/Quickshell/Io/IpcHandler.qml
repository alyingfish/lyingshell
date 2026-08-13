import QtQml

// Test stand-in for Quickshell.Io.IpcHandler under plain qml6. The declared
// functions ride on the instance; nothing routes IPC to them in a test.
QtObject {
    property string target: ""
}
