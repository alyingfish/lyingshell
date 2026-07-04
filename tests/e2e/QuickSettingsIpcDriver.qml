import QtQuick
import QtTest
import Quickshell.Io

// Test-only IPC driver for the quick-settings e2e test. QuickSettings.qml
// loads this file when LYINGSHELL_QS_E2E_DRIVER points at it and hands us
// its root as `view`; product builds never register an IpcHandler.
//
// Usage: quickshell ipc --path <repo> call quicksettings <fn> [args...]
Item {
    id: root

    property var view: null

    // Synthesizes real QWheelEvents into the live window's delivery chain
    // (same helper TestCase.mouseWheel uses), so the e2e test can exercise
    // hover-wheel behavior that quickshell IPC cannot reach.
    TestEvent {
        id: events
    }

    IpcHandler {
        target: "quicksettings"

        function state(): string {
            return root.view.serializeState();
        }

        function openPanel(): void {
            root.view.panelOpen = true;
        }

        function closePanel(): void {
            root.view.panelOpen = false;
        }

        function setDetail(name: string): void {
            root.view.setDetail(name);
        }

        function setPage(value: string): void {
            root.view.e2eSetPage(Number(value));
        }

        // Vertical wheel over the first tile (first row/column center).
        function wheelTiles(delta: string): void {
            const item = root.view.e2eTileArea;
            events.mouseWheel(item, item.width / 4, item.height / 4, Qt.NoButton, Qt.NoModifier, 0, Number(delta), -1);
        }

        // Vertical wheel over the empty column gap between the two tiles.
        function wheelTileGap(delta: string): void {
            const item = root.view.e2eTileArea;
            events.mouseWheel(item, item.width / 2, item.height / 4, Qt.NoButton, Qt.NoModifier, 0, Number(delta), -1);
        }

        // Vertical wheel over the volume slider row.
        function wheelVolume(delta: string): void {
            const item = root.view.e2eVolumeRow;
            events.mouseWheel(item, item.width / 2, item.height / 2, Qt.NoButton, Qt.NoModifier, 0, Number(delta), -1);
        }

        // Vertical wheel over the lower panel body (the detail list card
        // while a detail page is open) to scroll overlong lists.
        function wheelDetail(delta: string): void {
            const item = root.view.e2ePanel;
            events.mouseWheel(item, item.width / 2, item.height * 0.6, Qt.NoButton, Qt.NoModifier, 0, Number(delta), -1);
        }

        function setVolume(value: string): void {
            root.view.e2eSetVolume(Number(value));
        }

        function toggleMuted(): void {
            root.view.e2eToggleMuted();
        }

        function setBrightness(value: string): void {
            root.view.e2eSetBrightness(Number(value));
        }

        function toggleNightLight(): void {
            root.view.e2eToggleNightLight();
        }

        function toggleDarkStyle(): void {
            root.view.e2eToggleDarkStyle();
        }

        function toggleDoNotDisturb(): void {
            root.view.e2eToggleDoNotDisturb();
        }
    }
}
