import QtQuick
import Quickshell
import Qcm.Material as MD
import qs.Commons.Settings

Item {
    id: root

    required property var workspaceModel

    signal focusRequested(string workspaceId)

    // Wheel scroll handling. Shared by the pill background and every dot so a
    // scroll reads as one surface. See handleWheel: accumulate to a threshold,
    // switch exactly one workspace, then gate input for a cooldown.
    property real wheelAccumulator: 0
    property bool wheelCooldown: false

    readonly property int horizontalPadding: 8
    readonly property int controlHeight: 24
    readonly property int dotGap: 6
    readonly property int workspaceCount: workspaceModel && workspaceModel.length !== undefined ? workspaceModel.length : 0
    readonly property bool hasWorkspaces: workspaceCount > 0
    readonly property bool hovered: pillMouseArea.containsMouse || hasHoveredDot()
    // Updated by syncRenderedWorkspaces, not bound: Niri replaces workspace
    // array identities on every compositor event (including per-frame window
    // layout storms), and a plain binding would push fresh objects into the
    // ScriptModel and re-bind every dot each time. The signature guard drops
    // updates whose rendered content is unchanged.
    property var renderedWorkspaceValues: []
    property string _renderedSignature: ""
    readonly property int enterDuration: MD.Token.duration.short4
    readonly property int exitDuration: MD.Token.duration.short3
    readonly property int displacedDuration: MD.Token.duration.short4

    visible: hasWorkspaces
    implicitWidth: hasWorkspaces ? workspaceList.contentWidth + horizontalPadding * 2 : 0
    implicitHeight: controlHeight
    width: implicitWidth
    height: implicitHeight

    // Required properties are assigned before completion without firing the
    // change signal, so seed once here.
    Component.onCompleted: syncRenderedWorkspaces()
    onWorkspaceModelChanged: syncRenderedWorkspaces()

    function syncRenderedWorkspaces() {
        var next = normalizedWorkspaces(workspaceModel);
        var signature = JSON.stringify(next);
        if (signature === _renderedSignature) {
            return;
        }
        _renderedSignature = signature;
        renderedWorkspaceValues = next;
    }

    ScriptModel {
        id: renderedWorkspaces

        objectProp: "id"
        values: root.renderedWorkspaceValues
    }

    MD.Rectangle {
        id: stateLayer

        anchors.fill: parent
        radius: height / 2
        color: MD.Token.color.on_surface_variant
        opacity: root.hovered ? MD.Token.state.hover.state_layer_opacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: MD.Token.duration.short2
                easing: MD.Token.easing.standard
            }
        }
    }

    MouseArea {
        id: pillMouseArea

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onWheel: function(wheel) {
            // Sum both axes so a touchpad's perpendicular wobble can't flip the
            // sign; a pixelDelta means it's a touchpad (higher threshold).
            var angle = wheel.angleDelta.x + wheel.angleDelta.y;
            var pixel = wheel.pixelDelta.x + wheel.pixelDelta.y;
            root.handleWheel(angle !== 0 ? angle : pixel * 8, pixel !== 0);
            wheel.accepted = true;
        }
    }

    ListView {
        id: workspaceList

        anchors.centerIn: parent
        width: contentWidth
        height: root.controlHeight
        clip: false
        interactive: false
        orientation: ListView.Horizontal
        spacing: root.dotGap
        model: renderedWorkspaces

        delegate: Item {
            id: workspaceDelegate

            required property var modelData
            readonly property var workspace: modelData

            readonly property bool hovered: dot.hovered
            readonly property bool pressed: dot.pressed

            width: dot.width
            height: workspaceList.height

            WorkspaceDot {
                id: dot

                anchors.verticalCenter: parent.verticalCenter
                workspace: workspaceDelegate.workspace
                pulseEnabled: Settings.options.bar.widgets.workspaces.urgentPulse

                onActivated: function(workspaceId) {
                    root.focusRequested(workspaceId);
                }

                onWheelRequested: function(delta, isTouchpad) {
                    root.handleWheel(delta, isTouchpad);
                }
            }
        }

        add: Transition {
            NumberAnimation {
                property: "scale"
                from: 0.8
                to: 1
                duration: root.enterDuration
                easing: MD.Token.easing.emphasized_decelerate
            }

            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: root.enterDuration
                easing: MD.Token.easing.standard
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "scale"
                to: 0.8
                duration: root.exitDuration
                easing: MD.Token.easing.emphasized_accelerate
            }

            NumberAnimation {
                property: "opacity"
                to: 0
                duration: root.exitDuration
                easing: MD.Token.easing.standard
            }
        }

        move: Transition {
            NumberAnimation {
                properties: "x"
                duration: root.displacedDuration
                easing: MD.Token.easing.standard
            }
        }

        displaced: Transition {
            NumberAnimation {
                properties: "x"
                duration: root.displacedDuration
                easing: MD.Token.easing.standard
            }
        }
    }

    // Resets the cooldown gate once niri has had time to apply the focus.
    Timer {
        id: wheelCooldownTimer

        interval: 150
        onTriggered: {
            root.wheelCooldown = false;
            root.wheelAccumulator = 0;
        }
    }

    function handleWheel(delta, isTouchpad) {
        // Accumulate to a threshold, switch exactly ONE workspace, then gate
        // further input for a short cooldown. Niri applies focus asynchronously,
        // so without this a fast touchpad swipe stacks several notches before
        // the active workspace updates -- overshooting by two or misfiring.
        // Pattern from dank-material-shell / noctalia workspace switchers.
        if (wheelCooldown) {
            return;
        }
        wheelAccumulator += delta;
        // Touchpads stream far more (smaller) events than a mouse notch (120);
        // both thresholds are calibration knobs -- raise for less sensitivity.
        var threshold = isTouchpad ? 500 : 120;
        if (Math.abs(wheelAccumulator) < threshold) {
            return;
        }
        // Positive delta = up/left = previous workspace.
        var steps = wheelAccumulator > 0 ? 1 : -1;
        wheelAccumulator = 0;
        wheelCooldown = true;
        wheelCooldownTimer.restart();
        var workspaceId = workspaceIdForSteps(steps);
        if (workspaceId.length > 0) {
            focusRequested(workspaceId);
        }
    }

    function workspaceIdForSteps(steps) {
        if (steps === 0 || workspaceCount === 0) {
            return "";
        }

        var currentIndex = workspaceModel.findIndex(function(workspace) {
            return workspace.active === true;
        });

        if (currentIndex < 0) {
            return "";
        }

        // Positive steps = up/left = previous workspace (lower index).
        var nextIndex = currentIndex - steps;
        nextIndex = Settings.options.bar.widgets.workspaces.scrollLoop
            ? ((nextIndex % workspaceCount) + workspaceCount) % workspaceCount
            : MD.Util.clamp(nextIndex, 0, workspaceCount - 1);

        if (nextIndex === currentIndex) {
            return "";
        }

        return String(workspaceModel[nextIndex].id);
    }

    function hasHoveredDot() {
        for (var index = 0; index < workspaceList.contentItem.children.length; index++) {
            var child = workspaceList.contentItem.children[index];
            if (child.hovered || child.pressed) {
                return true;
            }
        }

        return false;
    }

    function normalizedWorkspaces(sourceModel) {
        if (!sourceModel || sourceModel.length === undefined) {
            return [];
        }

        return sourceModel.map(function(workspace) {
            return {
                "id": String(workspace.id),
                "index": Number(workspace.index),
                "outputName": String(workspace.outputName || ""),
                "name": String(workspace.name || ""),
                "active": workspace.active === true,
                "focused": workspace.focused === true,
                "urgent": workspace.urgent === true,
                "hasWindows": String(workspace.activeWindowId || "").length > 0
            };
        });
    }
}
