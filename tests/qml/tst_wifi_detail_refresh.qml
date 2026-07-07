import QtQuick
import QtQuick.Window
import QtTest
import Quickshell.Networking
import qs.Modules.QuickSettings.Widgets

// WifiDetailPage stops rebuilding the whole delegate list on every scan tick:
// the cached networkList (and its signature) only change when the visible
// order or membership changes, so sub-bar signal jitter leaves the array
// reference — and thus the delegates — untouched.
Window {
    id: root

    visible: true
    width: 424
    height: 760

    WifiDetailPage {
        id: page

        width: parent.width
    }

    TestCase {
        id: tester

        name: "WifiDetailRefresh"

        function test_signature_gate() {
            // Top 10, connected network first.
            compare(page.networkList.length, 10, "top-10 networks listed");
            compare(page.networkList[0].name, "Homelab-5G", "connected network sorts first");

            // A no-op refresh keeps the same array (no delegate churn).
            var ref = page.networkList;
            var sig = page._signature;
            page.refresh();
            verify(page.networkList === ref, "unchanged data keeps the same list reference");
            compare(page._signature, sig, "unchanged data keeps the same signature");

            // Jitter within the same signal bar: still no churn.
            Networking.wifiNets[1].signalStrength = 0.82; // Homelab 0.85 -> 0.82, still bar 4
            page.refresh();
            verify(page.networkList === ref, "sub-bar jitter keeps the same list reference");

            // Crossing a signal bar changes order -> new list.
            Networking.wifiNets[1].signalStrength = 0.5; // Homelab -> bar 2
            page.refresh();
            verify(page.networkList !== ref, "bar crossing rebuilds the list");
            verify(page.networkList[1].name !== "Homelab", "weakened network dropped down the list");

            // Toggling wifi off empties the list; back on repopulates.
            Networking.wifiEnabled = false;
            page.refresh();
            compare(page.networkList.length, 0, "disabled wifi clears the list");
            Networking.wifiEnabled = true;
            page.refresh();
            compare(page.networkList.length, 10, "re-enabled wifi repopulates the list");

            console.log("PASS: wifi detail refresh");
        }
    }
}
