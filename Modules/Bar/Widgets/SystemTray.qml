import QtQuick
import Quickshell
import Quickshell.Services.SystemTray as SysTray
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import "TrayPinning.js" as TrayPinning

// System tray: overflow button (left) + pinned zone (right). Unpinned items
// live in a popover below the overflow button. Items are pinned/unpinned by
// dragging between the zones; the result persists to
// Settings.options.bar.tray.pinnedRegexes.
//
// Everything that must escape the bar strip (popover, tooltip, drag avatar)
// renders in `overlay`, reparented to the window contentItem. Bar.qml expands
// the window to full screen height while `expanded` is true, so popover +
// drag stay one QtQuick scene: no cross-window coordinates or stacking.
Item {
    id: root

    // Fed by Bar.qml so the overlay can track bar geometry.
    property bool barHidden: false
    property rect barSurfaceRect

    readonly property var trayItems: SysTray.SystemTray.items.values
    readonly property var pinnedRegexes: Settings.options.bar.tray.pinnedRegexes || []
    readonly property var traySplit: TrayPinning.partition(trayItems, pinnedRegexes)
    readonly property var pinnedItems: traySplit.pinned
    readonly property var overflowItems: traySplit.overflow

    property bool popoverOpen: false

    // Drag state. dragItem !== null while a tray icon is being dragged.
    property var dragItem: null
    property bool dragFromPinned: false
    property point dragPoint: Qt.point(0, 0)
    // "pinned" | "overflow" | "unpinBtn" | "blocked"
    property string dropZone: "blocked"
    property int dropIndex: -1
    readonly property bool dragActive: dragItem !== null
    readonly property string dropIcon: dropZone === "pinned" ? "keep" : (dropZone === "overflow" || dropZone === "unpinBtn") ? "keep_off" : "block"

    // Insert pulse: the just-dropped icon grows in; the others jump (no move
    // animation on purpose, per spec).
    property string pulseId: ""
    property int pulseStamp: 0

    // Bar.qml: full-screen window + full input mask while true.
    readonly property bool expanded: popoverOpen || dragActive || popoverCard.openProgress > 0.001
    // Bar.qml: transparent strip below the bar kept for tooltips while collapsed.
    readonly property real collapsedReserve: 48

    // Uniform tray cell metrics (button implicit size = token container + insets).
    readonly property real cellWidth: MD.Token.icon_button.xsmall.default_width + 8
    readonly property real cellHeight: MD.Token.icon_button.xsmall.container_height + 8
    readonly property real barBottom: barSurfaceRect.y + barSurfaceRect.height

    implicitWidth: trayRow.implicitWidth
    implicitHeight: trayRow.implicitHeight

    onBarHiddenChanged: if (barHidden) popoverOpen = false
    // Last overflow item pinned away: nothing left to show.
    onOverflowItemsChanged: if (overflowItems.length === 0 && !dragActive) popoverOpen = false
    onTraySplitChanged: console.info("[Tray] pinned=" + JSON.stringify(traySplit.pinned.map(i => i.id)) + " overflow=" + JSON.stringify(traySplit.overflow.map(i => i.id)))
    onPopoverOpenChanged: console.info("[Tray] popover " + (popoverOpen ? "open" : "closed"))

    // Reactive overlay-space position. mapToItem registers no QML
    // dependencies, so bindings built on it go stale whenever an ancestor
    // moves after the fact (startup Row polish, pin/unpin growing the pinned
    // row, bar shape morphs). Summing x/y up the parent chain reads each
    // ancestor's position property, so the binding re-fires on any move.
    // The chain stops at overlay.parent (the window contentItem); overlay
    // sits at 0,0 inside it, so the sums are already overlay coordinates.
    function overlayX(item) {
        let x = 0;
        for (let it = item; it && it !== overlay.parent; it = it.parent)
            x += it.x;
        return x;
    }

    function overlayY(item) {
        let y = 0;
        for (let it = item; it && it !== overlay.parent; it = it.parent)
            y += it.y;
        return y;
    }

    function itemLabel(item) {
        return item.tooltipTitle || item.title || item.id;
    }

    function activateItem(item, button) {
        console.info("[Tray] activate " + item.id);
        if (item.onlyMenu) {
            openMenu(item, button);
            return;
        }
        item.activate();
    }

    function secondaryActivateItem(item) {
        console.info("[Tray] secondaryActivate " + item.id);
        item.secondaryActivate();
    }

    function scrollItem(item, delta) {
        console.info("[Tray] scroll " + item.id + " " + delta);
        item.scroll(delta, false);
    }

    function openMenu(item, button) {
        if (!item.hasMenu)
            return;
        console.info("[Tray] menu " + item.id);
        menuAnchor.menu = item.menu;
        menuAnchor.anchor.item = button;
        menuAnchor.open();
    }

    function writeRegexes(regexes) {
        Settings.options.bar.tray.pinnedRegexes = regexes;
    }

    function pinItemAt(item, index) {
        console.info("[Tray] pin " + item.id + " @" + index);
        writeRegexes(TrayPinning.pinAt(pinnedRegexes, trayItems, item, index));
        pulseId = item.id;
        pulseStamp++;
    }

    function unpinItem(item) {
        console.info("[Tray] unpin " + item.id);
        writeRegexes(TrayPinning.unpin(pinnedRegexes, item));
        pulseId = item.id;
        pulseStamp++;
    }

    // --- drag controller ------------------------------------------------

    function beginDrag(item, fromPinned) {
        dragItem = item;
        dragFromPinned = fromPinned;
        dropZone = "blocked";
        dropIndex = -1;
        tooltipDelay.stop();
        tooltip.targetItem = null;
        // Give unpin drags their drop target right away, Windows-flyout style.
        if (fromPinned)
            popoverOpen = true;
        console.info("[Tray] dragStart " + item.id + " fromPinned=" + fromPinned);
    }

    function updateDrag(button, dragX, dragY) {
        if (!dragActive)
            return;
        updateDragAt(button.mapToItem(overlay, dragX, dragY));
    }

    // `point` is in overlay coordinates.
    function updateDragAt(point) {
        dragPoint = point;

        const btnOrigin = overflowButton.mapToItem(overlay, 0, 0);
        const rowOrigin = pinnedRow.mapToItem(overlay, 0, 0);
        const target = TrayPinning.classifyDrag(dragPoint.x, dragPoint.y, {
            "fromPinned": dragFromPinned,
            "barBottom": root.barBottom,
            "button": { "x": btnOrigin.x, "width": overflowButton.width, "visible": overflowButton.visible },
            "row": { "x": rowOrigin.x, "width": pinnedRow.width },
            "pinnedCount": pinnedItems.length,
            "overflowCount": overflowItems.length,
            "card": { "x": popoverCard.x, "y": popoverCard.y, "width": popoverCard.width, "height": popoverCard.height, "visible": popoverCard.visible },
            "grid": { "x": popoverCard.x + overflowGrid.x, "y": popoverCard.y + overflowGrid.y },
            "cellWidth": root.cellWidth,
            "cellHeight": root.cellHeight
        });
        dropZone = target.zone;
        dropIndex = target.index;
    }

    function endDrag() {
        if (!dragActive)
            return;
        const item = dragItem;
        const zone = dropZone;
        let index = dropIndex;
        dragItem = null;
        if (zone === "pinned") {
            const currentIndex = pinnedItems.indexOf(item);
            if (currentIndex >= 0 && index > currentIndex)
                index--;
            pinItemAt(item, index);
        } else if (zone === "overflow" || zone === "unpinBtn") {
            unpinItem(item);
        } else {
            console.info("[Tray] dragCancel " + item.id);
        }
        dropZone = "blocked";
        dropIndex = -1;
    }

    // --- tooltip --------------------------------------------------------

    function requestTooltip(target, text) {
        if (dragActive)
            return;
        tooltipDelay.pendingTarget = target;
        tooltipDelay.pendingText = text;
        tooltipDelay.restart();
    }

    function releaseTooltip(target) {
        if (tooltipDelay.pendingTarget === target) {
            tooltipDelay.pendingTarget = null;
            tooltipDelay.stop();
        }
        if (tooltip.targetItem === target)
            tooltip.targetItem = null;
    }

    Timer {
        id: tooltipDelay

        property Item pendingTarget: null
        property string pendingText: ""

        interval: MD.Token.duration.long2
        repeat: false

        onTriggered: {
            if (pendingTarget && !root.dragActive) {
                tooltip.text = pendingText;
                tooltip.targetItem = pendingTarget;
            }
        }
    }

    QsMenuAnchor {
        id: menuAnchor

        anchor.window: root.QsWindow.window
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
    }

    // --- e2e surface ------------------------------------------------------
    // Plain functions consumed by the test-only IPC driver
    // (tests/e2e/TrayIpcDriver.qml). Product ships no IpcHandler; the driver
    // loads only when LYINGSHELL_TRAY_E2E_DRIVER points at it.

    function itemById(id) {
        return trayItems.find(i => i.id === id) || null;
    }

    function serializeState() {
        return JSON.stringify({
            "pinned": pinnedItems.map(i => i.id),
            "overflow": overflowItems.map(i => i.id),
            "popoverOpen": popoverOpen,
            "pinnedRegexes": pinnedRegexes,
            "dragging": dragActive ? dragItem.id : "",
            "dropZone": dropZone,
            "dropIndex": dropIndex,
            "geometry": {
                "barBottom": barBottom,
                "button": overlay.mapFromItem(overflowButton, 0, 0, overflowButton.width, overflowButton.height),
                "row": overlay.mapFromItem(pinnedRow, 0, 0, Math.max(pinnedRow.width, 1), Math.max(pinnedRow.height, 1)),
                "card": Qt.rect(popoverCard.x, popoverCard.y, popoverCard.width, popoverCard.height)
            }
        });
    }

    // Same beginDrag/updateDragAt/endDrag path as pointer drags, against
    // live geometry. x/y are window coordinates.
    function dragItemTo(id, x, y) {
        const item = itemById(id);
        if (!item)
            return "";
        if (!dragActive || dragItem !== item)
            beginDrag(item, pinnedItems.indexOf(item) >= 0);
        updateDragAt(Qt.point(x, y));
        return JSON.stringify({ "dropZone": dropZone, "dropIndex": dropIndex });
    }

    function dropDraggedItem() {
        endDrag();
        return JSON.stringify(pinnedRegexes);
    }

    function activateById(id) {
        const item = itemById(id);
        if (!item)
            return false;
        activateItem(item, overflowButton);
        return true;
    }

    function openMenuById(id) {
        const item = itemById(id);
        if (!item)
            return false;
        openMenu(item, overflowButton);
        return item.hasMenu;
    }

    function showTooltipById(id) {
        const item = itemById(id);
        if (!item)
            return false;
        tooltip.text = itemLabel(item);
        tooltip.targetItem = overflowButton;
        return true;
    }

    function hideTooltip() {
        tooltip.targetItem = null;
    }

    Loader {
        active: root.e2eDriverSource.length > 0
        source: root.e2eDriverSource

        onLoaded: item.view = root
    }

    readonly property string e2eDriverSource: String(Quickshell.env("LYINGSHELL_TRAY_E2E_DRIVER") || "")

    Row {
        id: trayRow

        spacing: 0

        MD.IconButton {
            id: overflowButton

            visible: root.overflowItems.length > 0
            mdState.type: MD.Enum.IBtStandard
            mdState.size: MD.Enum.XS
            mdState.widthMode: MD.Enum.NarrowWidth
            icon.name: "expand_more"
            icon.width: 16
            icon.height: 16

            checked: root.popoverOpen
            onClicked: root.popoverOpen = !root.popoverOpen

            onHoveredChanged: hovered ? root.requestTooltip(overflowButton, I18n.t("bar.tray.showHidden")) : root.releaseTooltip(overflowButton)

            // Chevron flips while open. Rotate the GLYPH, not the button, so
            // the button's layout box stays stable during bar shape morphs.
            contentItem: Item {
                implicitWidth: overflowButton.icon.width
                implicitHeight: overflowButton.icon.height
                opacity: overflowButton.mdState.contentOpacity
                rotation: overflowButton.checked ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: MD.Token.duration.short4
                        easing: MD.Token.easing.emphasized
                    }
                }

                MD.Icon {
                    anchors.centerIn: parent
                    name: overflowButton.icon.name
                    size: 16
                    color: overflowButton.mdState.textColor
                    fill: overflowButton.checked
                }
            }
        }

        Row {
            id: pinnedRow

            spacing: 0

            Repeater {
                id: pinnedRepeater

                model: root.pinnedItems

                TrayItemButton {
                    id: pinnedButton

                    required property var modelData

                    trayItemId: modelData.id
                    iconSource: modelData.icon
                    ghosted: root.dragActive && root.dragItem === modelData

                    onActivated: root.activateItem(modelData, pinnedButton)
                    onSecondaryActivated: root.secondaryActivateItem(modelData)
                    onMenuRequested: root.openMenu(modelData, pinnedButton)
                    onScrolled: delta => root.scrollItem(modelData, delta)
                    onHoveredChanged: hovered ? root.requestTooltip(pinnedButton, root.itemLabel(modelData)) : root.releaseTooltip(pinnedButton)

                    onDragStarted: root.beginDrag(modelData, true)
                    onDragMoved: (dragX, dragY) => root.updateDrag(pinnedButton, dragX, dragY)
                    onDragFinished: root.endDrag()

                    Connections {
                        target: root

                        function onPulseStampChanged() {
                            if (root.pulseId === pinnedButton.trayItemId)
                                insertPulse.restart();
                        }
                    }

                    SequentialAnimation {
                        id: insertPulse

                        NumberAnimation {
                            target: pinnedButton
                            property: "scale"
                            from: 0.5
                            to: 1.1
                            duration: MD.Token.duration.short4
                            easing: MD.Token.easing.emphasized_decelerate
                        }
                        NumberAnimation {
                            target: pinnedButton
                            property: "scale"
                            to: 1.0
                            duration: MD.Token.duration.short2
                            easing: MD.Token.easing.standard
                        }
                    }
                }
            }
        }
    }

    // Window-level overlay: popover, carets, tooltip, drag avatar.
    Item {
        id: overlay

        parent: root.QsWindow.window ? root.QsWindow.window.contentItem : null
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        z: 100

        // Click-catcher below the bar strip: any press outside the popover
        // card closes it. The bar strip itself stays interactive.
        MouseArea {
            id: catcher

            x: 0
            y: root.barBottom
            width: overlay.width
            height: Math.max(0, overlay.height - catcher.y)
            visible: root.popoverOpen
            acceptedButtons: Qt.AllButtons

            onPressed: root.popoverOpen = false
        }

        Item {
            id: popoverCard

            // 0 = hidden, 1 = open; drives the slide/fade in both directions.
            property real openProgress: root.popoverOpen ? 1 : 0
            readonly property real pad: 8

            Behavior on openProgress {
                NumberAnimation {
                    duration: MD.Token.duration.medium2
                    easing: MD.Token.easing.emphasized
                }
            }

            // Tracks the overflow button live through startup layout, bar
            // shape morphs, and pinned-row growth (see overlayX).
            readonly property real anchorCenterX: root.overlayX(overflowButton) + overflowButton.width / 2

            // Explicit cell math (positioners own their implicit size); an
            // empty popover keeps one cell as a valid unpin drop target.
            width: Math.min(4, Math.max(1, root.overflowItems.length)) * root.cellWidth + pad * 2
            height: Math.max(1, Math.ceil(root.overflowItems.length / 4)) * root.cellHeight + pad * 2
            x: Math.max(pad, Math.min(anchorCenterX - width / 2, overlay.width - width - pad))
            y: root.barBottom + pad - 12 * (1 - openProgress)
            opacity: openProgress
            visible: openProgress > 0.001

            MD.ElevationRectangle {
                anchors.fill: parent
                corners: MD.Util.corners(MD.Token.shape.corner.large)
                color: MD.Token.color.surface_container
                elevation: MD.Token.elevation.level2
                elevationVisible: true

                // Swallow presses on the card body so the catcher below
                // does not dismiss the popover.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                Grid {
                    id: overflowGrid

                    x: popoverCard.pad
                    y: popoverCard.pad
                    spacing: 0
                    // Compact icon grid: at most 4 columns, row-major wrap.
                    columns: Math.max(1, Math.min(4, root.overflowItems.length))

                    Repeater {
                        id: overflowRepeater

                        model: root.overflowItems

                        TrayItemButton {
                            id: overflowItemButton

                            required property var modelData

                            trayItemId: modelData.id
                            iconSource: modelData.icon
                            ghosted: root.dragActive && root.dragItem === modelData

                            onActivated: root.activateItem(modelData, overflowItemButton)
                            onSecondaryActivated: root.secondaryActivateItem(modelData)
                            onMenuRequested: root.openMenu(modelData, overflowItemButton)
                            onScrolled: delta => root.scrollItem(modelData, delta)
                            onHoveredChanged: hovered ? root.requestTooltip(overflowItemButton, root.itemLabel(modelData)) : root.releaseTooltip(overflowItemButton)

                            onDragStarted: root.beginDrag(modelData, false)
                            onDragMoved: (dragX, dragY) => root.updateDrag(overflowItemButton, dragX, dragY)
                            onDragFinished: root.endDrag()

                            Connections {
                                target: root

                                function onPulseStampChanged() {
                                    if (root.pulseId === overflowItemButton.trayItemId)
                                        overflowPulse.restart();
                                }
                            }

                            SequentialAnimation {
                                id: overflowPulse

                                NumberAnimation {
                                    target: overflowItemButton
                                    property: "scale"
                                    from: 0.5
                                    to: 1.1
                                    duration: MD.Token.duration.short4
                                    easing: MD.Token.easing.emphasized_decelerate
                                }
                                NumberAnimation {
                                    target: overflowItemButton
                                    property: "scale"
                                    to: 1.0
                                    duration: MD.Token.duration.short2
                                    easing: MD.Token.easing.standard
                                }
                            }
                        }
                    }
                }
            }

            // Insertion caret inside the popover grid (unpin target position).
            Rectangle {
                visible: root.dragActive && root.dropZone === "overflow" && root.dropIndex >= 0
                width: 2
                height: root.cellHeight - 8
                radius: width / 2
                color: MD.Token.color.primary
                x: {
                    const columns = overflowGrid.columns;
                    const index = Math.max(0, root.dropIndex);
                    const column = Math.min(index % columns, columns);
                    const endOfRow = index > 0 && index % columns === 0 && index >= root.overflowItems.length;
                    const gridColumn = endOfRow ? columns : column;
                    return overflowGrid.x + gridColumn * root.cellWidth - width / 2;
                }
                y: {
                    const columns = overflowGrid.columns;
                    const index = Math.max(0, root.dropIndex);
                    const endOfRow = index > 0 && index % columns === 0 && index >= root.overflowItems.length;
                    const row = endOfRow ? Math.floor((index - 1) / columns) : Math.floor(index / columns);
                    return overflowGrid.y + row * root.cellHeight + 4;
                }
            }
        }

        // Insertion caret in the pinned zone.
        Rectangle {
            visible: root.dragActive && root.dropZone === "pinned" && root.dropIndex >= 0
            width: 2
            height: root.cellHeight - 8
            radius: width / 2
            color: MD.Token.color.primary
            x: root.overlayX(pinnedRow) + root.dropIndex * root.cellWidth - width / 2
            y: root.overlayY(pinnedRow) + 4
        }

        // Hover tooltip: MD3 plain tooltip below the item, fade + rise.
        Rectangle {
            id: tooltip

            property Item targetItem: null
            property string text: ""
            readonly property bool shown: targetItem !== null && !root.dragActive && text.length > 0
            // Freeze the last position while targetItem is null so the fade-out
            // stays in place instead of snapping to the bottom-left corner.
            property real cachedCenterX: 0
            property real cachedBottom: 0
            readonly property real targetCenterX: {
                if (!targetItem)
                    return cachedCenterX;
                return cachedCenterX = root.overlayX(targetItem) + targetItem.width / 2;
            }
            readonly property real targetBottom: {
                if (!targetItem)
                    return cachedBottom;
                return cachedBottom = root.overlayY(targetItem) + targetItem.height;
            }

            width: tooltipLabel.implicitWidth + 16
            height: tooltipLabel.implicitHeight + 8
            x: Math.max(8, Math.min(targetCenterX - width / 2, overlay.width - width - 8))
            y: Math.max(targetBottom, root.barBottom) + 4 + 4 * (1 - opacity)
            radius: MD.Token.shape.corner.extra_small
            color: MD.Token.color.inverse_surface
            opacity: shown ? 1 : 0
            visible: opacity > 0.001

            Behavior on opacity {
                NumberAnimation {
                    duration: MD.Token.duration.short2
                    easing: MD.Token.easing.standard
                }
            }

            MD.Text {
                id: tooltipLabel

                anchors.centerIn: parent
                text: tooltip.text
                color: MD.Token.color.inverse_on_surface
                typescale: MD.Token.typescale.body_small
                font.family: Theme.textTypeface
            }
        }

        // Drag avatar: the icon follows the pointer; a badge below shows the
        // drop outcome (keep = pin, keep_off = unpin, block = return).
        Item {
            id: dragAvatar

            visible: root.dragActive
            x: root.dragPoint.x
            y: root.dragPoint.y

            Image {
                id: avatarIcon

                x: -width / 2
                y: -height / 2
                width: 16
                height: 16
                source: root.dragItem ? root.dragItem.icon : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
            }

            Rectangle {
                x: -width / 2
                y: avatarIcon.y + avatarIcon.height + 8
                width: dropBadgeIcon.implicitWidth + 8
                height: dropBadgeIcon.implicitHeight + 8
                radius: MD.Token.shape.corner.extra_small
                color: MD.Token.color.inverse_surface

                MD.Icon {
                    id: dropBadgeIcon

                    anchors.centerIn: parent
                    name: root.dropIcon
                    size: 16
                    color: MD.Token.color.inverse_on_surface
                }
            }
        }
    }
}
