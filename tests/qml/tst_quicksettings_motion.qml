import QtQuick
import QtQuick.Window
import QtTest
import Qcm.Material as MD
import "../../Modules/QuickSettings"

// Motion contract for the quick-settings panel under offscreen qml6 (mocked
// services): the staggered entrance, expandable-row reveal spring, detail
// slide, and tile-page spring all animate — mid-flight samples catch both
// snapping (no animation) and stalls (frozen then jumping).
Window {
    id: root

    visible: true
    width: 424
    height: 760

    Rectangle {
        width: panel.implicitWidth
        height: panel.implicitHeight
        color: MD.Token.color.surface_container_low

        QuickSettingsPanel {
            id: panel

            width: parent.width
        }
    }

    TestCase {
        id: tester

        name: "QuickSettingsMotion"

        function test_rise_stagger() {
            panel.open = true;
            wait(60);
            // Header (20ms delay) is already fading in; the pager (140ms
            // delay) has barely started.
            const headerMid = panel.headerOpacityProbe;
            const pagerMid = panel.pagerOpacityProbe;
            verify(headerMid > 0.05, "header rise started, got " + headerMid);
            verify(pagerMid < headerMid + 0.01, "pager rise lags the header: " + pagerMid + " vs " + headerMid);
            wait(700);
            verify(Math.abs(panel.headerOpacityProbe - 1) < 0.01, "header settles opaque");
            verify(Math.abs(panel.pagerOpacityProbe - 1) < 0.01, "pager settles opaque");
        }

        function test_tools_reveal_spring() {
            panel.toolsOpen = true;
            wait(100);
            const mid = panel.toolsReveal;
            verify(mid > 0.1 && mid < 0.98, "tools reveal animates through midflight, got " + mid);
            wait(600);
            verify(Math.abs(panel.toolsReveal - 1) < 0.01, "tools reveal settles open");
            // The open row adds its gap + 40px row to the panel height.
            panel.toolsOpen = false;
            wait(600);
            verify(Math.abs(panel.toolsReveal) < 0.01, "tools reveal settles closed");
        }

        function test_detail_slide() {
            panel.detail = "wifi";
            wait(80);
            const mid = panel.detailSlideProbe;
            verify(mid > 1 && mid < 43, "detail slides in from 44, midflight got " + mid);
            wait(700);
            verify(Math.abs(panel.detailSlideProbe) < 0.5, "detail slide settles at 0");
            verify(Math.abs(panel.mainSlideProbe + 28) < 0.5, "main view rests at -28");
            panel.detail = "";
            wait(700);
            verify(Math.abs(panel.mainSlideProbe) < 0.5, "main view slides back");
        }

        function test_page_spring() {
            // The page track slides x 0 -> -page*width on the prototype's exact
            // --spring-soft curve (cubic-bezier(.38,1.21,.22,1) @ .5s): it
            // front-loads the travel (~92% of the way by ~160ms) and overshoots
            // ~1.4% near 280ms before settling by ~500ms. The front-loaded rise
            // is what pins the prototype curve -- an MD3 spring token would only
            // be ~75% along at 160ms (and never traces the same shape).
            const track = panel.tileTrackProbe;
            const w = panel.tileArea.width;
            compare(panel.page, 0, "starts on page 1");
            panel.setPage(1);
            wait(40);
            verify(track.x < -5, "track slides toward page 2, got " + track.x);
            // ~160ms in, the prototype curve is ~92% travelled; require >=85% so
            // the slow/late MD3 springs (only ~75% here) can't pass.
            wait(130);
            verify(track.x < -0.85 * w, "front-loaded rise: >=85% travelled by ~170ms, got " + (-track.x / w * 100).toFixed(1) + "%");
            // Then it overshoots past -w (peak ~1.4% near 280ms) before settling.
            let overshoot = 0;
            for (let i = 0; i < 12; ++i) {
                overshoot = Math.min(overshoot, track.x + w);
                wait(20);
            }
            verify(overshoot < -1, "track rebounds past page 2 (peak " + overshoot.toFixed(1) + "px past -w)");
            wait(300);
            compare(panel.page, 1, "settled on page 2");
            verify(Math.abs(track.x + w) < 2, "track rests on page 2, got " + track.x + " vs " + w);
            panel.setPage(0);
            wait(600);
            compare(panel.page, 0, "returns to page 1");
            verify(Math.abs(track.x) < 2, "track returns to page 1, got " + track.x);
            console.log("PASS: quick settings motion contract");
        }
    }
}
