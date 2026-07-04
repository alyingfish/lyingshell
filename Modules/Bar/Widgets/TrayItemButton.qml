import QtQuick
import QtQuick.Window
import QtQuick.Effects
import Qcm.Material as MD

// One tray item: a single hit-test target rendering the app icon.
// Duck-typed (id + icon source only) and Quickshell-free so offscreen
// pointer tests can drive it; SystemTray.qml owns the service wiring.
MD.IconButton {
    id: root

    property string trayItemId
    property url iconSource
    // Recolor the icon to the theme foreground so dark/monochrome app icons
    // stay legible on the dark bar. Off = render the raw icon (keeps colors).
    property bool recolorIcons: false
    // Drag origin placeholder: keep layout, fade the icon.
    property bool ghosted: false
    // Insert pulse: bound to SystemTray's pulse state; the just-dropped item
    // grows in when the stamp bumps. Guarded past creation because repeater
    // rebuilds re-evaluate the bindings with the stale last pulse.
    property string pulseId
    property int pulseStamp: 0
    property bool _created: false

    Component.onCompleted: _created = true
    onPulseStampChanged: {
        if (_created && pulseId === trayItemId)
            insertPulse.restart();
    }

    signal activated()
    signal secondaryActivated()
    signal menuRequested()
    signal scrolled(real delta)
    signal dragStarted()
    signal dragMoved(real dragX, real dragY)
    signal dragFinished()

    mdState.type: MD.Enum.IBtStandard
    mdState.size: MD.Enum.XS
    // 14, not the nominal 16: app icons are full-bleed bitmaps while the
    // web-UX reference renders 16px Material Symbols (~13px of glyph ink).
    icon.width: 14
    icon.height: 14

    onClicked: activated()

    contentItem: Item {
        implicitWidth: root.icon.width
        implicitHeight: root.icon.height
        opacity: root.ghosted ? MD.Token.state.disabled_content : root.mdState.contentOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: MD.Token.duration.short2
            }
        }

        Image {
            anchors.centerIn: parent
            width: root.icon.width
            height: root.icon.height
            source: root.iconSource
            sourceSize: Qt.size(root.icon.width * Screen.devicePixelRatio, root.icon.height * Screen.devicePixelRatio)
            fillMode: Image.PreserveAspectFit
            asynchronous: true

            // Flatten the icon to a solid on_surface silhouette: brightness lifts
            // near-black ink so colorization (luma-weighted) reaches full target
            // instead of staying dark. ponytail: pure-MultiEffect, no per-icon
            // dominant-color sampling; add a ColorQuantizer lift only if colored
            // logos need to keep internal shading.
            layer.enabled: root.recolorIcons
            layer.effect: MultiEffect {
                brightness: 1
                colorization: 1
                colorizationColor: MD.Token.color.on_surface
            }
        }
    }

    // Left-drag for pin/unpin. target:null keeps the button in place; the
    // exclusive grab past the threshold cancels the pending click.
    DragHandler {
        id: dragHandler

        target: null

        onActiveChanged: {
            if (active)
                root.dragStarted();
            else
                root.dragFinished();
        }

        onTranslationChanged: {
            if (active)
                root.dragMoved(centroid.position.x, centroid.position.y);
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton

        onTapped: root.menuRequested()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton

        onTapped: root.secondaryActivated()
    }

    WheelHandler {
        onWheel: function (event) {
            root.scrolled(event.angleDelta.y);
        }
    }

    SequentialAnimation {
        id: insertPulse

        NumberAnimation {
            target: root
            property: "scale"
            from: 0.5
            to: 1.1
            duration: MD.Token.duration.short4
            easing: MD.Token.easing.emphasized_decelerate
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.0
            duration: MD.Token.duration.short2
            easing: MD.Token.easing.standard
        }
    }
}
