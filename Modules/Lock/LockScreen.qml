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
// so the desktop cannot be shown through it, and a screencopy taken while
// locked captures the lock screen, not the desktop. The sweep therefore runs
// on ordinary layer-shell surfaces on the Overlay layer, which sit ABOVE the
// desktop and BELOW the lock:
//
//   enter   the sweep surface paints a live copy of the lock scene with a
//           circular hole in it, over the real live desktop. The hole shrinks
//           into the avatar's spot, so the desktop is what shrinks; when it
//           reaches nothing the session lock is taken and the real surfaces
//           come up on the same scene, already at rest.
//   exit    each lock surface grabs its frozen hello pose into an image, a
//           fresh window buffers that still — full cover, hole at nothing —
//           under the lock, and only then is the lock released: the
//           compositor swaps one for the other with no gap. The hole grows
//           back out of the avatar over a desktop that is live, and the
//           windows are dropped when it lands.
//
// The visible result is the prototype's: a circle of desktop, centred on the
// avatar, riding above a lock scene that never moves. What differs is which
// layer carries the hole, and that the session is only strictly locked for the
// second half of the entry gesture — see the note in Services/Lock.qml.
//
// RENDERING SAFETY: the compositor sends frame callbacks only to surfaces it
// draws, and while locked it draws nothing but the lock surfaces. A sweep
// window forced to render in that state stalls its render thread on buffers
// that are never released, and that stall can wedge the shell. Hence the
// shape of everything below: entry windows park (updatesEnabled) the moment
// the lock goes up and are destroyed once the compositor confirms coverage;
// exit windows hold a static still — nothing in them can animate on its own —
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

            LockScene {
                id: scene

                anchors.fill: parent
                screenName: surface.screen ? surface.screen.name : ""
                full: root.isFull(surface.screen ? surface.screen.name : "")
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
            // The entry sweep runs before the session is locked, so it holds
            // the keyboard itself: a keystroke aimed at the screen must not
            // reach whatever is still on the desktop underneath. Once the lock
            // is taken the compositor owns focus, and the exit sweep runs over
            // a live desktop it must never take anything from.
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

            // Parked the moment the compositor stops drawing this window: the
            // scene copy's own animations must not force renders onto a
            // surface that gets no frame callbacks (see RENDERING SAFETY
            // above). The exit window never trips this — it is created while
            // locked precisely so its one hidden frame is a fresh window's
            // first — but it stays static until the lock drops regardless.
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

            // The scene is rendered to a texture and the hole is cut in the
            // shader, rather than clipped: the alpha that comes out is what the
            // compositor blends against the desktop, so the circle is genuinely
            // empty. (QtQuick.Effects' MultiEffect mask does not produce a
            // usable texture here, and a clip cannot make a hole.)
            Loader {
                anchors.fill: parent
                active: sweep.entering
                sourceComponent: enterSweep
            }

            Loader {
                anchors.fill: parent
                active: !sweep.entering
                sourceComponent: exitSweep
            }

            Component {
                id: enterSweep

                Item {
                    id: live

                    LockScene {
                        id: sweepScene

                        anchors.fill: parent
                        screenName: sweep.outputName
                        full: root.isFull(sweep.outputName)
                        // A copy, never the thing being driven: the real
                        // surface underneath owns focus, keys and clicks.
                        interactive: false
                    }

                    // `hideSource` keeps the scene itself off the screen; the
                    // shader below is what puts it there, minus the circle.
                    ShaderEffectSource {
                        id: sceneTexture

                        anchors.fill: parent
                        sourceItem: sweepScene
                        hideSource: true
                        visible: false
                    }

                    ShaderEffect {
                        anchors.fill: parent

                        property variant scene: sceneTexture
                        // Centred on where the avatar RESTS, not where its
                        // approach transform has it mid-flight.
                        property vector2d centre: Qt.vector2d(0.5, LockMotion.sweepOriginYCqh / 100)
                        // In width units, and free to overshoot the screen
                        // corners: the curve runs past 1, which is what
                        // finishes the visible travel early on its fast half.
                        property real radius: Math.max(0, Lock.deskHole * sweep.fullRadius) / sweep.width
                        property real aspect: sweep.height / sweep.width
                        property real feather: 1.0 / sweep.width

                        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/qsb/lock_sweep.frag.qsb")
                    }

                    // The first presented frame means this output's cover is
                    // mapped; report it so the circle starts shrinking on a
                    // painted surface everywhere, not on a blind tick.
                    property bool announced: false

                    Connections {
                        target: live.Window.window
                        enabled: !live.announced

                        function onFrameSwapped() {
                            live.announced = true;
                            Lock.sweepSurfacePainted();
                        }
                    }
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
