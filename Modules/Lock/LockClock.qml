import QtQuick
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Services

import "../../Material/Motion.js" as Motion

// The two-tone stacked clock: hours in `primary` over minutes in `tertiary`,
// each line centred on the other, proportional figures.
//
// It grows and shrinks on the MD3 Expressive slow spatial spring, which is the
// role a hero-sized change belongs to. The glyphs are laid out once at their
// largest size and CurveRendering keeps their outlines vector-sharp while the
// block transforms down. Scaling from the largest pose never magnifies a
// small glyph cache, and avoids the integer steps of `font.pixelSize`.
//
// Minimized it is also the way back out: the crown answers a click by
// returning the room to glance (Lock.back()), and hovering tugs it toward full
// size to preview that.
Item {
    id: root

    // 1% of the surface, the unit the whole scene is drawn in.
    required property real cqh
    required property real cqw
    // Where the crown has to land: one identity step above the avatar's centre.
    required property real crownCentreY

    // Fed by the scene rather than read off the state machine: an output that
    // carries no prompt keeps its clock full size whatever the prompt is doing
    // on the output that does.
    required property bool minimized
    required property bool returnable

    readonly property real fullSize: 26.5 * cqh
    readonly property real crownSize: fullSize * 0.24
    // Hovering the door out tugs it toward full size, previewing the click.
    readonly property real hoverSize: fullSize * 0.265
    readonly property real lineHeightScale: 0.80

    // Keep these dimensionless constants valid while a lock surface is still
    // 0x0; deriving 0 / 0 here would poison its first mapped frame with NaN.
    readonly property real crownScale: 0.24
    readonly property real hoverScale: 0.265
    // ζ 0.8 peaks at ~1.5% beyond its target. The fixed pointer target covers
    // that whole pose plus the glyph ink which intentionally overhangs the
    // tight 0.80 line boxes.
    readonly property real hoverOvershootScale: hoverScale * 1.016
    readonly property real glyphOverhang: Math.max(0, hoursDigits.contentHeight - hoursDigits.height, minutesDigits.contentHeight - minutesDigits.height) / 2
    readonly property real targetPose: minimized ? 0 : 1
    readonly property real targetHover: minimized && returnable && hover.hovered ? 1 : 0

    // Both poses are pinned by their top edge. One dimensionless pose drives
    // the size and the travel, so they cannot desynchronize. Surface geometry
    // is applied after that pose: when a WlSessionLockSurface is constructed
    // at 0x0 and then receives its screen, cqh changes without starting a fake
    // 0px -> full-size animation at the sweep/session-lock handoff.
    readonly property real crownTop: crownCentreY - crownSize * lineHeightScale
    readonly property real fullTop: 25 * cqh
    readonly property real blockY: crownTop + (fullTop - crownTop) * pose

    // `pose` is the hero transition. `hoverPose` is separate because hover
    // changes only size, never the crown's top. Both are real springs rather
    // than duration-based Bezier replays: retargeting keeps current velocity,
    // as M3's interactive-motion guidance requires.
    property real pose: 1
    property real poseVelocity: 0
    property real hoverPose: 0
    property real hoverVelocity: 0
    property bool springReady: false

    readonly property real clockScale: crownScale + (1 - crownScale) * pose + (hoverScale - crownScale) * hoverPose * (1 - pose)
    readonly property bool poseAtRest: Math.abs(pose - targetPose) < 0.0005 && Math.abs(poseVelocity) < 0.005
    readonly property bool hoverAtRest: Math.abs(hoverPose - targetHover) < 0.0005 && Math.abs(hoverVelocity) < 0.005
    readonly property bool animating: springClock.running
    readonly property bool hovered: hover.hovered

    function snapToTargets() {
        pose = targetPose;
        poseVelocity = 0;
        hoverPose = targetHover;
        hoverVelocity = 0;
    }

    onTargetPoseChanged: if (springReady && Settings.options.appearance.reducedMotion)
        snapToTargets()
    onTargetHoverChanged: if (springReady && Settings.options.appearance.reducedMotion)
        snapToTargets()

    Connections {
        target: Settings.options.appearance

        function onReducedMotionChanged() {
            if (Settings.options.appearance.reducedMotion) {
                root.snapToTargets();
            }
        }
    }

    FrameAnimation {
        id: springClock

        running: root.springReady && !Settings.options.appearance.reducedMotion && (!root.poseAtRest || !root.hoverAtRest)

        onTriggered: {
            if (!root.poseAtRest) {
                var mainStep = Motion.stepSpring(root.pose, root.poseVelocity, root.targetPose, Motion.spatialSlow, frameTime);
                root.pose = mainStep.value;
                root.poseVelocity = mainStep.velocity;
                if (root.poseAtRest) {
                    root.pose = root.targetPose;
                    root.poseVelocity = 0;
                }
            }
            if (!root.hoverAtRest) {
                var hoverStep = Motion.stepSpring(root.hoverPose, root.hoverVelocity, root.targetHover, Motion.spatialDefault, frameTime);
                root.hoverPose = hoverStep.value;
                root.hoverVelocity = hoverStep.velocity;
                if (root.hoverAtRest) {
                    root.hoverPose = root.targetHover;
                    root.hoverVelocity = 0;
                }
            }
        }
    }

    // The hit target is the digits, not a band across the screen.
    width: column.width
    height: column.height
    x: (parent.width - width) / 2
    y: blockY

    // The two lines are set on a 0.80 line box, which is tighter than the
    // glyphs: the digits' own ascent and descent overhang it and the pair reads
    // as one stacked mass. Qt's `lineHeight` only spaces lines INSIDE one Text
    // item, so the box is given here instead and the glyphs are centred in it —
    // which is exactly what CSS line-height does to a one-line block.
    component Digits: Text {
        required property color ink

        color: ink
        font.family: Theme.textTypeface
        font.pixelSize: root.fullSize
        font.weight: 700
        font.letterSpacing: -0.028 * root.fullSize
        // Proportional figures: the two lines are read as one shape, and
        // tabular slots leave the narrow digits swimming in their cells.
        font.features: ({
                "tnum": 0,
                "pnum": 1
            })
        renderType: Text.CurveRendering
        height: root.fullSize * root.lineHeightScale
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Column {
        id: column

        scale: root.clockScale
        transformOrigin: Item.Top

        Digits {
            id: hoursDigits

            ink: LockTheme.clockHours
            text: Time.format(I18n.t("lock.hourFormat"))
        }

        Digits {
            id: minutesDigits

            ink: LockTheme.clockMinutes
            text: Time.format(I18n.t("lock.minuteFormat"))
        }
    }

    // A fixed target encloses the largest hover pose. The visual glyph bounds
    // never feed their own hover state, so expanding or spring overshoot cannot
    // move the pointer across the target edge and make the clock oscillate.
    Item {
        id: hitTarget

        x: (root.width - width) / 2
        y: -root.glyphOverhang * root.hoverOvershootScale
        width: column.width * root.hoverOvershootScale
        height: (column.height + 2 * root.glyphOverhang) * root.hoverOvershootScale

        HoverHandler {
            id: hover

            enabled: root.returnable
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: root.returnable

            onTapped: Lock.back()
        }
    }

    Component.onCompleted: {
        snapToTargets();
        springReady = true;
    }
}
