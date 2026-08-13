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
// The view exists only while the entry capture runs ("enter"); it captures
// one frame on its own schedule (an explicit captureFrame() before the
// recording context is ready is refused), and hasContent is the signal that
// the frame landed. A grab that cannot even be scheduled answers with null
// so the lock never waits for a callback that will not come — Lock's
// captureBail bounds the rest.
Item {
    id: root

    property ShellScreen screen: null

    readonly property string outputName: screen ? screen.name : ""

    width: screen ? screen.width : 0
    height: screen ? screen.height : 0

    Loader {
        anchors.fill: parent
        active: Lock.sweepMode === "enter" && root.screen !== null
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
