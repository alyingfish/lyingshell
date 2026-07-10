import QtQuick
import Qcm.Material as MD
import qs.Commons.Theme
import qs.Material
import "../../../Material/Motion.js" as Motion

// Detail-list row (prototype .dvi): 46px surface-container-high card
// (radius 15, 12 selected = secondary-container) with icon, name + optional
// badge glyph, sub line, and a popping trailing check; rows rise in with a
// 35ms/index stagger.
MD.Button {
    id: detailRow

    property bool current: false
    property string subText: ""
    property string leadingIcon: ""
    // Small glyph beside the name (prototype's 12px lock).
    property string nameBadgeIcon: ""
    // Replaces the check with a progress affordance while connecting.
    property bool busy: false
    // Index in the list; drives the entrance stagger.
    property int order: 0

    width: parent ? parent.width : 0
    implicitHeight: 46
    leftPadding: 14
    rightPadding: 14
    checkable: false
    flat: true
    topInset: 0
    bottomInset: 0
    leftInset: 0
    rightInset: 0
    mdState.size: MD.Enum.XS
    mdState.type: current ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
    property color animBackground: current ? mdState.ctx.color.secondary_container : mdState.ctx.color.surface_container_high

    Behavior on animBackground {
        MotionColorAnimation {}
    }

    mdState.backgroundColor: animBackground
    mdState.textColor: current ? mdState.ctx.color.on_secondary_container : mdState.ctx.color.on_surface
    readonly property real rowCorner: current ? 12 : 15
    mdState.corners: MD.Util.corners(rowCorner)
    scale: down ? 0.97 : 1

    Behavior on scale {
        MotionAnimation {}
    }

    // Entrance (prototype dvIn keyframes, 35ms/index stagger).
    transform: Translate {
        id: rowTy
    }

    Component.onCompleted: rowIn.restart()

    DetailRise {
        id: rowIn

        target: detailRow
        translate: rowTy
        order: detailRow.order
    }

    contentItem: Item {
        implicitHeight: 46 - 8

        MD.Icon {
            id: rowIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: detailRow.leadingIcon.length > 0
            name: detailRow.leadingIcon
            size: 18
            color: detailRow.current ? detailRow.mdState.ctx.color.on_secondary_container : detailRow.mdState.ctx.color.on_surface_variant
        }

        Column {
            anchors.left: rowIcon.visible ? rowIcon.right : parent.left
            anchors.leftMargin: rowIcon.visible ? 10 : 0
            anchors.right: rowTrailing.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                width: parent.width
                spacing: 6

                MD.Text {
                    // Reserve room for the badge glyph.
                    width: Math.min(implicitWidth, parent.width - (badgeIcon.visible ? badgeIcon.width + parent.spacing : 0))
                    text: detailRow.text
                    color: detailRow.mdState.textColor
                    typescale: MD.Token.typescale.label_large
                    prominent: detailRow.current
                    font.family: Theme.textTypeface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }

                MD.Icon {
                    id: badgeIcon

                    anchors.verticalCenter: parent.verticalCenter
                    visible: detailRow.nameBadgeIcon.length > 0
                    name: detailRow.nameBadgeIcon
                    size: 12
                    opacity: 0.75
                    color: detailRow.mdState.ctx.color.on_surface_variant
                }
            }

            MD.Text {
                width: parent.width
                visible: detailRow.subText.length > 0
                text: detailRow.subText
                color: detailRow.mdState.ctx.color.on_surface_variant
                typescale: MD.Token.typescale.body_small
                font.family: Theme.textTypeface
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }
        }

        Item {
            id: rowTrailing

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18

            MD.Icon {
                anchors.centerIn: parent
                visible: !detailRow.busy
                name: "check"
                size: 18
                color: MD.Token.color.primary
                opacity: detailRow.current ? 1 : 0
                scale: detailRow.current ? 1 : 0.4

                Behavior on opacity {
                    MotionAnimation {
                        spring: Motion.effectsFast
                    }
                }

                Behavior on scale {
                    MotionAnimation {}
                }
            }

            MD.BusyIndicator {
                anchors.centerIn: parent
                // Drive it via running only. The control writes its own
                // `visible` imperatively in onRunningChanged, which clobbers a
                // `visible:` binding and strands the spinner on-screen after
                // busy clears (the "Connected but still spinning" bug).
                running: detailRow.busy
                implicitWidth: 18
                implicitHeight: 18
            }
        }
    }
}
