import QtQuick
import QtQuick.Shapes
import Qcm.Material as MD
import qs.Commons.Settings
import qs.Services.Niri
import "AutoShape.js" as AutoShape

// Animated Bar background surface. One CurveRenderer Shape whose path, MD3
// elevation shadow, and fill opacity are driven by scalar properties. Each
// scalar binds to the active shape's target value AND has a Behavior, so
// switching `Settings.options.bar.currentShape` morphs smoothly. The `hug` shape
// extends its bottom-left/right edges downward and closes them with inner
// reversed (concave) fillets. `blurSigma`/`blurEnabled` feed the owner window's
// BackgroundEffect (best-effort; a no-op where the compositor lacks
// ext-background-effect-v1, e.g. current Niri).
Item {
    id: root

    // Bar thickness (content band height) supplied by the owning window.
    property real barHeight: 32

    // Output this bar lives on; needed for per-output autoShape resolution.
    property string outputName: ""
    // ponytail: inert until a lock signal exists (no lock module / niri IPC
    // does not expose session-lock). lockscreenShape never matches today.
    property bool locked: false

    // When currentShape is "autoShape", select a concrete shape per-output from
    // live Niri state; otherwise pass the setting through. `width` is the output
    // logical width (the bar spans the whole output) used for the maximized-
    // column heuristic. Touch Niri.lastEventVersion so the binding re-evaluates
    // on every Niri state change: QML property capture does NOT see the Niri.*
    // reads that happen inside the .pragma library resolve(), so without this
    // the shape would freeze. Every downstream scalar animates via its Behavior.
    readonly property string shape: {
        if (Settings.options.bar.currentShape !== "autoShape")
            return Settings.options.bar.currentShape;
        void Niri.lastEventVersion;
        return AutoShape.resolve(Settings.options.bar.autoShape, Niri, outputName, locked, width);
    }
    readonly property var shapeOptions: Settings.options.bar.shape
    readonly property bool isHidden: shape === "hidden"

    // The last non-hidden shape, so `hidden` keeps the current geometry while it
    // slides away instead of first morphing to fullWidth.
    property string lastVisibleShape: "floating"
    onShapeChanged: if (shape !== "hidden")
        lastVisibleShape = shape

    // Active shape (held at the last visible one while hidden) and its uniform
    // settings object. Fall back to fullWidth for an unknown currentShape.
    readonly property string activeShape: isHidden ? lastVisibleShape : shape
    readonly property var config: shapeOptions[activeShape] || shapeOptions.fullWidth

    // Where the shape's single `radius` lands: floating/fullWidth round all
    // corners, softAttach only the bottom, hug turns it into reversed concave
    // wings (top/bottom stay square).
    readonly property real reversedTarget: activeShape === "hug" ? config.radius : 0

    // Extra vertical room kept below the bar so the elevation shadow and the hug
    // overhang are not clipped by the layer surface. This region is click-through
    // (see Bar.qml mask), so the headroom is free.
    readonly property real shadowBuffer: 24

    // ---- Animated scalars (binding target + Behavior == smooth morph) ----
    property real animMargin: config.margin
    property real animTopRadius: activeShape === "softAttach" || activeShape === "hug" ? 0 : config.radius
    property real animBottomRadius: activeShape === "hug" ? 0 : config.radius
    property real animReversed: reversedTarget
    property real animOpacity: config.opacity
    property real revealOffset: isHidden ? -(animMargin + barHeight + shadowBuffer + 8) : 0

    // MD3 elevation (dp) feeding RRectShadowImpl, animated so depth tweens with
    // the morph. The fade MUST ride on elevation, not color alpha: RRectShadowImpl
    // drops the color alpha before rendering, so an alpha fade is a no-op.
    property real shadowElevation: config.elevation

    // Best-effort background blur (compositor effect; not animated).
    readonly property real blurSigma: config.blur
    readonly property bool blurEnabled: blurSigma > 0

    Behavior on animMargin {
        NumberAnimation {
            duration: MD.Token.duration.medium2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on animTopRadius {
        NumberAnimation {
            duration: MD.Token.duration.medium2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on animBottomRadius {
        NumberAnimation {
            duration: MD.Token.duration.medium2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on animReversed {
        NumberAnimation {
            duration: MD.Token.duration.medium2
            easing: MD.Token.easing.emphasized
        }
    }
    Behavior on animOpacity {
        NumberAnimation {
            duration: MD.Token.duration.medium2
            easing: MD.Token.easing.standard
        }
    }
    Behavior on shadowElevation {
        NumberAnimation {
            duration: MD.Token.duration.medium2
            easing: MD.Token.easing.standard
        }
    }
    Behavior on revealOffset {
        NumberAnimation {
            duration: MD.Token.duration.long2
            easing: MD.Token.easing.emphasized
        }
    }

    // ---- Derived surface rectangle within this item ----
    // Keep room below the bar for the shadow and the hug overhang. The surface
    // tracks the *fractional* animMargin so the slide is continuous (sub-pixel)
    // — rounding it here makes an N-px slide N discrete 1px jumps, i.e. visible
    // stepping. The wobble that fractional geometry caused on centered content
    // is fixed where it originates (Bar.qml centers with a non-rounding binding
    // instead of the anchor, which rounds), so geometry can stay smooth here.
    readonly property real totalHeight: animMargin + barHeight + Math.max(shadowBuffer, reversedTarget + 4)
    readonly property real surfaceX: animMargin
    readonly property real surfaceY: animMargin + revealOffset
    readonly property real surfaceWidth: Math.max(0, width - animMargin * 2)
    readonly property real surfaceHeight: barHeight

    // One continuous CurveRenderer path for every shape. Top corners are convex
    // (`animTopRadius`). The bottom is a single SIGNED value
    // `animBottomRadius - animReversed`: positive draws convex corners
    // (floating/softAttach/fullWidth), negative draws reversed concave wings
    // that extend below the baseline (hug). Sweeping through 0 (square) makes
    // every transition — including hug<->convex shapes — morph continuously.
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

    // MD3 elevation shadow, drawn behind the fill. QmlMaterial's RRectShadowImpl
    // is the Skia ambient + spot model (soft ambient base + a downward-projected
    // directional shadow), so it reads as natural depth rather than a flat halo.
    // Driven by corner radii from the same animated scalars as the fill, so the
    // shadow tracks the floating<->softAttach morph. The user-configurable
    // per-shape `elevation` (animated via root.shadowElevation) sets the depth:
    // the shadow grows/shrinks with it, and a shape whose elevation is 0 renders
    // no shadow. The color stays full-alpha so the component can apply its own
    // ambient/spot opacities. `visible` culls once the depth eases to ~0.
    MD.RRectShadowImpl {
        x: root.surfaceX
        y: root.surfaceY
        width: root.surfaceWidth
        height: root.surfaceHeight
        visible: root.shadowElevation > 0.001
        // The Skia shadow keeps a constant peak alpha as elevation drops (only
        // its spread shrinks), so at low elevation it's a thin, still-dark band
        // that `visible` then hard-culls — a pop, made visible here only because
        // the bar fill is translucent (an opaque fill, like ElevationRectangle,
        // hides it). Fade the whole shadow out over the last ~1.5dp via item
        // opacity, which the shader honors. The shader cubes qt_Opacity
        // (pow(opacity,3)), so cbrt it here to get a fade that's linear in
        // elevation rather than a cliff near the top of the ramp.
        opacity: Math.cbrt(Math.min(1, root.shadowElevation / 1.5))
        elevation: root.shadowElevation
        corners: MD.Util.corners(root.animTopRadius, root.animTopRadius, Math.max(0, root.animBottomRadius), Math.max(0, root.animBottomRadius))

        color: MD.Token.color.shadow
    }

    // Surface fill, painted once on top of the shadow.
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
