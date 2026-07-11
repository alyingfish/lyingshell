pragma Singleton

import QtQml
import Quickshell

// Transient status toasts (web-prototype #toast): fire-and-forget messages
// raised by services and the quick-settings pages ("Connected to X",
// "Pairing failed — Y"). The singleton owns the queue-of-one and its timing;
// Modules/Toast/ToastOverlay.qml renders it.
Singleton {
    id: root

    // Current message; valid while `active`.
    property string text: ""
    // Window mapped (kept through the hide animation).
    property bool active: false
    // Content shown; false during the fade-out beat before unmap.
    property bool shown: false

    function show(message: string) {
        text = message;
        shown = false;
        // Retrigger the entrance when a toast replaces a visible one
        // (prototype re-adds .show after a reflow).
        Qt.callLater(() => {
            root.active = true;
            root.shown = true;
            hideTimer.restart();
        });
    }

    Timer {
        id: hideTimer

        interval: 2400
        onTriggered: {
            root.shown = false;
            unmapTimer.restart();
        }
    }

    Timer {
        id: unmapTimer

        interval: 300
        onTriggered: if (!root.shown) {
            root.active = false;
        }
    }
}
