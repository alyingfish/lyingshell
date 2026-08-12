import QtQuick
import Quickshell
import Qcm.Material as MD
import qs.Material
import "../../Material/Motion.js" as Motion

// Quick-settings popup (GNOME's quick-settings panel): a floating MD3 card
// below the bar, opened by the bar's quick-settings button. The card and
// its click-catcher render in a window-level overlay reparented to the
// window contentItem; Bar.qml expands the window to full height while
// `expanded` is true (same window contract as SystemTray).
Item {
    id: root

    // Bar-strip item the card's right edge anchors to (the button's pill).
    required property Item anchorItem
    // Bottom edge of the bar surface in window coordinates.
    property real barBottom: 0
    property bool open: false

    // Where the card and its click-catcher are reparented to. The bar's own
    // window supplies its content item through the QsWindow attached object;
    // a WlSessionLockSurface is NOT a QsWindow (it wraps a raw QQuickWindow),
    // so the lock passes its scene root explicitly instead.
    property Item overlayParent: root.QsWindow.window ? root.QsWindow.window.contentItem : null

    signal closeRequested
    // Panel asks to be reopened (a colour pick completed while closed);
    // bubbles to the bar button that owns the open state.
    signal openRequested

    // Bar.qml: full-screen window + full input mask while true.
    readonly property bool expanded: open || panelCard.opacity > 0.001
    readonly property alias panel: panel
    // e2e geometry probes.
    readonly property rect cardRect: Qt.rect(panelCard.x, panelCard.y, panelCard.width, panelCard.height)

    function itemRect(item: Item): rect {
        return overlay.mapFromItem(item, 0, 0, item.width, item.height);
    }

    // Reactive overlay-space position (mapToItem registers no dependencies;
    // summing x/y up the chain does — same reasoning as SystemTray).
    function overlayX(item) {
        let x = 0;
        for (let it = item; it && it !== overlay.parent; it = it.parent)
            x += it.x;
        return x;
    }

    // Window-level overlay: click-catcher + panel card.
    Item {
        id: overlay

        parent: root.overlayParent
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        z: 90

        MouseArea {
            x: 0
            y: root.barBottom
            width: overlay.width
            height: Math.max(0, overlay.height - y)
            visible: root.open
            acceptedButtons: Qt.AllButtons

            onPressed: root.closeRequested()
        }

        Item {
            id: panelCard

            readonly property real pad: 8
            readonly property real anchorRightX: root.overlayX(root.anchorItem) + root.anchorItem.width

            // Prototype #qs entrance: translateY(-16) + scale(.9) around a
            // transform origin at 85% / -10%, opening on the bouncy spatial
            // spring and closing on the quicker standard curve.
            property real slideY: -16
            property real cardScale: 0.9

            // Prototype `#qs.open { transition: transform .55s var(--spring) }`:
            // the literal cubic-bezier(.34,1.56,.64,1) at .55s as one Bezier
            // segment (control-y 1.56 = overshoot). Same technique as
            // TilePager.springSoft; an MD3 spatial token settles ~2x faster.
            readonly property var entranceSpring: ({
                    "duration": 550,
                    "curve": [0.34, 1.56, 0.64, 1.0, 1.0, 1.0]
                })

            states: State {
                name: "open"
                when: root.open

                PropertyChanges {
                    panelCard.slideY: 0
                    panelCard.cardScale: 1
                    panelCard.opacity: 1
                }
            }

            transitions: [
                Transition {
                    to: "open"

                    MotionAnimation {
                        properties: "slideY,cardScale"
                        spring: panelCard.entranceSpring
                    }

                    // Prototype opacity .15s linear (not the effects spring).
                    NumberAnimation {
                        property: "opacity"
                        duration: 150
                        easing.type: Easing.Linear
                    }
                },
                Transition {
                    from: "open"

                    NumberAnimation {
                        properties: "slideY,cardScale"
                        duration: MD.Token.duration.short4
                        easing: MD.Token.easing.standard
                    }

                    MotionAnimation {
                        property: "opacity"
                        spring: Motion.effectsDefault
                    }
                }
            ]

            // Content height follows the expandable rows' own springs and
            // the detail-page lock; a second height animation here would
            // double-lag them (the prototype panel has no height transition).
            width: panel.implicitWidth
            height: panel.implicitHeight

            x: Math.max(pad, Math.min(anchorRightX - width, overlay.width - width - pad))
            y: root.barBottom + pad
            opacity: 0
            visible: opacity > 0.001

            transform: [
                Scale {
                    origin.x: panelCard.width * 0.85
                    origin.y: -panelCard.height * 0.1
                    xScale: panelCard.cardScale
                    yScale: panelCard.cardScale
                },
                Translate {
                    y: panelCard.slideY
                }
            ]

            MD.ElevationRectangle {
                anchors.fill: parent
                // Prototype panel: 24px radius, surface-container-low fill,
                // deep floating shadow — MD3 elevated surfaces carry no
                // border. 24 sits between the large and extra-large corner
                // tokens; it is the prototype's card radius.
                corners: MD.Util.corners(24)
                color: MD.Token.color.surface_container_low
                elevation: MD.Token.elevation.level3
                elevationVisible: true

                // Context colors for descendants (ListItem, Menu, TextField
                // defaults resolve MProp.textColor/backgroundColor).
                MD.MProp.textColor: MD.Token.color.on_surface
                MD.MProp.backgroundColor: MD.Token.color.surface_container_low

                // Swallow presses so the catcher below does not dismiss.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                // Clip only the content during height animation; clipping the
                // ElevationRectangle itself cuts its shadow into a hard rim.
                Item {
                    anchors.fill: parent
                    clip: true

                    QuickSettingsPanel {
                        id: panel

                        width: parent.width
                        visible: root.expanded
                        open: root.open

                        onCloseRequested: root.closeRequested()
                        onOpenRequested: root.openRequested()
                    }
                }
            }
        }
    }
}
