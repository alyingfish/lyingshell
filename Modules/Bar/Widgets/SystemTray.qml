import QtQuick
import Quickshell
import Qcm.Material as MD
import qs.Commons.I18n

MD.IconButton {
    id: root

    // Fed by Bar.qml so the popup can track bar geometry.
    property bool barHidden: false
    property rect barSurfaceRect

    mdState.type: MD.Enum.IBtStandard
    mdState.size: MD.Enum.XS
    mdState.widthMode: MD.Enum.NarrowWidth
    icon.name: "keyboard_arrow_up"

    // Open-state: checked mirrors the popup, so StateIconButton fills the glyph
    // and recolors it primary. Standard type is container-less (no shape morph).
    checked: popup.visible
    onClicked: popup.visible = !popup.visible

    // Bar hidden → nothing to anchor to; close the popup.
    onBarHiddenChanged: if (barHidden) popup.visible = false
    // Shape/margin morph moves the button, but anchor.item is only computed at
    // open time — re-anchor so the gap below the button stays constant (esp.
    // floating's margin → a marginless shape).
    onBarSurfaceRectChanged: if (popup.visible) popup.anchor.updateAnchor()

    // Chevron flips up->down while open. Rotate the GLYPH, not the button:
    // updateAnchor() re-derives the popup anchor from root.boundingRect() mapped
    // through root's transform, so rotating root would shift that rect on every
    // shape morph (a morph landing mid-flip shifts it by an arbitrary angle) and
    // drift the gap below the bar. A 180 rotation of keyboard_arrow_up reads as
    // keyboard_arrow_down.
    contentItem: Item {
        implicitWidth: root.icon.width
        implicitHeight: root.icon.height
        opacity: root.mdState.contentOpacity
        rotation: root.checked ? 180 : 0
        Behavior on rotation {
            NumberAnimation {
                duration: MD.Token.duration.short4   // 200ms
                easing: MD.Token.easing.emphasized
            }
        }

        MD.Icon {
            anchors.centerIn: parent
            name: root.icon.name
            size: Math.min(root.icon.width, root.icon.height)
            color: root.mdState.textColor
            fill: root.checked
        }
    }

    // Tray-style popup below the button; grabFocus dismisses on outside click.
    PopupWindow {
        id: popup

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        anchor.margins.top: 8

        implicitWidth: 320
        implicitHeight: 400
        color: "transparent"
        visible: false
        grabFocus: true

        // ponytail: placeholder surface — drop real content in here.
        MD.Rectangle {
            anchors.fill: parent
            radius: 16
            color: MD.Token.color.surface_container

            MD.Text {
                anchors.centerIn: parent
                text: I18n.t("app.name")
                color: MD.Token.color.on_surface_variant
                typescale: MD.Token.typescale.title_medium
            }
        }
    }
}
