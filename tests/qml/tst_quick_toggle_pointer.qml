import QtQuick
import QtQuick.Window
import QtTest
import Qcm.Material as MD
import "../../Modules/QuickSettings/Widgets"

// Pointer behavior of the quick-settings MD3 widgets under offscreen qml6.
// qs.Commons.* singletons come from tests/qml/mocks.
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

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

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
    }

    Timer {
        interval: 150
        running: true
        repeat: false

        onTriggered: {
            try {
                // QuickToggle: click emits, never self-toggles (service owns state).
                tester.mouseClick(toggle, toggle.width / 2, toggle.height / 2, Qt.LeftButton);
                tester.wait(20);
                root.verify(root.toggleClicks === 1, "toggle click should emit clicked");
                root.verify(toggle.checked === false, "toggle must not flip its own checked");

                // Checked visual contract: filled when on, tonal when off.
                root.verify(toggle.mdState.type === MD.Enum.BtFilledTonal, "unchecked toggle is tonal");
                toggle.checked = true;
                root.verify(toggle.mdState.type === MD.Enum.BtFilled, "checked toggle is filled");
                toggle.checked = false;

                // QuickMenuToggle: left half toggles, arrow segment expands.
                tester.mouseClick(menuToggle, 40, menuToggle.height / 2, Qt.LeftButton);
                tester.wait(20);
                root.verify(root.menuToggleClicks === 1, "menu toggle body should emit clicked");
                root.verify(root.expandRequests === 0, "body click must not expand");

                tester.mouseClick(menuToggle, menuToggle.width - 10, menuToggle.height / 2, Qt.LeftButton);
                tester.wait(20);
                root.verify(root.expandRequests === 1, "arrow click should request expand");
                root.verify(root.menuToggleClicks === 1, "arrow click must not toggle");

                // QuickSlider: press on the track emits moved with the new value.
                tester.mousePress(slider, slider.width * 0.8, slider.height / 2, Qt.LeftButton);
                tester.wait(20);
                tester.mouseRelease(slider, slider.width * 0.8, slider.height / 2, Qt.LeftButton);
                tester.wait(20);
                root.verify(root.movedValue > 0.5, "track press should move value up, got " + root.movedValue);

                // Reactive icon emits iconClicked (mute affordance).
                tester.mouseClick(slider, 24, slider.height / 2, Qt.LeftButton);
                tester.wait(20);
                root.verify(root.iconClicks === 1, "reactive icon should emit iconClicked");

                console.log("PASS: quick settings pointer contract");
                Qt.exit(0);
            } catch (error) {
                console.error("FAIL: " + error.message);
                Qt.exit(1);
            }
        }
    }
}
