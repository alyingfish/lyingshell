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
//   lock    the sweep surface paints the lock scene with a circular hole in
//           it, over the real live desktop. The hole shrinks into the avatar's
//           spot, so the desktop is what shrinks; when it reaches nothing the
//           session lock is taken and the real surfaces come up on the same
//           scene, already at rest.
//   unlock  the sweep surface paints the frozen success pose, the lock is
//           released, and the hole grows back out of the avatar over a desktop
//           that is live rather than a still.
//
// The visible result is the prototype's: a circle of desktop, centred on the
// avatar, riding above a lock scene that never moves. What differs is which
// layer carries the hole, and that the session is only strictly locked for the
// second half of the entry gesture — see the note in Services/Lock.qml.
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
                anchors.fill: parent
                screenName: surface.screen ? surface.screen.name : ""
                full: root.isFull(surface.screen ? surface.screen.name : "")
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

            screen: modelData
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "lyingshell-lock-sweep-" + outputName
            // The entry sweep runs before the session is locked, so it holds
            // the keyboard itself: a keystroke aimed at the screen must not
            // reach whatever is still on the desktop underneath. Once the lock
            // is taken the compositor owns focus and this must not compete.
            WlrLayershell.keyboardFocus: Lock.locked ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Click-through the moment it stops painting, so a surface left
            // alive by a mistake can never swallow the desktop's input.
            mask: Lock.sweepPainting ? null : blockNothing

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
            LockScene {
                id: sweepScene

                anchors.fill: parent
                screenName: sweep.outputName
                full: root.isFull(sweep.outputName)
                // A copy, never the thing being driven: the real surface
                // underneath owns focus, keys and clicks.
                interactive: false
            }

            // `hideSource` keeps the scene itself off the screen; the shader
            // below is what puts it there, minus the circle.
            ShaderEffectSource {
                id: sceneTexture

                anchors.fill: parent
                sourceItem: sweepScene
                live: Lock.sweepPainting
                hideSource: true
                visible: false
            }

            ShaderEffect {
                anchors.fill: parent
                visible: Lock.sweepPainting

                property variant scene: sceneTexture
                // Centred on where the avatar RESTS, not where its approach
                // transform has it mid-flight.
                property vector2d centre: Qt.vector2d(sweepScene.sweepOriginX / sweep.width, sweepScene.sweepOriginY / sweep.height)
                // In width units, and free to overshoot the screen corners: the
                // curve runs past 1, which is what finishes the visible travel
                // early on its fast half.
                property real radius: Math.max(0, Lock.deskHole * sweep.fullRadius) / sweep.width
                property real aspect: sweep.height / sweep.width
                property real feather: 1.0 / sweep.width

                fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/qsb/lock_sweep.frag.qsb")
            }
        }
    }
}
