pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import qs.Services.Niri

// Shell command layer: the one CLI surface external processes (niri binds,
// scripts) use to drive shell surfaces. Per-screen surfaces register a small
// api object keyed by output name; calls route to the focused output via the
// Niri singleton, so "toggle" always acts on the monitor the user is on.
//
//   qs ipc -p <repo> call panels toggle quicksettings
//   qs ipc -p <repo> call tools colorPicker
//
// scripts/ctl.sh wraps the `-p <repo>` addressing; `qs ipc -p <repo> show`
// lists every target. New panels only register here; new tools add a typed
// function to the `tools` handler (untyped functions are not exported).
Singleton {
    id: root

    // name -> ({ screenName -> api }); api = { isOpen(), setOpen(bool),
    // pickColor() }. Plain object, never bound to — mutated in place.
    property var _panels: ({})

    function registerPanel(name, screenName, api) {
        const byScreen = _panels[name] || {};
        byScreen[screenName] = api;
        _panels[name] = byScreen;
    }

    function unregisterPanel(name, screenName) {
        const byScreen = _panels[name];
        if (!byScreen)
            return;
        delete byScreen[screenName];
        if (Object.keys(byScreen).length === 0)
            delete _panels[name];
    }

    // Focused output's instance, else any registered one (single-monitor
    // before the first focus event, or an output niri no longer reports).
    function panelApi(name) {
        const byScreen = _panels[name];
        if (!byScreen)
            return null;
        if (byScreen[Niri.focusedOutputName])
            return byScreen[Niri.focusedOutputName];
        const screens = Object.keys(byScreen);
        return screens.length > 0 ? byScreen[screens[0]] : null;
    }

    function setPanelOpen(name, mode) {
        const api = panelApi(name);
        if (!api)
            return "unknown panel: " + name;
        const open = mode === "toggle" ? !api.isOpen() : mode === "open";
        api.setOpen(open);
        return open ? "open" : "closed";
    }

    IpcHandler {
        target: "panels"

        function toggle(name: string): string {
            return root.setPanelOpen(name, "toggle");
        }

        function open(name: string): string {
            return root.setPanelOpen(name, "open");
        }

        function close(name: string): string {
            return root.setPanelOpen(name, "close");
        }

        function list(): string {
            return Object.keys(root._panels).sort().join("\n");
        }
    }

    IpcHandler {
        target: "tools"

        // Routes through the focused output's quick-settings panel so the
        // full pick flow runs (clipboard copy, recent colors, readout page).
        function colorPicker(): string {
            const api = root.panelApi("quicksettings");
            if (!api)
                return "unavailable";
            api.pickColor();
            return "picking";
        }
    }
}
