import QtQuick
import QtTest
import Quickshell.Io
import Quickshell.Networking
import qs.Services

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

        // Expandable header rows (tools / power mode) for screenshot passes.
        function setTools(open: string): void {
            root.view.e2ePanel.toolsOpen = open === "true";
        }

        function setPmode(open: string): void {
            root.view.e2ePanel.pmodeOpen = open === "true";
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

        // --- network/bluetooth port hooks (wifi accordion, hotspot, toasts) --

        // The pushed detail page's body (holds expandedNetwork/expandedDevice).
        function _body(prop: string): var {
            function walk(item) {
                if (!item) {
                    return null;
                }
                if (prop in item) {
                    return item;
                }
                for (var i = 0; i < item.children.length; i++) {
                    const hit = walk(item.children[i]);
                    if (hit) {
                        return hit;
                    }
                }
                return null;
            }
            return walk(root.view.e2ePanel);
        }

        function netState(): string {
            const wifiBody = _body("expandedNetwork");
            const btBody = _body("expandedDevice");
            const dev = SystemStatus.wifiDevice;
            const adapter = SystemStatus.btAdapter;
            return JSON.stringify({
                "hotspotActive": SystemStatus.hotspotActive,
                "hotspotBusy": Hotspot.busy,
                "hotspotSsid": Hotspot.ssid,
                "connectivity": Networking.connectivity,
                "scannerEnabled": dev !== null && dev.scannerEnabled,
                "toastText": Toast.text,
                "toastActive": Toast.active,
                "hiddenBusy": HiddenNetwork.busy,
                "btDiscovering": adapter !== null && adapter.discovering,
                "btDiscoverable": adapter !== null && adapter.discoverable,
                "wifi": wifiBody === null ? null : {
                    "hero": wifiBody.heroRows.count,
                    "saved": wifiBody.savedRows.count,
                    "other": wifiBody.rows.count,
                    "expanded": (() => {
                        try {
                            const x = wifiBody.expandedNetwork;
                            return x !== null && x !== undefined ? (x.name || "hidden") : "";
                        } catch (error) {
                            return "";
                        }
                    })(),
                    "errorText": wifiBody.errorText
                },
                "bt": btBody === null ? null : {
                    "connected": btBody.heroRows.count,
                    "paired": btBody.pairedRows.count,
                    "nearby": btBody.rows.count
                }
            });
        }

        function wifiExpand(name: string): void {
            const body = _body("expandedNetwork");
            const dev = SystemStatus.wifiDevice;
            if (!body || !dev) {
                return;
            }
            if (name === "hidden") {
                body.expandedNetwork = body.hiddenSentinel;
                return;
            }
            const net = dev.networks.values.find(n => n !== null && n.name === name);
            if (net) {
                body.expandedNetwork = net;
            }
        }

        function wifiSecurity(name: string): string {
            const dev = SystemStatus.wifiDevice;
            const net = dev ? dev.networks.values.find(n => n !== null && n.name === name) : null;
            return net ? String(net.security) + " known=" + net.known : "none";
        }

        function btConnect(name: string): void {
            const adapter = SystemStatus.btAdapter;
            const device = adapter ? adapter.devices.values.find(d => d !== null && d.name === name) : null;
            if (device) {
                ConnectFeedback.watchBt(device);
                device.connect();
            }
        }

        function hotspotToggle(): void {
            Hotspot.toggle();
        }

        function hiddenJoin(ssid: string, psk: string): void {
            HiddenNetwork.join(ssid, psk);
        }
    }
}
