pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

// Do Not Disturb over mako's mode mechanism. Documented gap: mako owns the
// notification daemon role in this session, and two daemons cannot coexist,
// so Quickshell.Services.Notifications is not usable here; makoctl is the
// daemon's own control interface, not a polled fallback.
//
// Banner suppression requires the conventional mako config section:
//   [mode=do-not-disturb]
//   invisible=1
Singleton {
    id: root

    readonly property string modeName: "do-not-disturb"
    property bool available: false
    property bool enabled: false
    property bool busy: false

    function refresh() {
        if (!readProcess.running) {
            readProcess.running = true;
        }
    }

    function toggle() {
        if (busy) {
            return;
        }
        busy = true;
        enabled = !enabled;
        toggleProcess.command = ["makoctl", "mode", enabled ? "-a" : "-r", modeName];
        toggleProcess.running = true;
    }

    function _applyModes(text) {
        available = true;
        enabled = text.split("\n").indexOf(modeName) >= 0;
    }

    Component.onCompleted: refresh()

    Process {
        id: readProcess

        command: ["makoctl", "mode"]

        stdout: StdioCollector {
            onStreamFinished: root._applyModes(text)
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                root.available = false;
            }
        }
    }

    Process {
        id: toggleProcess

        // makoctl mode -a/-r prints the resulting mode list.
        stdout: StdioCollector {
            onStreamFinished: root._applyModes(text)
        }

        onExited: root.busy = false
    }
}
