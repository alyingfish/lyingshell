import QtQuick
import QtQuick.Window
import Qcm.Material as MD

// One tray item: a single hit-test target rendering the app icon.
// Duck-typed (id + icon source only) and Quickshell-free so offscreen
// pointer tests can drive it; SystemTray.qml owns the service wiring.
MD.IconButton {
    id: root

    property string trayItemId
    property url iconSource
    // Drag origin placeholder: keep layout, fade the icon.
    property bool ghosted: false

    signal activated()
    signal secondaryActivated()
    signal menuRequested()
    signal scrolled(real delta)
    signal dragStarted()
    signal dragMoved(real dragX, real dragY)
    signal dragFinished()

    mdState.type: MD.Enum.IBtStandard
    mdState.size: MD.Enum.XS
    icon.width: 16
    icon.height: 16

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
}
