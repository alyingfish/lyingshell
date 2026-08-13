import QtQuick
import QtQuick.Shapes
import Quickshell
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Services
import qs.Material

import "../../Material/Motion.js" as Motion
import "LockMotion.js" as LockMotion

// The portrait, clipped by a twelve-lobe scallop that turns slowly — Material's
// turning-shape motif.
//
// THE MASK TURNS, NOT THE PICTURE. The prototype spins a clipped frame and
// gives the <img> inside it an equal counter-spin, because a CSS clip-path is
// applied in the element's own coordinates and turning the element turns the
// clip with it. That counter-turn is a workaround for the CSS model, not part
// of the design, and it is not ported: here the edge is evaluated at a rotated
// angle in the fragment shader, so the rim travels while the face underneath
// never moves at all. See assets/shaders/frag/lock_scallop.frag.
//
// The avatar is not interactive on the lock screen: the account is already
// known. No hover ring, no chevrons, no hover scale — those belong to the
// greeter's user picker, which is out of scope.
Item {
    id: root

    required property real cqw
    property real shakeOffset: 0

    readonly property string portrait: Lock.accountAvatar
    readonly property bool hasPortrait: portrait.length > 0 && portraitImage.status === Image.Ready

    readonly property string initial: {
        var name = Lock.displayName;
        return name.length > 0 ? name.charAt(0).toUpperCase() : "?";
    }

    // 0.10 is the scallop; 0 is a circle of the same diameter, because the
    // curve is normalized so its crests never move.
    property real amplitude: Lock.succeeded ? 0 : 0.10
    property real successFill: Lock.succeeded ? 1 : 0
    property real turn: 0

    Behavior on amplitude {
        NumberAnimation {
            duration: LockMotion.avatarMorphMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spatialSlow.curve
        }
    }
    Behavior on successFill {
        MotionAnimation {
            spring: Motion.effectsFast
        }
    }

    // One slow turn, stopped where it stands the moment the password lands.
    NumberAnimation on turn {
        running: !Lock.succeeded
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: LockMotion.scallopTurnMs
    }

    transform: Translate {
        x: root.shakeOffset
    }

    ShakeAnimation {
        id: shake

        item: root
        unit: root.cqw
    }

    Connections {
        target: Lock

        function onShakeGenerationChanged() {
            if (Settings.options.appearance.reducedMotion) {
                return;
            }
            shake.restart();
        }
    }

    // ---- what gets clipped -----------------------------------------------
    // Drawn once into a texture and never shown where it stands: the shader is
    // what puts it on screen. The success fill rides in here with everything
    // else, so it arrives already wearing the shape the shape is morphing into.
    Item {
        id: plate

        anchors.fill: parent

        // The fallback plate when no portrait is configured: the palette's own
        // container pair on the prototype's 150° axis.
        MD.Shape {
            anchors.fill: parent
            visible: !root.hasPortrait
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0

                fillGradient: LinearGradient {
                    // CSS 150deg: 0deg points up and angles run clockwise, so
                    // the line travels down-and-right through the centre.
                    x1: 0.1585 * plate.width
                    y1: -0.0915 * plate.height
                    x2: 0.8415 * plate.width
                    y2: 1.0915 * plate.height

                    GradientStop {
                        position: 0
                        color: MD.Token.color.primary_container
                    }
                    GradientStop {
                        position: 1
                        color: MD.Token.color.tertiary_container
                    }
                }

                PathRectangle {
                    width: plate.width
                    height: plate.height
                }
            }
        }

        Image {
            id: portraitImage

            anchors.fill: parent
            source: root.portrait
            visible: root.hasPortrait
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            mipmap: true
            sourceSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
        }

        Rectangle {
            anchors.fill: parent
            color: MD.Token.color.primary
            opacity: root.successFill
        }
    }

    // `hideSource` keeps the plate off the screen, and the provider itself is
    // invisible — an invisible ShaderEffectSource still keeps its texture live,
    // which is what lets the clipped result be the only thing drawn.
    ShaderEffectSource {
        id: plateTexture

        anchors.fill: parent
        sourceItem: plate
        hideSource: true
        live: true
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent

        property variant source: plateTexture
        property real lobes: 12
        property real amp: root.amplitude
        property real turn: root.turn * Math.PI / 180
        // One pixel of edge, in the shader's own units (the box is 1 unit wide).
        property real feather: 1.0 / Math.max(1, width)

        fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/qsb/lock_scallop.frag.qsb")
    }

    // ---- the marks, never clipped and never tilted -----------------------

    MD.Text {
        anchors.centerIn: parent
        visible: !root.hasPortrait && root.successFill < 0.5
        text: root.initial
        color: MD.Token.color.on_primary_container
        font.pixelSize: root.height * 0.42
        font.weight: 640
    }

    MD.Icon {
        id: check

        anchors.centerIn: parent
        visible: Lock.succeeded
        name: "check"
        size: root.height * 0.41
        color: MD.Token.color.on_primary

        scale: 1

        SequentialAnimation on scale {
            running: check.visible
            // The pop is the one thing that says the password landed, so it
            // plays even under reduced motion: it is a morph in place, not
            // travel.
            NumberAnimation {
                from: 0.3
                to: 1.18
                duration: LockMotion.checkPopMs * 0.6
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                to: 1.0
                duration: LockMotion.checkPopMs * 0.4
                easing.type: Easing.OutCubic
            }
        }
    }
}
