import QtQuick
import QtQuick.Window
import QtTest
import qs.Commons.Settings
import qs.Modules.QuickSettings.Widgets
import qs.Services.Niri
import "../../Modules/QuickSettings"

// Color readout page under offscreen qml6 (mocked Niri/Settings): the
// M3-expressive layout fills the detail viewport exactly (no scroll, no gap,
// with a floor so tiny viewports scroll instead of crushing the hero), the
// Recent grid reloads a tapped pick into the readout, the clear button
// empties the history without dropping the readout, and a live pick lands in
// the settings-persisted history (deduped, capped) through the panel.
Window {
    id: root

    visible: true
    width: 424
    height: 760

    // Standalone readout page at the panel's locked geometry: 320 content
    // width, 302 stack height -> a 262px body viewport (302 - 40 chrome),
    // matching the collapsed main view measured under the same mocks.
    ColorDetailPage {
        id: page

        width: 320
        height: 302
    }

    // Real panel over the same mocks: owns recording picks into Settings.
    QuickSettingsPanel {
        id: panel

        y: 320
        width: 344
    }

    TestCase {
        id: tester

        name: "ColorReadout"

        // Same completion counter as tst_quicksettings_motion.qml: qml6 has
        // no per-test reporting, so the alphabetically-last case emits the
        // wrapper's PASS marker only when every case ran to the end.
        property int passedTests: 0
        property var body: null

        function initTestCase() {
            Settings.options.quickSettings.colorPicker.recentColors = ["#112233", "#445566", "#778899"];
        }

        function test_a_layout_fills_viewport() {
            tryVerify(() => page.bodyItem !== null, 5000, "async body loads");
            body = page.bodyItem;

            // No live pick yet: the readout falls back to the newest recent.
            verify(body.hasColor, "recents alone light the readout");
            compare(body.shownHex, "#112233", "readout falls back to the newest recent");

            // Fits exactly: the hero absorbs the leftover, so the body is
            // precisely the 262px viewport - no scroll, no bottom gap.
            tryVerify(() => Math.abs(body.height - 262) < 0.5, 5000, "body fills the viewport exactly, got " + body.height);

            // Below the floor the fixed sections win (48px hero + rows +
            // recents + gaps = 254) and the page scrolls instead.
            page.height = 200;
            tryVerify(() => Math.abs(body.height - 254) < 0.5, 5000, "tiny viewports overflow at the 254px floor, got " + body.height);
            page.height = 302;
            tryVerify(() => Math.abs(body.height - 262) < 0.5, 5000, "restored viewport refits");
            tester.passedTests++;
        }

        function test_b_recent_tap_reloads() {
            const cell = findChild(page, "recentCell-1");
            verify(cell !== null && cell.visible, "second recent slot is filled");
            mouseClick(cell);
            compare(body.shownHex, "#445566", "tapping a thumbnail reloads it into the readout");
            verify(cell.current, "the shown thumbnail marks itself current");
            const empty = findChild(page, "recentCell-3");
            verify(empty !== null && !empty.visible, "unfilled slots are inert sockets");
            tester.passedTests++;
        }

        function test_c_clear_history() {
            const clearBtn = findChild(page, "clearRecents");
            verify(clearBtn !== null && clearBtn.visible, "clear action shows while history exists");
            mouseClick(clearBtn);
            compare(Settings.options.quickSettings.colorPicker.recentColors.length, 0, "clear empties the persisted history");
            compare(body.recents.length, 0, "the grid collapses to sockets");
            verify(body.hasColor, "the readout keeps its color through a clear");
            compare(body.shownHex, "#445566", "the shown color survives the clear");
            verify(!clearBtn.visible, "clear action hides with nothing to clear");
            tester.passedTests++;
        }

        function test_d_pick_records_and_rearms() {
            panel.beginColorPick();
            wait(50); // mock Niri replies via Qt.callLater
            compare(panel.detail, "color", "the pick reply opens the readout");
            const recents = Settings.options.quickSettings.colorPicker.recentColors;
            compare(recents.length, 1, "the pick lands in the history");
            compare(recents[0], "#8150ff", "newest pick sits first");
            compare(body.shownHex, "#8150ff", "a fresh pick re-arms the readout past the tap override");
            compare(body.copiedFormat, "hex", "the auto-copied HEX row claims the check");
            compare(body.copiedHex, "#8150ff", "the check is pinned to the picked color");

            // Re-picking a known color moves it to the front, no duplicate.
            panel.recordRecentColor("#112233");
            panel.recordRecentColor("#8150ff");
            const deduped = Settings.options.quickSettings.colorPicker.recentColors;
            compare(deduped.length, 2, "re-recording an existing color never duplicates");
            compare(deduped[0], "#8150ff", "a re-record moves the color to the front");

            // History is capped at the grid's slot count, newest first.
            for (let i = 1; i <= 9; i++) {
                panel.recordRecentColor("#00000" + i);
            }
            const capped = Settings.options.quickSettings.colorPicker.recentColors;
            compare(capped.length, panel.maxRecentColors, "history caps at the grid size");
            compare(capped[0], "#000009", "the cap drops the oldest entries");
            tester.passedTests++;
        }

        // Alphabetically last: emits the wrapper's required marker only when
        // every case above completed (see passedTests).
        function test_zz_all_completed() {
            compare(tester.passedTests, 4, "every readout case ran to completion");
            console.log("PASS: color readout contract");
        }
    }
}
