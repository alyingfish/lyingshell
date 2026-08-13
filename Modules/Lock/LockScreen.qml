import QtQuick

import Quickshell
import Quickshell.Wayland
import qs.Commons.Settings
import qs.Services
import qs.Services.Niri

import "LockMotion.js" as LockMotion

// The lock screen as the compositor sees it: one ext-session-lock surface per
// output, plus the pair of layer-shell surfaces the sweep runs on.
//
// MULTI-MONITOR. Every output is covered — that is the protocol's own
// requirement and what makes the lock secure. The focused output gets the
// whole thing (avatar, prompt, tray); the rest get the wallpaper and the clock
// and nothing to type into, so the prompt is where the user is already
// looking. Set `lock.focusedOutputOnly` false to put the full scene on every
// output. A monitor plugged in while locked is covered by the compositor
// before Quickshell ever hears about it.
//
// THE SWEEP. The prototype clips the DESKTOP to a circle and rides it above
// the lock scene. Under Wayland nothing can be composited under a session-lock
// surface — niri renders the lock surface and an opaque colour and returns —
// so a live desktop cannot be shown through it, and a screencopy taken while
// locked captures the lock screen, not the desktop. Each half of the gesture
// therefore rides on whatever the compositor is actually drawing at the time:
//
//   enter   before the lock is requested, a capture window per output shows
//           one frozen wlr-screencopy frame of its desktop and hands a grab
//           of it to the Lock singleton; the session locks the moment every
//           output has answered. Each lock surface then draws that still
//           over its scene, clipped to the circle (lock_desk.frag), and the
//           circle shrinks into the avatar's spot on the lock surface
//           itself — the one window the locked compositor draws, so the
//           animation always has frame callbacks and a keystroke lands on
//           the live scene from the first locked frame.
//   exit    each lock surface grabs its frozen hello pose into an image, a
//           fresh window buffers that still — full cover, hole at nothing —
//           under the lock, and only then is the lock released: the
//           compositor swaps one for the other with no gap. The hole grows
//           back out of the avatar over a desktop that is live, and the
//           windows are dropped when it lands.
//
// The visible result is the prototype's: a circle of desktop, centred on the
// avatar, riding above a lock scene that never moves. What differs is that
// the desktop in the entry circle is a still — the price of taking the real
// lock BEFORE the circle moves rather than after it lands.
//
// RENDERING SAFETY: the compositor sends frame callbacks only to surfaces it
// draws, and while locked it draws nothing but the lock surfaces. A sweep
// window forced to render in that state stalls its render thread on buffers
// that are never released, and that stall can wedge the shell. Hence the
// shape of everything below: the entry circle animates on the lock surfaces
// themselves; capture windows park (updatesEnabled) the moment the lock is
// requested and are destroyed once the compositor confirms coverage; exit
// windows hold a static still — nothing in them can animate on its own —
// and render exactly one frame while hidden, which a fresh swapchain can
// always produce without waiting on the compositor.
Scope {
    id: root

    readonly property string focusedOutput: Niri.focusedOutputName

    function isFull(name: string): bool {
        if (!Settings.options.lock.focusedOutputOnly) {
            return true;
        }
        // Before niri has named a focused output (or on an output it no longer
        // reports) fall back to showing the prompt rather than hiding it.
        return focusedOutput.length === 0 || name === focusedOutput;
    }

    WlSessionLock {
        id: sessionLock

        locked: Lock.locked

        WlSessionLockSurface {
            id: surface

            // Never transparent: there is nothing behind a lock surface to
            // show, and a compositor is free to ignore the attempt anyway.
            color: "black"

            // This output's frozen desktop, if the entry capture delivered
            // one. Cleared when the entry circle lands, which is also what
            // unloads the cover below.
            readonly property var entryStill: Lock.desktopStills[surface.screen ? surface.screen.name : ""] || null

            LockScene {
                id: scene

                anchors.fill: parent
                screenName: surface.screen ? surface.screen.name : ""
                full: root.isFull(surface.screen ? surface.screen.name : "")
            }

            // The entry circle: the desktop still, drawn ABOVE the scene and
            // clipped to the shrinking circle. Everything it paints is on
            // top, so every failure — a lost grab, a still that never
            // decoded — resolves to transparency and a plain cut to the
            // scene, never to a hole. It takes nothing from the scene
            // either: no handlers, and focus stays below, so a keystroke
            // mid-sweep wakes the prompt under the circle.
            Loader {
                anchors.fill: parent
                active: surface.entryStill !== null
                sourceComponent: entryCover
            }

            Component {
                id: entryCover

                Item {
                    id: cover

                    Image {
                        id: deskStill

                        anchors.fill: parent
                        visible: false
                        cache: false
                        source: surface.entryStill ? surface.entryStill.url : ""
                    }

                    ShaderEffect {
                        anchors.fill: parent

                        property variant still: deskStill
                        property vector2d centre: Qt.vector2d(0.5, LockMotion.sweepOriginYCqh / 100)
                        // A real lock surface is born at 0x0; radius 0 keeps
                        // the cover transparent until geometry lands.
                        property real radius: cover.width > 0 ? Math.max(0, Lock.deskHole * LockMotion.fullRadius(cover.width, cover.height)) / cover.width : 0
                        property real aspect: cover.width > 0 ? cover.height / cover.width : 1
                        property real feather: cover.width > 0 ? 1.0 / cover.width : 0

                        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/qsb/lock_desk.frag.qsb")
                    }
                }
            }

            // The unlock sweep's cover is this surface's own last look: the
            // scene is grabbed as an image — an offscreen render of the one
            // window the compositor is still drawing, so it cannot stall —
            // and handed to the exit windows to hold under the growing
            // circle. A grab that cannot even be scheduled answers with null
            // so the unlock never waits for a callback that will not come.
            Connections {
                target: Lock

                function onSweepSnapshotWanted() {
                    var name = surface.screen ? surface.screen.name : "";
                    if (!scene.grabToImage(function (grab) {
                        Lock.deliverSweepSnapshot(name, grab);
                    })) {
                        Lock.deliverSweepSnapshot(name, null);
                    }
                }
            }
        }
    }

    Binding {
        target: Lock
        property: "secure"
        value: sessionLock.secure
    }

    // ---- the sweep surfaces ----------------------------------------------

    Variants {
        model: Lock.sweepActive ? Quickshell.screens : []

        PanelWindow {
            id: sweep

            required property var modelData

            readonly property string outputName: modelData ? modelData.name : ""
            readonly property real fullRadius: LockMotion.fullRadius(width, height)
            // Which sweep this window is raised for. The state machine always
            // passes through "" between the two, so a window only ever serves
            // one mode in its lifetime.
            readonly property bool entering: Lock.sweepMode === "enter"

            screen: modelData
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "lyingshell-lock-sweep-" + outputName
            // The capture runs before the session is locked, so its window
            // holds the keyboard itself: a keystroke aimed at the screen must
            // not reach whatever is still on the desktop underneath. Once the
            // lock is taken the compositor owns focus, and the exit sweep
            // runs over a live desktop it must never take anything from.
            WlrLayershell.keyboardFocus: entering && !Lock.locked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Entry covers the desktop and blocks its input; exit is
            // click-through from its first frame, so it can never swallow the
            // unlocked desktop's clicks.
            mask: entering ? null : blockNothing

            // Parked the moment the lock is requested: the frozen still this
            // window holds is already committed, and nothing may force
            // renders onto a surface that gets no frame callbacks (see
            // RENDERING SAFETY above). The exit window never trips this — it
            // is created while locked precisely so its one hidden frame is a
            // fresh window's first — but it stays static until the lock
            // drops regardless.
            updatesEnabled: !(entering && Lock.locked)

            Region {
                id: blockNothing

                item: nothing
            }

            Item {
                id: nothing

                width: 0
                height: 0
            }

            Loader {
                anchors.fill: parent
                active: sweep.entering
                sourceComponent: captureCover
            }

            Loader {
                anchors.fill: parent
                active: !sweep.entering
                sourceComponent: exitSweep
            }

            Component {
                id: captureCover

                Item {
                    id: live

                    // One frozen frame of this output's desktop. The view
                    // paints it over the live desktop the moment it lands —
                    // they are identical, so nothing visibly changes — and
                    // that cover is what carries the handoff: niri keeps
                    // drawing this window until its lock surfaces are ready,
                    // and the lock surfaces open on the same still.
                    ScreencopyView {
                        id: capture

                        anchors.fill: parent
                        captureSource: sweep.modelData
                        live: false
                        paintCursor: false

                        // The view captures its first frame on its own
                        // schedule — an explicit captureFrame() before the
                        // recording context is ready is refused — so
                        // hasContent is the signal that the frame landed. The
                        // grab is one offscreen render of a window the
                        // compositor is actively drawing; a grab that cannot
                        // even be scheduled answers with null so the lock
                        // never waits for a callback that will not come.
                        onHasContentChanged: {
                            if (!hasContent || live.delivered) {
                                return;
                            }
                            live.delivered = true;
                            if (!capture.grabToImage(function (grab) {
                                Lock.deliverDesktopStill(sweep.outputName, grab);
                            })) {
                                Lock.deliverDesktopStill(sweep.outputName, null);
                            }
                        }
                    }

                    property bool delivered: false
                }
            }

            Component {
                id: exitSweep

                Item {
                    id: still

                    // The frozen hello pose, grabbed from this output's real
                    // lock surface. A missing grab (the bail path) leaves the
                    // source empty and the sweep on this output degrades to a
                    // plain cut — never to a wait.
                    readonly property var grab: Lock.sweepSnapshots[sweep.outputName] || null

                    Image {
                        id: pose

                        anchors.fill: parent
                        visible: false
                        cache: false
                        source: still.grab ? still.grab.url : ""
                    }

                    ShaderEffect {
                        anchors.fill: parent

                        property variant scene: pose
                        property vector2d centre: Qt.vector2d(0.5, LockMotion.sweepOriginYCqh / 100)
                        property real radius: Math.max(0, Lock.deskHole * sweep.fullRadius) / sweep.width
                        property real aspect: sweep.height / sweep.width
                        property real feather: 1.0 / sweep.width

                        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/qsb/lock_sweep.frag.qsb")
                    }

                    // The first presented frame means the cover is committed
                    // on the compositor's side; report it so the release can
                    // follow the moment every output has one. Not while the
                    // still is decoding: the frame reported must carry the
                    // cover, not a blank the cover then replaces.
                    property bool announced: false

                    Connections {
                        target: still.Window.window
                        enabled: !still.announced && pose.status !== Image.Loading

                        function onFrameSwapped() {
                            still.announced = true;
                            Lock.sweepSurfacePainted();
                        }
                    }
                }
            }
        }
    }
}
