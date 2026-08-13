import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services

import "LockMotion.js" as LockMotion

// One output's pre-lock desktop capture, hosted OFFSCREEN inside a window
// that already exists (the bar hosts one per output, parked just below its
// own strip). Raising fresh fullscreen windows at lock time is exactly what
// this replaces: mapping them stuttered the lock's first frames, and the
// surface/focus churn tripped a Qt wl_surface.enter crash in the wild
// (QtWaylandClient dereferences a stale screen while logging "Ignoring
// unexpected wl_surface.enter"). grabToImage renders an item at the item's
// own size regardless of the window's viewport — the visual_lock*.qml
// trick — so a bar strip can deliver a full-screen still.
//
// The view is armed only while the entry capture runs ("capture"), and the
// shot is serialized behind `hold` (the host window's own overlays going
// away — the entry gesture cuts them shut, so this normally clears in the
// same tick) plus a ONE-FRAME handshake: the cut is only QML state until
// the host's render thread commits a frame carrying it, so the capture
// pokes an invisible pixel, waits for the host's next frameSwapped, and
// only then requests the copy. The screencopy request and the host's
// commit travel the same Wayland connection in that order, so the still
// can never carry the panel — no fixed settle, no race, one frame. The
// bail covers a host that never swaps (nothing dirty, updates throttled),
// and Lock's captureBail bounds the whole stage, hold and handshake
// included. The view captures one frame on its own schedule (an explicit
// captureFrame() before the recording context is ready is refused), and
// hasContent is the signal that the frame landed. A grab that cannot even
// be scheduled answers with null so the lock never waits for a callback
// that will not come.
Item {
    id: root

    property ShellScreen screen: null
    // Raised by the hosting window while its own overlays (quick-settings
    // panel, tray popover) are still up. The entry gesture cuts them shut
    // (their close animations are disabled while the entry runs), so this
    // normally clears within the arming tick; it lingers only for the
    // states with no animation to cut (a tray drag in flight), and Lock's
    // captureBail bounds even those.
    property bool hold: false

    readonly property string outputName: screen ? screen.name : ""
    readonly property bool armed: Lock.entryStage === "capture" && root.screen !== null && !root.hold

    width: screen ? screen.width : 0
    height: screen ? screen.height : 0

    property bool handshakeDone: false

    onArmedChanged: {
        if (armed) {
            handshakeDone = false;
            // Force a fresh host frame even when nothing else is dirty: the
            // capture itself sits below the viewport and dirties nothing.
            nudge.rotation = nudge.rotation === 0 ? 1 : 0;
            handshakeBail.restart();
        } else {
            handshakeBail.stop();
            handshakeDone = false;
            captureLoader.active = false;
        }
    }

    function completeHandshake() {
        if (!armed || handshakeDone) {
            return;
        }
        handshakeDone = true;
        handshakeBail.stop();
        captureLoader.active = true;
    }

    // In the host window's visible region on purpose: a node parked below
    // the viewport can be culled, and a culled change may not schedule a
    // frame. Same trick as Bar.qml's unpark nudge.
    Rectangle {
        id: nudge

        parent: root.Window.window ? root.Window.window.contentItem : root
        width: 1
        height: 1
        color: "transparent"
    }

    Connections {
        target: root.Window.window
        enabled: root.armed && !root.handshakeDone

        function onFrameSwapped() {
            root.completeHandshake();
        }
    }

    Timer {
        id: handshakeBail

        interval: LockMotion.captureHandshakeBailMs
        onTriggered: root.completeHandshake()
    }

    Loader {
        id: captureLoader

        anchors.fill: parent
        active: false
        sourceComponent: capture
    }

    Component {
        id: capture

        ScreencopyView {
            id: view

            property bool delivered: false

            captureSource: root.screen
            live: false
            paintCursor: false

            onHasContentChanged: {
                if (!hasContent || delivered) {
                    return;
                }
                delivered = true;
                if (!view.grabToImage(function (grab) {
                    Lock.deliverDesktopStill(root.outputName, grab);
                })) {
                    Lock.deliverDesktopStill(root.outputName, null);
                }
            }
        }
    }
}
