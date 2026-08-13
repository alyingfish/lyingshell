import QtQml

// Test stand-in for Quickshell.Io.StdioCollector under plain qml6: the
// collected text of a process that never ran is empty.
QtObject {
    property string text: ""
    property var data: null

    signal streamFinished
}
