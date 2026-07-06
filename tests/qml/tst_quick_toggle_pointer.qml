import QtQuick
import QtQuick.Window
import QtTest
import Qcm.Material as MD
import "../../Modules/QuickSettingsMenu/Widgets"

// Pointer behavior of the quick-settings MD3 widgets under offscreen qml6.
// qs.Commons.* singletons come from tests/qml/mocks. Assertions live in a
// real TestCase function: an empty TestCase auto-quits qml6 ~150ms in,
// racing (and silently skipping) any Timer-driven checks.
Window {
    id: root

    visible: true
    width: 420
    height: 320

    property int toggleClicks: 0
    property int menuToggleClicks: 0
    property int expandRequests: 0
    property real movedValue: -1
    property int iconClicks: 0

    QuickToggle {
        id: toggle

        x: 10
        y: 10
        width: 188
        labelKey: "quickSettings.nightLight"
        icon.name: "nightlight"
        checked: false

        onClicked: root.toggleClicks++
    }

    QuickMenuToggle {
        id: menuToggle

        x: 10
        y: 70
        width: 188
        labelKey: "quickSettings.wifi"
        iconName: "wifi"
        checked: true

        onClicked: root.menuToggleClicks++
        onExpandRequested: root.expandRequests++
    }

    QuickSlider {
        id: slider

        x: 10
        y: 130
        width: 380
        iconName: "volume_up"
        iconReactive: true
        value: 0.25

        onMoved: function (newValue) {
            root.movedValue = newValue;
        }
        onIconClicked: root.iconClicks++
    }

    TestCase {
        id: tester

        name: "QuickSettingsPointer"

        function test_pointer() {
            // QuickToggle: click emits, never self-toggles (service owns state).
            mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton);
            wait(20);
            verify(root.toggleClicks === 1, "toggle click should emit clicked");
            verify(toggle.checked === false, "toggle must not flip its own checked");

            // Checked visual contract: filled when on, tonal when off.
            verify(toggle.mdState.type === MD.Enum.BtFilledTonal, "unchecked toggle is tonal");
            toggle.checked = true;
            verify(toggle.mdState.type === MD.Enum.BtFilled, "checked toggle is filled");

            // Selected corner morph (web-prototype 22 -> 14). Assert the
            // RENDERED corner (mdState.corners), not the stepped driver, so
            // a morph that freezes then snaps is actually caught. Right
            // after the flip the internal Behavior has not ticked yet
            // (still stadium); ~130ms in it must already be past halfway
            // toward the selected corner (the old spring-into-internal-
            // Behavior stall left it frozen at stadium until ~300ms); then
            // it settles at the selected corner.
            verify(toggle.mdState.corners.topLeft > toggle.selectedCorner + 1, "corner morph must animate, not snap");
            wait(130);
            verify(toggle.mdState.corners.topLeft < 18, "corner morph must track the color, not freeze then snap; at 130ms got " + toggle.mdState.corners.topLeft);
            wait(500);
            verify(Math.abs(toggle.mdState.corners.topLeft - toggle.selectedCorner) < 0.5, "corner morph settles at the selected corner, got " + toggle.mdState.corners.topLeft);
            toggle.checked = false;
            wait(600);

            // QuickMenuToggle: left half toggles, arrow segment expands.
            mouseClick(menuToggle, 40, menuToggle.height / 2, Qt.LeftButton);
            wait(20);
            verify(root.menuToggleClicks === 1, "menu toggle body should emit clicked");
            verify(root.expandRequests === 0, "body click must not expand");

            mouseClick(menuToggle, menuToggle.width - 10, menuToggle.height / 2, Qt.LeftButton);
            wait(20);
            verify(root.expandRequests === 1, "arrow click should request expand");
            verify(root.menuToggleClicks === 1, "arrow click must not toggle");

            // QuickSlider: wheel over the row nudges the value by the
            // prototype's coarse step of 5 (0.25 -> 0.30).
            mouseWheel(slider, slider.width / 2, slider.height / 2, 0, 120, Qt.NoButton);
            wait(20);
            verify(Math.abs(root.movedValue - 0.3) < 0.001, "wheel up should step +5, got " + root.movedValue);

            // QuickSlider: press on the track emits moved with the new value.
            mousePress(slider, slider.width * 0.8, slider.height / 2, Qt.LeftButton);
            wait(20);
            mouseRelease(slider, slider.width * 0.8, slider.height / 2, Qt.LeftButton);
            wait(20);
            verify(root.movedValue > 0.5, "track press should move value up, got " + root.movedValue);

            // Reactive icon emits iconClicked (mute affordance).
            mouseClick(slider, 24, slider.height / 2, Qt.LeftButton);
            wait(20);
            verify(root.iconClicks === 1, "reactive icon should emit iconClicked");

            console.log("PASS: quick settings pointer contract");
        }
    }
}
