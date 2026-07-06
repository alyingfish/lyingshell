import QtQuick
import Qcm.Material as MD

Item {
    id: root

    required property var workspace
    property bool pulseEnabled: true

    signal activated(string workspaceId)
    signal wheelRequested(real delta)

    readonly property int dotSize: 8
    readonly property int activeWidth: 24
    readonly property int hoverHaloExtension: 8
    readonly property int pressedHaloExtension: 10
    readonly property int morphDuration: MD.Token.duration.medium1
    readonly property int pulseDuration: MD.Token.duration.long2
    readonly property bool isActive: workspace && (workspace.active || workspace.focused)
    readonly property bool isFocused: workspace && workspace.focused
    readonly property bool isUrgent: workspace && workspace.urgent && !isFocused
    readonly property bool isBusy: workspace && workspace.hasWindows && !isFocused && !isUrgent
    readonly property bool hovered: dotMouseArea.containsMouse
    readonly property bool pressed: dotMouseArea.pressed
    readonly property bool shouldPulse: isUrgent && pulseEnabled
    readonly property color emphasisColor: isFocused ? MD.Token.color.primary
        : isUrgent ? MD.Token.color.error
        : isBusy ? MD.Token.color.secondary
        : MD.Token.color.outline
    readonly property color dotColor: isFocused ? MD.Token.color.primary
        : isUrgent ? MD.Token.color.error
        : isBusy ? (hovered ? MD.Token.color.secondary : MD.Util.transparent(MD.Token.color.secondary, 0.82))
        : hovered ? MD.Token.color.outline : MD.Token.color.outline_variant
    readonly property real haloOpacity: pressed
        ? (isUrgent ? 0.24 : isFocused ? 0.22 : 0.14)
        : hovered ? (isFocused || isUrgent ? 0.16 : 0.10) : 0
    property bool urgentInitialized: false
    property bool wasUrgent: false
    property real haloExtension: pressed ? pressedHaloExtension : hovered ? hoverHaloExtension : 0

    implicitWidth: width
    implicitHeight: dotSize
    width: isActive ? activeWidth : dotSize
    height: dotSize

    Component.onCompleted: {
        wasUrgent = isUrgent;
        urgentInitialized = true;
        if (shouldPulse) {
            startUrgentPulse();
        }
    }

    onIsUrgentChanged: {
        if (urgentInitialized && isUrgent && !wasUrgent) {
            startUrgentPulse();
        }
        wasUrgent = isUrgent;
    }

    onShouldPulseChanged: {
        if (shouldPulse) {
            startUrgentPulse();
        } else {
            urgentPulse.stop();
            pulseHalo.opacity = 0;
            pulseHalo.scale = 1;
        }
    }

    function startUrgentPulse() {
        if (!shouldPulse) {
            return;
        }

        pulseHalo.opacity = 1;
        pulseHalo.scale = 1;
        urgentPulse.restart();
    }

    Behavior on width {
        NumberAnimation {
            duration: root.morphDuration
            // Emphasized: the dot<->pill is an expressive shape morph, not a plain
            // state change, so it gets the container-transform curve.
            easing: MD.Token.easing.emphasized
        }
    }

    Behavior on haloExtension {
        NumberAnimation {
            duration: MD.Token.duration.short2
            easing: MD.Token.easing.standard
        }
    }

    Rectangle {
        id: interactionHalo

        anchors.centerIn: dot
        width: dot.width + root.haloExtension
        height: dot.height + root.haloExtension
        radius: height / 2
        color: MD.Util.transparent(root.emphasisColor, root.haloOpacity)
        opacity: root.haloOpacity > 0 ? 1 : 0

        Behavior on color {
            ColorAnimation {
                duration: MD.Token.duration.short2
                easing: MD.Token.easing.standard
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: MD.Token.duration.short2
                easing: MD.Token.easing.standard
            }
        }
    }

    Rectangle {
        id: pulseHalo

        anchors.centerIn: dot
        width: dot.width
        height: dot.height
        radius: height / 2
        color: MD.Util.transparent(MD.Token.color.error, 0.26)
        opacity: 0
    }

    Rectangle {
        id: dot

        anchors.centerIn: parent
        width: root.width
        height: root.dotSize
        radius: height / 2
        color: root.dotColor

        Behavior on color {
            ColorAnimation {
                duration: root.morphDuration
                easing: MD.Token.easing.standard
            }
        }
    }

    MouseArea {
        id: dotMouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.activated(root.workspace.id)
        onWheel: function(wheel) {
            var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y;
            root.wheelRequested(delta);
            wheel.accepted = true;
        }
    }

    SequentialAnimation {
        id: urgentPulse

        loops: 2

        ParallelAnimation {
            NumberAnimation {
                target: pulseHalo
                property: "opacity"
                from: 1
                to: 0
                duration: root.pulseDuration
                // Linear, not standard: standard front-loads the fade (alpha drops
                // below 0.27 by ~200ms) so the ring is invisible long before it
                // finishes expanding. Linear keeps it visible across the expansion.
                easing: MD.Token.easing.linear
            }

            NumberAnimation {
                target: pulseHalo
                property: "scale"
                from: 1
                to: 3
                duration: root.pulseDuration
                easing: MD.Token.easing.standard
            }
        }

        // Gap between beats: without it the second loop snaps opacity 0->1 in one
        // frame glued onto the end of the first, reading as a glitch rather than a
        // deliberate second pulse.
        PauseAnimation {
            duration: MD.Token.duration.short4
        }

        onStopped: {
            pulseHalo.opacity = 0;
            pulseHalo.scale = 1;
        }
    }
}
