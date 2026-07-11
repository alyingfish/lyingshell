import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Material
import "../../../Material/Motion.js" as Motion

// Web-prototype toggle tile for the quick-settings grid (GNOME QuickToggle):
// a 44px pill (radius 22) of surface-container-high that fills primary and
// squares to radius 14 when selected, with emphasized label type and an icon
// pop. Display state is service-owned: `checked` is bound in, clicks only
// emit `clicked` and the caller flips the service. These colors are not a
// QmlMaterial button variant, so they override the StateButton bindings.
MD.Button {
    id: control

    required property string labelKey
    // Runtime OS data (SSID, device name, profile, ...) shown instead of the
    // static label while set, so a connected tile reads as its connection.
    property string statusText: ""
    // Squared trailing edge when an arrow segment sits to the right.
    property bool splitCorners: false
    // Optional unchecked glyph (prototype ico-off/ico-on cross-fade, e.g.
    // wifi slashed <-> solid); empty means the single icon.name renders.
    property string offIconName: ""
    // Dark/night tiles render both glyphs filled at all times (no hover fill).
    property bool alwaysFill: false
    // Acquiring state (prototype .tile.acq): the icon pulses while an
    // adapter power transition or hotspot start is in flight.
    property bool pulsing: false
    // Cross-fade the selection colors on the M3E effects spring (critically
    // damped, never overshoots) so the fill animates in step with the shape
    // morph instead of snapping. `checked` is outside StateButton's state
    // machine, so the library never animates these on its own.
    property color animBackground: checked ? mdState.ctx.color.primary : mdState.ctx.color.surface_container_high
    property color animText: checked ? mdState.ctx.color.on_primary : mdState.ctx.color.on_surface_variant
    // Prototype tile.on radius (a hair rounder than the MD3 medium token).
    readonly property real selectedCorner: 14
    // Toggle shape morph: full pill (22) at rest, 14 selected. Step the
    // target — StateButton's own Behavior on corners renders it. Don't add a
    // spring Behavior here: it stalls that internal Behavior and freezes the
    // morph. Press feedback is the prototype's scale, not a corner change.
    readonly property real stateCorner: checked ? selectedCorner : height / 2
    // Prototype split corners: inner edge 6 at rest, 5 selected.
    readonly property real innerCorner: checked ? 5 : 6

    checkable: false
    // Desktop-compact: XS tokens in the web-prototype's 44px tile; touch-size
    // MD3 metrics read oversized on a pointer-driven desktop shell.
    mdState.size: MD.Enum.XS
    mdState.type: checked ? MD.Enum.BtFilled : MD.Enum.BtFilledTonal
    mdState.backgroundColor: animBackground
    mdState.textColor: animText
    // Select pop (web prototype `pop` keyframes): the icon rescales through
    // the same spring, whose overshoot supplies the bounce. Select only —
    // deselect stays quiet, like the prototype.
    onCheckedChanged: {
        if (checked) {
            iconPop.restart();
        }
    }
    mdState.corners: splitCorners ? MD.Util.corners(stateCorner, innerCorner, stateCorner, innerCorner) : MD.Util.corners(stateCorner)
    // Prototype `.tile:active{transform:scale(.95)}`.
    scale: down ? 0.95 : 1
    implicitHeight: 44
    icon.width: MD.Token.button.xsmall.icon_size
    icon.height: MD.Token.button.xsmall.icon_size
    // Prototype tile padding (0 12px).
    leftPadding: 12
    rightPadding: 12

    // Full text on hover when the compact cell truncates it (long SSIDs).
    MD.ToolTip {
        // Below the button, like bar-tray tooltips (library default is above).
        y: parent.height + 4
        text: titleText.text
        visible: control.hovered && titleText.truncated
    }

    Behavior on animBackground {
        MotionColorAnimation {
        }

    }

    Behavior on animText {
        MotionColorAnimation {
        }

    }

    Behavior on scale {
        MotionAnimation {
        }

    }

    contentItem: Item {
        implicitWidth: iconStack.width + control.mdState.spacing + titleText.implicitWidth
        implicitHeight: Math.max(iconStack.height, titleText.implicitHeight)
        opacity: control.mdState.contentOpacity

        Item {
            id: iconStack

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: control.icon.width
            height: control.icon.height

            MD.Icon {
                id: toggleIcon

                anchors.centerIn: parent
                name: control.icon.name
                size: control.icon.width
                color: control.mdState.textColor
                // alwaysFill tiles (dark/night): glyph stays filled. Others:
                // solid whenever selected.
                fill: control.alwaysFill || control.checked
                // Prototype ico-on/ico-off cross-fade (effects easing).
                opacity: control.offIconName.length === 0 || control.checked ? 1 : 0

                Behavior on opacity {
                    MotionAnimation {
                        spring: Motion.effectsSlow
                    }

                }

            }

            MD.Icon {
                anchors.centerIn: parent
                visible: control.offIconName.length > 0
                name: control.offIconName
                size: control.icon.width
                color: control.mdState.textColor
                fill: control.alwaysFill
                opacity: control.checked ? 0 : 1

                Behavior on opacity {
                    MotionAnimation {
                        spring: Motion.effectsSlow
                    }

                }

            }

            MotionAnimation {
                id: iconPop

                target: iconStack
                property: "scale"
                from: 0.6
                to: 1
            }

            // Prototype acqPulse keyframes (.9s ease-in-out, 50% -> 0.3).
            SequentialAnimation {
                running: control.pulsing
                loops: Animation.Infinite

                onStopped: iconStack.opacity = 1

                NumberAnimation {
                    target: iconStack
                    property: "opacity"
                    to: 0.3
                    duration: 450
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: iconStack
                    property: "opacity"
                    to: 1
                    duration: 450
                    easing.type: Easing.InOutQuad
                }
            }

        }

        MD.Text {
            id: titleText

            anchors.left: iconStack.right
            anchors.leftMargin: control.mdState.spacing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: control.statusText.length > 0 ? control.statusText : I18n.t(control.labelKey)
            color: control.mdState.textColor
            typescale: MD.Token.typescale.label_medium
            // Prototype selected tiles switch to emphasized (700) type.
            prominent: control.checked
            font.family: Theme.textTypeface
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }

    }

}
