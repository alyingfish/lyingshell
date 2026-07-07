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
            // SwipeView scrolls its content flickable: contentX runs 0 -> page*width.
            const track = panel.tileTrackProbe;
            const w = panel.tileArea.width;
            compare(panel.page, 0, "starts on page 1");
            panel.setPage(1);
            wait(50);
            verify(track.contentX > 5, "content scrolls toward page 2, got " + track.contentX);
            wait(600);
            compare(panel.page, 1, "settled on page 2");
            verify(Math.abs(track.contentX - w) < 2, "content rests on page 2, got " + track.contentX + " vs " + w);
            panel.setPage(0);
            wait(600);
            compare(panel.page, 0, "returns to page 1");
            verify(Math.abs(track.contentX) < 2, "content returns to page 1, got " + track.contentX);
            console.log("PASS: quick settings motion contract");
        }
    }
}
