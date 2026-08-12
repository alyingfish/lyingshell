import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Services
import qs.Material

import "../../Material/Motion.js" as Motion

// The two-tone stacked clock: hours in `primary` over minutes in `tertiary`,
// each line centred on the other, proportional figures.
//
// It grows and shrinks on ONE spring — the MD3 Expressive slow spatial spring,
// which is the role a hero-sized change belongs to — and what travels on that
// spring is the TYPE SIZE, not `scale`. A Text item rasterizes its glyphs once
// at layout size; scaling that texture up blows a 68px cache entry across a
// 286px block and the digits go soft. Animating pixelSize re-lays the text
// every frame instead, so every frame is drawn sharp at the size it is shown.
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

    readonly property real targetSize: minimized ? (returnable && hover.hovered ? hoverSize : crownSize) : fullSize
    // Full size hangs from 25cqh; minimized, the block's centre is what has to
    // land on crownCentreY, so the two poses are declared the way each is
    // actually anchored rather than as one number plus an offset.
    readonly property real targetY: minimized ? crownCentreY - fontSize * lineHeightScale : 25 * cqh

    // The one animated pair. Both ride the same spring so the crown never
    // arrives before the ink has finished shrinking into it.
    property real fontSize: root.targetSize
    property real blockY: root.targetY

    Behavior on fontSize {
        MotionAnimation {
            spring: Motion.spatialSlow
        }
    }
    Behavior on blockY {
        MotionAnimation {
            spring: Motion.spatialSlow
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
        font.pixelSize: root.fontSize
        font.weight: root.minimized ? 560 : 700
        font.letterSpacing: -0.028 * root.fontSize
        // Proportional figures: the two lines are read as one shape, and
        // tabular slots leave the narrow digits swimming in their cells.
        font.features: ({
                "tnum": 0,
                "pnum": 1
            })
        height: root.fontSize * root.lineHeightScale
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Column {
        id: column

        Digits {
            ink: LockTheme.clockHours
            text: Time.format(I18n.t("lock.hourFormat"))
        }

        Digits {
            ink: LockTheme.clockMinutes
            text: Time.format(I18n.t("lock.minuteFormat"))
        }
    }

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
