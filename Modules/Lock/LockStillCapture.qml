import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services

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
// The view is armed only while the entry capture runs ("enter"), and the
// shot itself is deliberately serialized: it waits for `hold` (the host
// window's own overlays fading shut) and then a two-frame settle, so the
// screencopy binds in a quiet dispatch and freezes a composited frame of
// the SETTLED desktop. Firing it in the same instant the quick-settings
// panel was tearing down froze the half-closed panel into the still — and
// that same one-dispatch pileup (click, panel teardown, screencopy bind,
// lock surfaces mapping) is where the stale-screen wl_surface.enter crash
// reproduced three-for-three, so the wait is crash avoidance as much as
// cosmetics. The view captures one frame on its own schedule (an explicit
// captureFrame() before the recording context is ready is refused), and
// hasContent is the signal that the frame landed. A grab that cannot even
// be scheduled answers with null so the lock never waits for a callback
// that will not come — Lock's captureBail bounds the whole stage, holds
// and settle included.
Item {
    id: root

    property ShellScreen screen: null
    // Raised by the hosting window while its own overlays (quick-settings
    // panel, tray popover) are still fading: the lock gesture closes them,
    // but the close is an animation, and a still taken mid-fade would carry
    // the half-closed panel through the whole entry sweep.
    property bool hold: false

    readonly property string outputName: screen ? screen.name : ""
    readonly property bool armed: Lock.sweepMode === "enter" && root.screen !== null && !root.hold

    width: screen ? screen.width : 0
    height: screen ? screen.height : 0

    // Two frames past the hold clearing, so the compositor has composited
    // the overlay-free desktop before the screencopy freezes it; the fade's
    // last drawn frame still carries a faint panel.
    onArmedChanged: {
        if (armed) {
            settle.restart();
        } else {
            settle.stop();
            captureLoader.active = false;
        }
    }

    Timer {
        id: settle

        interval: 34
        onTriggered: captureLoader.active = true
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
