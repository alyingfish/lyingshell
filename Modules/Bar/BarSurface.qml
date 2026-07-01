import QtQuick
import QtQuick.Shapes
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Services.Niri
import "AutoShape.js" as AutoShape

// Animated Bar surface: one CurveRenderer Shape whose scalars each bind to the
// active shape's target and have a Behavior, so switching currentShape morphs.
Item {
    id: root

    property real barHeight: 32

    // Output for per-output autoShape resolution.
    property string outputName: ""
    // ponytail: inert until a lock signal exists (no lock module / niri IPC
    // does not expose session-lock). lockscreenShape never matches today.
    property bool locked: false

    // Touch Niri.lastEventVersion so the binding re-runs on Niri changes: QML
    // capture can't see the Niri.* reads inside resolve()'s .pragma library.
    readonly property string shape: {
        if (Settings.options.bar.currentShape !== "autoShape")
            return Settings.options.bar.currentShape;
        void Niri.lastEventVersion;
        return AutoShape.resolve(Settings.options.bar.autoShape, Niri, outputName, locked, width);
    }
    readonly property var shapeOptions: Settings.options.bar.shape
    readonly property bool isHidden: shape === "hidden"

    // Last non-hidden shape, so `hidden` keeps its geometry while sliding away.
    property string lastVisibleShape: "floating"
    onShapeChanged: if (shape !== "hidden")
        lastVisibleShape = shape

    readonly property string activeShape: isHidden ? lastVisibleShape : shape
    readonly property var config: shapeOptions[activeShape] || shapeOptions.fullWidth

    readonly property real reversedTarget: activeShape === "hug" ? config.radius : 0

    // Settled radius for content insets; consumers animate it. Clamping the eased
    // radius (max(8, animRadius)) instead clips the ease and kinks the motion.
    readonly property real contentRadiusTarget: activeShape === "hug" ? 0 : config.radius

    // Click-through headroom below the bar for the shadow and hug overhang.
    readonly property real shadowBuffer: 24

    property real animMargin: config.margin
    property real animTopRadius: activeShape === "softAttach" || activeShape === "hug" ? 0 : config.radius
    property real animBottomRadius: activeShape === "hug" ? 0 : config.radius
    property real animReversed: reversedTarget
    property real animOpacity: config.opacity
    property real revealOffset: isHidden ? -(animMargin + barHeight + shadowBuffer + 8) : 0

    // Fade MUST ride on elevation: RRectShadowImpl drops color alpha pre-render.
    property real shadowElevation: config.elevation

    // Best-effort background blur (compositor effect; not animated).
    readonly property real blurSigma: config.blur
    // Keep blur alive while the surface is still translucent so it doesn't pop
    // off at frame 0 of a morph to an opaque shape: blur is only visible while
    // opacity < 1 anyway, so it fades in/out in lockstep with the opacity morph.
    readonly property bool blurEnabled: blurSigma > 0 || animOpacity < 0.999

    Behavior on animMargin {
        NumberAnimation {
            duration: MD.Token.duration.long2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on animTopRadius {
        NumberAnimation {
            duration: MD.Token.duration.long2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on animBottomRadius {
        NumberAnimation {
            duration: MD.Token.duration.long2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on animReversed {
        NumberAnimation {
            duration: MD.Token.duration.long2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on animOpacity {
        NumberAnimation {
            duration: MD.Token.duration.long2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on shadowElevation {
        NumberAnimation {
            duration: MD.Token.duration.long2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on revealOffset {
        NumberAnimation {
            duration: MD.Token.duration.long2
            easing: MD.Token.easing.emphasized
        }
    }

    // Track fractional animMargin (no rounding) so the slide stays sub-pixel
    // smooth; centered-content wobble is handled in Bar.qml's centering binding.
    readonly property real totalHeight: animMargin + barHeight + Math.max(shadowBuffer, reversedTarget + 4)
    readonly property real surfaceX: animMargin
    readonly property real surfaceY: animMargin + revealOffset
    readonly property real surfaceWidth: Math.max(0, width - animMargin * 2)
    readonly property real surfaceHeight: barHeight

    // Bottom radius is signed (animBottomRadius - animReversed): positive = convex
    // corners, negative = concave hug wings. Sweeping through 0 morphs continuously.
    function surfacePath(w, h) {
        const lim = Math.min(w / 2, h);
        const tr = Math.max(0, Math.min(animTopRadius, lim));
        const tl = tr;
        const signed = animBottomRadius - animReversed;
        const convex = signed >= 0;
        const b = Math.max(0, Math.min(Math.abs(signed), lim));

        let p = "M " + tl + " 0";
        p += " L " + (w - tr) + " 0";
        p += (tr > 0.01) ? (" A " + tr + " " + tr + " 0 0 1 " + w + " " + tr) : (" L " + w + " 0");
        if (convex) {
            p += " L " + w + " " + (h - b);
            p += (b > 0.01) ? (" A " + b + " " + b + " 0 0 1 " + (w - b) + " " + h) : (" L " + w + " " + h);
            p += " L " + b + " " + h;
            p += (b > 0.01) ? (" A " + b + " " + b + " 0 0 1 0 " + (h - b)) : (" L 0 " + h);
        } else {
            p += " L " + w + " " + (h + b);
            p += (b > 0.01) ? (" A " + b + " " + b + " 0 0 0 " + (w - b) + " " + h) : (" L " + w + " " + h);
            p += " L " + b + " " + h;
            p += (b > 0.01) ? (" A " + b + " " + b + " 0 0 0 0 " + (h + b)) : (" L 0 " + h);
        }
        p += " L 0 " + tl;
        p += (tl > 0.01) ? (" A " + tl + " " + tl + " 0 0 1 " + tl + " 0") : (" L 0 0");
        return p + " Z";
    }

    // MD3 elevation shadow behind the fill; radii/depth animate with it.
    MD.RRectShadowImpl {
        x: root.surfaceX
        y: root.surfaceY
        width: root.surfaceWidth
        height: root.surfaceHeight
        visible: root.shadowElevation > 0.001
        // Skia keeps peak alpha as elevation drops, so fade the band out over the
        // last ~1.5dp; shader cubes qt_Opacity, hence cbrt for a linear fade.
        opacity: Math.cbrt(Math.min(1, root.shadowElevation / 1.5))
        elevation: root.shadowElevation
        corners: MD.Util.corners(root.animTopRadius, root.animTopRadius, Math.max(0, root.animBottomRadius), Math.max(0, root.animBottomRadius))

        color: MD.Token.color.shadow
    }

    MD.Shape {
        id: surfaceFill

        x: root.surfaceX
        y: root.surfaceY
        width: root.surfaceWidth
        height: root.surfaceHeight

        ShapePath {
            readonly property color base: MD.Token.color.surface_container

            strokeWidth: 0
            fillColor: Qt.rgba(base.r, base.g, base.b, root.animOpacity)

            PathSvg {
                path: root.surfacePath(root.surfaceWidth, root.surfaceHeight)
            }
        }
    }
}
