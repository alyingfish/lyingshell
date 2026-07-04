import QtQuick
import Quickshell.Io

// Test-only IPC driver for the quick-settings e2e test. QuickSettings.qml
// loads this file when LYINGSHELL_QS_E2E_DRIVER points at it and hands us
// its root as `view`; product builds never register an IpcHandler.
//
// Usage: quickshell ipc --path <repo> call quicksettings <fn> [args...]
Item {
    id: root

    property var view: null

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
