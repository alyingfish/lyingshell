import QtQuick
import QtQuick.Window
import QtTest
import Quickshell.Networking
import qs.Services
import qs.Modules.QuickSettings.Detail.Pages

// WifiDetailPage feeds its hero / saved / other groups through ScriptModels,
// which diff by network identity: a re-sort MOVES the affected row's
// delegate instead of rebuilding the list. Reassigning a plain-array model
// (the old approach) reset the Repeater and recreated every delegate; when a
// scan-driven re-sort landed while a row was mid state-transition
// (scrolling), destroying it crashed the shell in Qt's animation timer. This
// test guards that grouping and that delegates are reused, not recreated.
Window {
    id: root

    visible: true
    width: 424
    height: 760

    WifiDetailPage {
        id: page

        width: parent.width
        height: parent.height
    }

    TestCase {
        id: tester

        name: "WifiDetailRefresh"

        // The list body is async-incubated by DetailPage; grab it once loaded.
        property var body: null

        function rowIn(repeater, name) {
            for (var i = 0; i < repeater.count; i++) {
                var it = repeater.itemAt(i);
                if (it && it.modelData && it.modelData.name === name) {
                    return it;
                }
            }
            return null;
        }

        function test_list_and_reuse() {
            tryVerify(() => page.bodyItem !== null, 5000, "async body loads");
            body = page.bodyItem;
            tryVerify(() => body.heroRows.count > 0, 5000, "refresh fills the models");

            // Groups: connected hero, saved (known), other (unknown).
            compare(body.heroRows.count, 1, "one connected hero card");
            compare(body.heroRows.itemAt(0).modelData.name, "Homelab-5G", "connected network is the hero");
            compare(body.savedRows.count, 1, "known network sits in Saved");
            compare(body.savedRows.itemAt(0).modelData.name, "Homelab", "Homelab is the saved row");
            compare(body.rows.count, 8, "unknown networks fill Other networks");

            // Sub-bar jitter changes nothing: same delegate instance.
            var cafe = rowIn(body.rows, "Café Aurora Guest");
            verify(cafe !== null, "Café Aurora Guest row present");
            Networking.wifiNets[2].signalStrength = 0.58; // 0.6 -> 0.58, still bar 3
            body.refresh();
            verify(rowIn(body.rows, "Café Aurora Guest") === cafe, "sub-bar jitter keeps the delegate");

            // Crossing a signal bar reorders the group. The moved row keeps
            // its delegate instance (a move, not a rebuild) -- the crash guard.
            var fritz = rowIn(body.rows, "FRITZ!Box 7590");
            verify(fritz !== null, "FRITZ!Box row present");
            Networking.wifiNets[3].signalStrength = 0.6; // bar 1 -> bar 3, moves up
            body.refresh();
            verify(rowIn(body.rows, "FRITZ!Box 7590") === fritz, "reordered row keeps its delegate instance");

            // Toggling wifi off empties every group; back on repopulates.
            Networking.wifiEnabled = false;
            body.refresh();
            compare(body.heroRows.count + body.savedRows.count + body.rows.count, 0, "disabled wifi clears the groups");
            Networking.wifiEnabled = true;
            body.refresh();
            compare(body.heroRows.count + body.savedRows.count + body.rows.count, 10, "re-enabled wifi repopulates");

            // The header refresh action forces a fresh scan and re-reads the
            // list: with wifi on it kicks WifiScan.rescan()...
            var scansBefore = WifiScan.rescanCount;
            page.refreshRequested();
            compare(WifiScan.rescanCount, scansBefore + 1, "refresh forces a NetworkManager rescan");
            compare(body.heroRows.count + body.savedRows.count + body.rows.count, 10, "refresh keeps the populated groups");

            // ...and with wifi off it clears every group without a scan (the
            // radio can't scan), proving the model-refresh wiring.
            Networking.wifiEnabled = false;
            page.refreshRequested();
            compare(WifiScan.rescanCount, scansBefore + 1, "no rescan while the radio is off");
            compare(body.heroRows.count + body.savedRows.count + body.rows.count, 0, "the header refresh re-reads the models");

            console.log("PASS: wifi detail refresh");
        }
    }
}
