import QtQuick
import QtQuick.Window
import QtTest
import Quickshell.Services.UPower
import qs.Services
import qs.Modules.QuickSettings.Widgets

// Behavioral matrix for the header battery pill + power-mode row across the
// four real-world combinations of battery presence and power-profile daemon
// availability (plus the 2- vs 3-segment split). Renders the real PanelHeader
// and PowerModeRow against controllable UPower / PowerMode mocks and asserts
// what the user actually sees. Probes are the components' "Test-only surface".
//
// All cases live in ONE test function ending in the PASS marker: under plain
// qml6 a failed verify/compare aborts the function silently, so the marker is
// the only reliable "everything passed" signal (a cleanupTestCase marker would
// print even after a failure).
Window {
    id: root

    visible: true
    width: 360
    height: 240

    Column {
        spacing: 12

        PanelHeader {
            id: header

            width: 320
        }

        PowerModeRow {
            id: row

            width: 320
        }
    }

    TestCase {
        id: tester

        name: "PowerModeMatrix"

        // Drive the three inputs; bindings propagate synchronously through
        // SystemStatus, so a single tick is plenty.
        function apply(battery, available, hasPerf) {
            UPower.batteryPresent = battery;
            UPower.timeToEmpty = 5 * 3600 + 12 * 60; // discharging baseline
            PowerMode.available = available;
            PowerMode.hasPerformanceProfile = hasPerf;
            wait(10);
        }

        function test_matrix() {
            // 1a: battery + daemon + Performance -> 3 working segments.
            apply(true, true, true);
            verify(header.pillVisibleProbe, "1a: pill shows with a battery");
            verify(header.pillEnabledProbe, "1a: pill is clickable");
            compare(header.pillTextProbe, "87%", "1a: pill reads battery percent");
            compare(header.pillIconProbe, PowerMode.iconName, "1a: pill shows the profile glyph");
            compare(row.label, "5h 12m left", "1a: row reads the time estimate");
            verify(row.groupVisibleProbe, "1a: profile group is shown");
            verify(!row.noticeVisibleProbe, "1a: no soft notice with a daemon");
            compare(row.segmentCountProbe, 3, "1a: all three profiles are offered");

            // 1b: battery + daemon, no Performance -> 2 segments (< 3).
            apply(true, true, false);
            verify(header.pillVisibleProbe && header.pillEnabledProbe, "1b: pill usable");
            verify(row.groupVisibleProbe, "1b: profile group is shown");
            compare(row.segmentCountProbe, 2, "1b: Performance dropped, two segments");
            compare(row.label, "5h 12m left", "1b: row still reads the time estimate");

            // 2: battery + no daemon (this laptop) -> pill still expands to time.
            apply(true, false, true);
            verify(header.pillVisibleProbe, "2: pill shows with a battery");
            verify(header.pillEnabledProbe, "2: pill stays clickable with no daemon");
            compare(header.pillTextProbe, "87%", "2: pill reads battery percent");
            verify(header.pillIconProbe.indexOf("battery") === 0, "2: pill shows a battery glyph, got " + header.pillIconProbe);
            compare(row.label, "5h 12m left", "2: row reads the time estimate");
            verify(!row.groupVisibleProbe, "2: dead profile group is hidden");
            verify(row.noticeVisibleProbe, "2: soft 'no power profile' notice shows");

            // 2b: battery + no daemon + no estimate yet -> "Estimating…",
            // never a bogus default profile name.
            apply(true, false, true);
            UPower.timeToEmpty = 0;
            wait(10);
            compare(row.label, "Estimating…", "2b: no estimate reads 'Estimating…', not a profile");

            // 2c: sub-hour discharge -> minute-only "30m left", no dead "0h".
            apply(true, false, true);
            UPower.state = 2; // Discharging
            UPower.timeToEmpty = 30 * 60;
            wait(10);
            compare(row.label, "30m left", "2c: sub-hour discharge drops the '0h' prefix");

            // 2d: sub-minute discharge -> floors to "1m left", not "0h 0m".
            apply(true, false, true);
            UPower.state = 2; // Discharging
            UPower.timeToEmpty = 45;
            wait(10);
            compare(row.label, "1m left", "2d: sub-minute discharge floors to '1m left'");

            // 2e: sub-minute charge -> "1m until full".
            apply(true, false, true);
            UPower.state = 1; // Charging (87% < 100, so not full)
            UPower.timeToFull = 45;
            wait(10);
            compare(row.label, "1m until full", "2e: sub-minute charge floors to '1m until full'");

            // 2f: plugged in but held below full (PendingCharge) -> "Not charging".
            apply(true, false, true);
            UPower.state = 5; // PendingCharge
            wait(10);
            compare(row.label, "Not charging", "2f: held-below-full reads 'Not charging'");

            // 2g: charging with no estimate yet -> "Estimating…".
            apply(true, false, true);
            UPower.state = 1; // Charging
            UPower.timeToFull = 0;
            wait(10);
            compare(row.label, "Estimating…", "2g: charging with no estimate reads 'Estimating…'");

            // 3: no battery (PC) + daemon -> AC readout, full profile selector.
            apply(false, true, true);
            verify(header.pillVisibleProbe, "3: pill shows for the daemon");
            verify(header.pillEnabledProbe, "3: pill is clickable");
            compare(header.pillTextProbe, "AC", "3: pill reads AC on a desktop");
            compare(header.pillIconProbe, PowerMode.iconName, "3: pill shows the profile glyph");
            compare(row.label, "Balanced", "3: no battery -> label is the current profile");
            verify(row.groupVisibleProbe, "3: profile group is shown");
            compare(row.segmentCountProbe, 3, "3: all three profiles are offered");

            // 4: no battery (PC) + no daemon -> nothing to show, pill hidden.
            apply(false, false, true);
            verify(!header.pillVisibleProbe, "4: pill hidden with no battery and no daemon");

            console.log("PASS: power-mode battery-pill matrix");
        }
    }
}
