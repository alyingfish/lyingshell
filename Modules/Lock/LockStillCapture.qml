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
// shot is serialized behind `hold` (the host window's own overlays going
// away — the entry gesture cuts them shut, so this normally clears in the
// same tick) plus a short settle, so the bar has committed its overlay-free
// frame and the compositor has ingested it before the screencopy renders.
// Without the wait the still froze the quick-settings panel mid-close over
// the desktop for the whole entry sweep. (The wait is cosmetic only: the
// stale-screen wl_surface.enter crash first blamed on this instant fired
// even with the capture fully deferred — its actual fix is the
// QT_LOGGING_RULES line in scripts/run.sh.) The view captures one frame on
// its own schedule (an explicit captureFrame() before the recording context
// is ready is refused), and hasContent is the signal that the frame landed.
// A grab that cannot even be scheduled answers with null so the lock never
// waits for a callback that will not come — Lock's captureBail bounds the
// whole stage, hold and settle included.
Item {
    id: root

    property ShellScreen screen: null
    // Raised by the hosting window while its own overlays (quick-settings
    // panel, tray popover) are still up. The entry gesture cuts them shut
    // (their close animations are disabled while sweepMode is "enter"), so
    // this normally clears within the arming tick; it lingers only for the
    // states with no animation to cut (a tray drag in flight), and Lock's
    // captureBail bounds even those.
    property bool hold: false

    readonly property string outputName: screen ? screen.name : ""
    readonly property bool armed: Lock.sweepMode === "enter" && root.screen !== null && !root.hold

    width: screen ? screen.width : 0
    height: screen ? screen.height : 0

    // Three frames past arming: the overlay cut is QML state until the bar's
    // render thread commits a frame, and the screencopy renders whatever
    // state the compositor holds when it lands — too early and the still
    // carries the fully-open panel.
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

        interval: 50
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
