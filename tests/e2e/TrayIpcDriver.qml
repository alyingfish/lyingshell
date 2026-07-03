import QtQuick
import Quickshell.Io

// Test-only IPC driver for the system tray e2e test. SystemTray.qml loads
// this file when LYINGSHELL_TRAY_E2E_DRIVER points at it and hands us its
// root as `view`; product builds never register an IpcHandler.
//
// Usage: quickshell ipc --path <repo> call tray <fn> [args...]
Item {
    id: root

    property var view: null

    IpcHandler {
        target: "tray"

        function state(): string {
            return root.view.serializeState();
        }

        function openPopover(): void {
            root.view.popoverOpen = true;
        }

        function closePopover(): void {
            root.view.popoverOpen = false;
        }

        function dragTo(id: string, x: int, y: int): string {
            return root.view.dragItemTo(id, x, y);
        }

        function drop(): string {
            return root.view.dropDraggedItem();
        }

        function pin(id: string, index: int): string {
            const item = root.view.itemById(id);
            if (item)
                root.view.pinItemAt(item, index);
            return JSON.stringify(root.view.pinnedRegexes);
        }

        function unpin(id: string): string {
            const item = root.view.itemById(id);
            if (item)
                root.view.unpinItem(item);
            return JSON.stringify(root.view.pinnedRegexes);
        }

        function activate(id: string): bool {
            return root.view.activateById(id);
        }

        function menu(id: string): bool {
            return root.view.openMenuById(id);
        }

        function showTooltip(id: string): bool {
            return root.view.showTooltipById(id);
        }

        function hideTooltip(): void {
            root.view.hideTooltip();
        }
    }
}
