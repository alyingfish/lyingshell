pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

// On-demand Wi-Fi rescan for the network detail's refresh button. Documented
// gap: Quickshell.Networking exposes only the continuous `scannerEnabled`
// toggle, with no trigger to force an immediate scan, so a user-driven
// refresh shells out to the NetworkManager CLI. The scanner binding folds the
// fresh results back into the device's network list.
Singleton {
    id: root

    function rescan(): void {
        if (scanProcess.running) {
            return;
        }
        scanProcess.running = true;
    }

    Process {
        id: scanProcess

        command: ["nmcli", "device", "wifi", "rescan"]
    }
}
