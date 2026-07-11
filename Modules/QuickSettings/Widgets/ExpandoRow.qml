import QtQuick
import Qcm.Material as MD
import qs.Commons.Theme
import qs.Material
import "../../../Material/Motion.js" as Motion

// Expandable device row (prototype .dvi.wf): a list-row header over a
// spring-revealed body, one vessel. Rest rows sit on surface-container-high
// in the group corner rhythm (16 outer / 6 inner); expanding morphs the shape
// round (18) and lifts the tone to surface-container-highest; the selected
// row keeps secondary-container. Hero rows (the connected network / device)
// are 64px with a 40px primary icon circle whose shape echoes the expansion.
Item {
    id: row

    property string text: ""
    property string subText: ""
    property string leadingIcon: ""
    // Small glyph beside the name (prototype's 12px lock).
    property string nameBadgeIcon: ""
    // Replaces the caret with a busy spinner (connecting / pairing).
    property bool busy: false
    property bool hero: false
    // Selected (connected) row: secondary-container tone.
    property bool current: false
    property bool open: false
    // Static cards (the hotspot card) render header + body, no toggle.
    property bool expandable: true
    // Index in the page's entrance stagger.
    property int order: 0
    // Corner rhythm within a group: "single" (standalone), "first", "mid",
    // "last", "only".
    property string groupPos: "single"

    signal headerClicked

    // True until the collapse reveal has fully closed; body Loaders key off
    // this so content doesn't vanish mid-animation.
    readonly property bool revealing: open || bodyReveal.height > 0

    // Body content (prototype .wf-in), revealed while open.
    default property alias bodyData: bodyColumn.data

    readonly property real headerHeight: hero ? 64 : 46
    readonly property color contentColor: current ? MD.Token.color.on_secondary_container : MD.Token.color.on_surface
    readonly property color mutedColor: current ? MD.Util.transparent(MD.Token.color.on_secondary_container, 0.88) : MD.Token.color.on_surface_variant

    readonly property real cornerTop: hero ? (open ? 24 : 20) : open ? 18 : groupPos === "single" ? 15 : groupPos === "first" || groupPos === "only" ? 16 : 6
    readonly property real cornerBottom: hero ? (open ? 24 : 20) : open ? 18 : groupPos === "single" ? 15 : groupPos === "last" || groupPos === "only" ? 16 : 6

    width: parent ? parent.width : 0
    implicitHeight: headerHeight + bodyReveal.height

    transform: Translate {
        id: rowTy
    }

    Component.onCompleted: rowIn.restart()

    DetailRise {
        id: rowIn

        target: row
        translate: rowTy
        order: row.order
    }

    Rectangle {
        id: vessel

        anchors.fill: parent
        topLeftRadius: row.cornerTop
        topRightRadius: row.cornerTop
        bottomLeftRadius: row.cornerBottom
        bottomRightRadius: row.cornerBottom
        color: row.current ? MD.Token.color.secondary_container : row.open ? MD.Token.color.surface_container_highest : MD.Token.color.surface_container_high

        Behavior on topLeftRadius {
            MotionAnimation {}
        }

        Behavior on topRightRadius {
            MotionAnimation {}
        }

        Behavior on bottomLeftRadius {
            MotionAnimation {}
        }

        Behavior on bottomRightRadius {
            MotionAnimation {}
        }

        Behavior on color {
            MotionColorAnimation {}
        }
    }

    // --- header (prototype .wf-head) ---------------------------------------
    MD.Button {
        id: head

        width: parent.width
        implicitHeight: row.headerHeight
        flat: true
        checkable: false
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0
        leftPadding: row.hero ? 10 : 14
        rightPadding: row.hero ? 16 : 14
        mdState.size: MD.Enum.XS
        mdState.type: MD.Enum.BtText
        mdState.textColor: row.contentColor

        onClicked: if (row.expandable) {
            row.headerClicked();
        }

        // The vessel paints the tone; the header keeps only its ripple,
        // clipped to the vessel's live top corners.
        background: MD.ElevationRectangle {
            color: "transparent"
            corners: MD.Util.corners(vessel.topLeftRadius, vessel.topRightRadius, row.open ? 0 : vessel.bottomLeftRadius, row.open ? 0 : vessel.bottomRightRadius)

            MD.Ripple {
                anchors.fill: parent
                corners: parent.corners
                pressX: head.pressX
                pressY: head.pressY
                pressed: head.pressed
                stateOpacity: row.expandable ? head.mdState.stateLayerOpacity : 0
                color: MD.Token.color.on_surface_variant
            }
        }

        contentItem: Item {
            implicitHeight: row.headerHeight - 8

            // Hero lead: 40px primary circle, radius 20 -> 13 while open.
            Rectangle {
                id: heroCircle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: row.hero
                width: 40
                height: 40
                radius: row.open ? 13 : 20
                color: MD.Token.color.primary

                Behavior on radius {
                    MotionAnimation {}
                }

                MD.Icon {
                    anchors.centerIn: parent
                    name: row.leadingIcon
                    size: 21
                    color: MD.Token.color.on_primary
                }
            }

            MD.Icon {
                id: flatIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.hero && row.leadingIcon.length > 0
                name: row.leadingIcon
                size: 18
                color: row.current ? MD.Token.color.on_secondary_container : MD.Token.color.on_surface_variant
            }

            Column {
                anchors.left: parent.left
                // Hero: 10 + 40 + 12; flat rows share the device lists' text
                // column (14 + 18 + 12 = 44, minus the 14 header padding).
                anchors.leftMargin: row.hero ? 52 : row.leadingIcon.length > 0 ? 30 : 0
                anchors.right: trail.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Row {
                    width: parent.width
                    spacing: 6

                    MD.Text {
                        width: Math.min(implicitWidth, parent.width - (badgeIcon.visible ? badgeIcon.width + parent.spacing : 0))
                        text: row.text
                        color: row.contentColor
                        typescale: row.hero ? MD.Token.typescale.title_medium : MD.Token.typescale.label_large
                        prominent: row.hero || row.current
                        font.family: Theme.textTypeface
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                    }

                    MD.Icon {
                        id: badgeIcon

                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.nameBadgeIcon.length > 0
                        name: row.nameBadgeIcon
                        size: 12
                        opacity: 0.75
                        color: row.mutedColor
                    }
                }

                MD.Text {
                    width: parent.width
                    visible: row.subText.length > 0
                    text: row.subText
                    color: row.mutedColor
                    typescale: MD.Token.typescale.body_small
                    prominent: row.hero
                    font.family: Theme.textTypeface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }
            }

            // Trail: busy spinner while connecting/pairing, else the caret
            // (rotates 90 -> -90, shown on hover or while open).
            Item {
                id: trail

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18

                MD.Icon {
                    anchors.centerIn: parent
                    visible: !row.busy && row.expandable
                    name: "chevron_right"
                    size: 15
                    color: row.mutedColor
                    opacity: row.open ? 0.65 : head.hovered ? 0.65 : 0
                    rotation: row.open ? -90 : 90

                    Behavior on rotation {
                        MotionAnimation {}
                    }

                    Behavior on opacity {
                        MotionAnimation {
                            spring: Motion.effectsFast
                        }
                    }
                }

                MD.BusyIndicator {
                    anchors.centerIn: parent
                    // running only; the control writes its own `visible`
                    // (see DetailRow's spinner note).
                    running: row.busy
                    indicatorSize: 18
                    implicitWidth: 18
                    implicitHeight: 18
                }
            }
        }
    }

    // --- body reveal (prototype .wf-x grid 0fr -> 1fr) ----------------------
    Item {
        id: bodyReveal

        y: row.headerHeight
        width: parent.width
        height: row.open ? bodyColumn.implicitHeight + 11 : 0
        clip: true

        Behavior on height {
            MotionAnimation {
                spring: Motion.spatialDefault
            }
        }

        Column {
            id: bodyColumn

            x: 14
            y: 2
            width: parent.width - 28
            spacing: 10
            opacity: row.open ? 1 : 0

            transform: Translate {
                y: row.open ? 0 : -6

                Behavior on y {
                    MotionAnimation {}
                }
            }

            Behavior on opacity {
                MotionAnimation {
                    spring: Motion.effectsDefault
                }
            }
        }
    }
}
