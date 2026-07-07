import QtQuick
import QtQuick.Window
import QtTest
import Quickshell.Networking
import qs.Modules.QuickSettings.Widgets

// WifiDetailPage feeds its sorted top-10 list through a ScriptModel, which
// diffs by network identity: a re-sort MOVES the affected row's delegate
// instead of rebuilding the whole list. Reassigning a plain-array model (the
// old approach) reset the Repeater and recreated every delegate; when a
// scan-driven re-sort landed while a row was mid state-transition (scrolling),
// destroying it crashed the shell in Qt's animation timer. This test guards
// that the delegate is reused, not recreated.
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

        function rowFor(name) {
            for (var i = 0; i < page.rows.count; i++) {
                var it = page.rows.itemAt(i);
                if (it && it.modelData && it.modelData.name === name) {
                    return it;
                }
            }
            return null;
        }

        function test_list_and_reuse() {
            // Top 10, connected network first.
            compare(page.rows.count, 10, "top-10 networks listed");
            compare(page.rows.itemAt(0).modelData.name, "Homelab-5G", "connected network sorts first");

            // Sub-bar jitter changes nothing: same delegate instance.
            var five = rowFor("Homelab-5G");
            verify(five !== null, "Homelab-5G row present");
            Networking.wifiNets[0].signalStrength = 0.88; // 0.9 -> 0.88, still bar 4
            page.refresh();
            verify(rowFor("Homelab-5G") === five, "sub-bar jitter keeps the delegate");

            // Crossing a signal bar reorders the list. The moved row keeps its
            // delegate instance (a move, not a rebuild) -- the crash guard.
            var homelab = rowFor("Homelab");
            verify(homelab !== null, "Homelab row present");
            Networking.wifiNets[1].signalStrength = 0.5; // bar 4 -> bar 2, drops down
            page.refresh();
            verify(rowFor("Homelab") === homelab, "reordered row keeps its delegate instance");

            // Toggling wifi off empties the list; back on repopulates.
            Networking.wifiEnabled = false;
            page.refresh();
            compare(page.rows.count, 0, "disabled wifi clears the list");
            Networking.wifiEnabled = true;
            page.refresh();
            compare(page.rows.count, 10, "re-enabled wifi repopulates the list");

            console.log("PASS: wifi detail refresh");
        }
    }
}
