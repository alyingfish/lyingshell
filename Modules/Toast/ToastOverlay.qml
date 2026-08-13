import QtQuick
import Quickshell
import Quickshell.Wayland
import Qcm.Material as MD
import qs.Commons.Theme
import qs.Material
import qs.Services
import qs.Services.Niri
import "../../Material/Motion.js" as Motion

// Transient toast surface (web prototype #toast): an inverse-surface pill
// top-centered under the bar on the focused output, springing in from -24px
// and fading out. Pointer-transparent; Services/Toast.qml owns the message
// and its timing.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutputName) || Quickshell.screens[0] || null
    anchors.top: true
    margins.top: 48
    color: "transparent"
    exclusiveZone: 0
    // Never while locked: the compositor draws no overlay surfaces behind the
    // session lock, so the toast would animate invisibly on a window that
    // gets no frame callbacks (see RENDERING SAFETY in
    // Modules/Lock/LockScreen.qml). A toast still pending when the lock drops
    // shows for whatever time it has left.
    visible: Toast.active && !Lock.locked
    implicitWidth: card.implicitWidth + 48
    implicitHeight: card.implicitHeight + 32
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lyingshell-toast"

    // Prototype pointer-events:none — clicks pass through everywhere.
    mask: Region {}

    MD.ElevationRectangle {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: message.implicitWidth + 40
        implicitHeight: message.implicitHeight + 24
        color: MD.Token.color.inverse_surface
        corners: MD.Util.corners(16)
        elevation: MD.Token.elevation.level3
        elevationVisible: true

        y: Toast.shown ? 0 : -24
        scale: Toast.shown ? 1 : 0.85
        opacity: Toast.shown ? 1 : 0

        Behavior on y {
            MotionAnimation {}
        }

        Behavior on scale {
            MotionAnimation {}
        }

        Behavior on opacity {
            MotionAnimation {
                spring: Motion.effectsFast
            }
        }

        MD.Text {
            id: message

            anchors.centerIn: parent
            text: Toast.text
            color: MD.Token.color.inverse_on_surface
            typescale: MD.Token.typescale.label_large
            font.family: Theme.textTypeface
        }
    }
}
