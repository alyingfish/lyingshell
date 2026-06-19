import QtQuick
import Qcm.Material as MD
import qs.Commons.Settings

Item {
    id: root

    required property var workspaceModel
    property bool reducedMotion: false

    signal focusRequested(string workspaceId)

    readonly property int horizontalPadding: 8
    readonly property int controlHeight: 24
    readonly property int dotGap: 6
    readonly property int workspaceCount: workspaceModel && workspaceModel.length !== undefined ? workspaceModel.length : 0
    readonly property bool hasWorkspaces: workspaceCount > 0
    readonly property bool hovered: pillMouseArea.containsMouse || hasHoveredDot()
    readonly property int enterDuration: reducedMotion ? 0 : MD.Token.duration.short4
    readonly property int exitDuration: reducedMotion ? 0 : MD.Token.duration.short3
    readonly property int displacedDuration: reducedMotion ? 0 : MD.Token.duration.short4

    visible: hasWorkspaces
    implicitWidth: hasWorkspaces ? workspaceList.contentWidth + horizontalPadding * 2 : 0
    implicitHeight: controlHeight
    width: implicitWidth
    height: implicitHeight

    onWorkspaceModelChanged: syncWorkspaceModel()

    Component.onCompleted: syncWorkspaceModel()

    ListModel {
        id: renderedWorkspaces

        dynamicRoles: true
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
                easing.type: MD.Token.easing.standard.type
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
            var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y;
            root.handleWheelDelta(delta);
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

            required property var workspace

            readonly property bool hovered: dot.hovered
            readonly property bool pressed: dot.pressed

            width: dot.width
            height: workspaceList.height

            WorkspaceDot {
                id: dot

                anchors.verticalCenter: parent.verticalCenter
                workspace: workspaceDelegate.workspace
                pulseEnabled: Settings.options.bar.workspaces.urgentPulse
                reducedMotion: root.reducedMotion

                onActivated: function(workspaceId) {
                    root.focusRequested(workspaceId);
                }

                onWheelRequested: function(delta) {
                    root.handleWheelDelta(delta);
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

    function handleWheelDelta(delta) {
        var workspaceId = workspaceIdForWheel(delta);
        if (workspaceId.length > 0) {
            focusRequested(workspaceId);
        }
    }

    function workspaceIdForWheel(delta) {
        if (delta === 0 || workspaceCount === 0) {
            return "";
        }

        var currentIndex = workspaceModel.findIndex(function(workspace) {
            return workspace.active === true;
        });

        if (currentIndex < 0) {
            return "";
        }

        var step = delta < 0 ? 1 : -1;
        if (Settings.options.bar.workspaces.reverseScroll) {
            step = -step;
        }

        var nextIndex = currentIndex + step;
        nextIndex = Settings.options.bar.workspaces.scrollLoop
            ? (nextIndex + workspaceCount) % workspaceCount
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

    function syncWorkspaceModel() {
        var nextWorkspaces = workspaceModel && workspaceModel.length !== undefined ? workspaceModel : [];
        for (var oldIndex = renderedWorkspaces.count - 1; oldIndex >= 0; oldIndex--) {
            var oldWorkspaceId = String(renderedWorkspaces.get(oldIndex).workspace.id);
            if (!nextWorkspaces.some(function(workspace) {
                return String(workspace.id) === oldWorkspaceId;
            })) {
                renderedWorkspaces.remove(oldIndex);
            }
        }

        for (var nextIndex = 0; nextIndex < nextWorkspaces.length; nextIndex++) {
            var workspace = nextWorkspaces[nextIndex];
            var existingIndex = renderedWorkspaceIndex(workspace.id);
            if (existingIndex < 0) {
                renderedWorkspaces.insert(nextIndex, workspaceRole(workspace));
                continue;
            }

            if (existingIndex !== nextIndex) {
                renderedWorkspaces.move(existingIndex, nextIndex, 1);
            }
            renderedWorkspaces.set(nextIndex, workspaceRole(workspace));
        }
    }

    function renderedWorkspaceIndex(workspaceId) {
        var id = String(workspaceId);
        for (var index = 0; index < renderedWorkspaces.count; index++) {
            if (String(renderedWorkspaces.get(index).workspace.id) === id) {
                return index;
            }
        }
        return -1;
    }

    function workspaceRole(workspace) {
        return {
            "workspace": {
                "id": String(workspace.id),
                "index": Number(workspace.index),
                "outputName": String(workspace.outputName || ""),
                "name": String(workspace.name || ""),
                "active": workspace.active === true,
                "focused": workspace.focused === true,
                "urgent": workspace.urgent === true,
                "hasWindows": String(workspace.activeWindowId || "").length > 0
            }
        };
    }
}
