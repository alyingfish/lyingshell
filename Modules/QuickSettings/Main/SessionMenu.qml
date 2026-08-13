import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Theme
import qs.Material
import qs.Services
import qs.Services.Niri
import "../../../Material/Motion.js" as Motion

// Session menu behind the header power button (prototype #pmenu): a compact
// card anchored top-right under the button — 18px card radius,
// surface-container-high, 5px padding, 2px row gap. Rows are 38px with the
// first/last outer corners nesting into the card; the shut-down row reads
// error red. Icon and label share the row colour (prototype currentColor).
// Opens with a top-right scale spring. The panel owns open/close and the
// click-catcher; this is a plain in-panel card so it stays clipped inside
// the panel exactly like the prototype (and is offscreen-verifiable, unlike
// an MD.Menu popup).
Item {
    id: root

    property bool open: false

    // The panel closes before the session action runs.
    signal panelCloseRequested

    implicitWidth: card.width
    implicitHeight: card.height
    visible: open || card.opacity > 0.001

    MD.ElevationRectangle {
        id: card

        // Prototype #pmenu: 5px padding around the row column.
        width: menuColumn.width + 10
        height: menuColumn.height + 10
        corners: MD.Util.corners(18)
        color: MD.Token.color.surface_container_high
        elevation: MD.Token.elevation.level3
        elevationVisible: true
        opacity: 0

        // Prototype #pmenu:not(.open){opacity:0;transform:scale(.75)} from a
        // top-right origin; opens on the bouncy spatial spring, closes on the
        // quicker standard curve.
        property real cardScale: 0.75

        transform: Scale {
            origin.x: card.width
            origin.y: 0
            xScale: card.cardScale
            yScale: card.cardScale
        }

        states: State {
            name: "open"
            when: root.open

            PropertyChanges {
                card.opacity: 1
                card.cardScale: 1
            }
        }

        transitions: [
            Transition {
                to: "open"

                MotionAnimation {
                    property: "cardScale"
                }

                MotionAnimation {
                    property: "opacity"
                    spring: Motion.effectsDefault
                }
            },
            Transition {
                from: "open"

                NumberAnimation {
                    property: "cardScale"
                    duration: MD.Token.duration.short4
                    easing.bezierCurve: Motion.effectsDefault.curve
                }

                MotionAnimation {
                    property: "opacity"
                    spring: Motion.effectsDefault
                }
            }
        ]

        Column {
            id: menuColumn

            x: 5
            y: 5
            spacing: 2
            // Prototype min-width 168px (=> 158 content) grows to the widest
            // localized label.
            width: Math.max(158, rowLock.implicitWidth, rowSleep.implicitWidth, rowLogout.implicitWidth, rowRestart.implicitWidth, rowShut.implicitWidth)

            // Locking again is meaningless from behind the lock, and logging
            // out would tear the session down without ever authenticating —
            // neither is offered on the lock screen (GNOME's own rule). Sleep,
            // restart and power off stay: they are physical-button parity.
            SessionRow {
                id: rowLock

                visible: !Lock.locked
                label: I18n.t("quickSettings.lock")
                iconName: "lock"
                topRadius: 14

                // Lock FIRST, unlike every other row: the entry gesture must
                // already be running ("enter") when the panel closes, so the
                // close resolves as a cut instead of a fade the pre-lock
                // desktop capture would have to wait out. Session.lock()
                // raising sweepActive closes the panel by itself
                // (QuickSettingsButton.sessionLocking); the explicit close
                // stays for the paths lock() refuses (already locked).
                onActivated: {
                    Session.lock();
                    root.panelCloseRequested();
                }
            }

            SessionRow {
                id: rowSleep

                label: I18n.t("quickSettings.session.suspend")
                iconName: "bedtime"
                // Inherits the card's top corner when the lock row is gone.
                topRadius: rowLock.visible ? 0 : 14

                onActivated: {
                    root.panelCloseRequested();
                    Session.suspend();
                }
            }

            SessionRow {
                id: rowLogout

                visible: !Lock.locked
                label: I18n.t("quickSettings.session.logOut")
                iconName: "logout"

                onActivated: {
                    root.panelCloseRequested();
                    Niri.quitSession();
                }
            }

            SessionRow {
                id: rowRestart

                label: I18n.t("quickSettings.session.restart")
                iconName: "restart_alt"

                onActivated: {
                    root.panelCloseRequested();
                    Session.reboot();
                }
            }

            SessionRow {
                id: rowShut

                label: I18n.t("quickSettings.session.powerOff")
                iconName: "power_settings_new"
                danger: true
                bottomRadius: 14

                onActivated: {
                    root.panelCloseRequested();
                    Session.powerOff();
                }
            }
        }
    }

    // Prototype .mi: 38px row, 16px icon, 10px gap, 12px side padding, label
    // large type; the state layer tints the row colour (hover 8% / press
    // 12%). The danger row draws its glyph and text in error red.
    component SessionRow: Rectangle {
        id: mi

        property string label
        property string iconName
        property bool danger: false
        property real topRadius: 10
        property real bottomRadius: 10

        signal activated

        readonly property color fg: danger ? MD.Token.color.error : MD.Token.color.on_surface

        width: menuColumn.width
        implicitWidth: rowContent.implicitWidth + 24
        height: 38
        topLeftRadius: topRadius
        topRightRadius: topRadius
        bottomLeftRadius: bottomRadius
        bottomRightRadius: bottomRadius
        color: Qt.rgba(fg.r, fg.g, fg.b, mouseArea.pressed ? 0.12 : mouseArea.containsMouse ? 0.08 : 0)

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Row {
            id: rowContent

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            MD.Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: mi.iconName
                size: 16
                color: mi.fg
            }

            MD.Text {
                anchors.verticalCenter: parent.verticalCenter
                text: mi.label
                color: mi.fg
                typescale: MD.Token.typescale.label_large
                font.family: Theme.textTypeface
            }
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true

            onClicked: mi.activated()
        }
    }
}
