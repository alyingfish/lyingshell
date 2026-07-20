import QtQuick
import QtQuick.Window
import QtTest
import Quickshell.Networking
import qs.Services
import qs.Modules.QuickSettings.Detail.Pages

// WifiDetailPage drives hero / Saved / Other as contiguous slices of ONE
// ScriptModel behind ONE Repeater, which diffs by network identity: a
// re-sort or a regroup MOVES the affected row's delegate instead of
// rebuilding it. Destroying a delegate mid state-transition (the old
// plain-array rebuilds, and later the per-group Repeaters that made a
// connect/disconnect a cross-model destroy+create) crashed the shell in
// Qt's animation timer. This test guards the grouping and that delegates
// are reused — across re-sorts AND across group changes.
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
            tryVerify(() => body.rows.count > 0, 5000, "refresh fills the model");

            // Groups: connected hero, saved (known), other (unknown) — slice
            // sizes exposed as counts, rows ordered hero → saved → other.
            compare(body.heroCount, 1, "one connected hero card");
            compare(body.rows.itemAt(0).modelData.name, "Homelab-5G", "connected network is the hero");
            compare(body.savedCount, 1, "known network sits in Saved");
            compare(body.rows.itemAt(1).modelData.name, "Homelab", "Homelab is the saved row");
            compare(body.otherCount, 8, "unknown networks fill Other networks");
            compare(body.rows.count, 10, "one repeater carries every group");

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

            // A saved connected network dropping out (phone hotspot vanishes,
            // then NM deactivates on the refresh-forced rescan) moves the
            // hero into the Saved group. With one model that's a delegate
            // MOVE while its state-flip animations run -- per-group
            // Repeaters made it a destroy+create, which SIGSEGVed in Qt's
            // animation timer.
            var heroNet = Networking.wifiNets[0]; // Homelab-5G, connected+known
            var heroRow = rowIn(body.rows, "Homelab-5G");
            heroNet.signalStrength = 0.5; // sorts below Homelab once regrouped
            heroNet.connected = false;
            body.refresh();
            compare(body.heroCount, 0, "no hero after the connection drops");
            compare(body.savedCount, 2, "the dropped network lands in Saved");
            compare(body.rows.itemAt(1).modelData.name, "Homelab-5G", "regrouped row re-sorts by strength");
            verify(rowIn(body.rows, "Homelab-5G") === heroRow, "hero-to-saved regroup keeps the delegate instance -- the crash guard");

            // Reconnecting moves it back up to the hero slot, same delegate.
            heroNet.signalStrength = 0.9;
            heroNet.connected = true;
            body.refresh();
            compare(body.heroCount, 1, "reconnect restores the hero");
            compare(body.rows.itemAt(0).modelData.name, "Homelab-5G", "the reconnected network is the hero again");
            verify(rowIn(body.rows, "Homelab-5G") === heroRow, "saved-to-hero regroup keeps the delegate instance");

            // Toggling wifi off empties the model; back on repopulates.
            Networking.wifiEnabled = false;
            body.refresh();
            compare(body.rows.count, 0, "disabled wifi clears the list");
            Networking.wifiEnabled = true;
            body.refresh();
            compare(body.rows.count, 10, "re-enabled wifi repopulates");

            // The header refresh action forces a fresh scan and re-reads the
            // list: with wifi on it kicks WifiScan.rescan()...
            var scansBefore = WifiScan.rescanCount;
            page.refreshRequested();
            compare(WifiScan.rescanCount, scansBefore + 1, "refresh forces a NetworkManager rescan");
            compare(body.rows.count, 10, "refresh keeps the populated list");

            // ...and with wifi off it clears every group without a scan (the
            // radio can't scan), proving the model-refresh wiring.
            Networking.wifiEnabled = false;
            page.refreshRequested();
            compare(WifiScan.rescanCount, scansBefore + 1, "no rescan while the radio is off");
            compare(body.rows.count, 0, "the header refresh re-reads the model");

            console.log("PASS: wifi detail refresh");
        }
    }
}
