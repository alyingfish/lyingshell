import QtQuick
import QtQuick.Window
import QtTest
import "../../Material"

// Pointer + motion behavior of the plus-kit M3E connected button group
// under offscreen qml6: radio semantics, selected-segment grow on the
// spatial spring (width sum invariant), and inner-corner morph. Assertions
// live in a real TestCase function: an empty TestCase auto-quits qml6
// ~150ms in, racing (and silently skipping) any Timer-driven checks.
Window {
    id: root

    visible: true
    width: 420
    height: 200

    property var picks: []

    ConnectedButtonGroup {
        id: group

        x: 10
        y: 10
        width: 340
        model: [
            {
                "icon": "eco",
                "text": "Saver",
                "value": "saver"
            },
            {
                "icon": "speed",
                "text": "Balanced",
                "value": "balanced"
            },
            {
                "icon": "bolt",
                "text": "Boost",
                "value": "boost"
            }
        ]
        current: "balanced"

        onSelected: function (value) {
            root.picks.push(value);
            current = value;
        }
    }

    TestCase {
        id: tester

        name: "ConnectedGroupPointer"

        function test_pointer() {
            const row = group.children[0];
            const segments = [row.children[0], row.children[1], row.children[2]];
            const slot = group.width - group.gap * 2;
            const grown = slot * group.selectedWeight / group.weightSum;
            const plain = slot / group.weightSum;

            // Selected segment holds the grow weight; sum stays put.
            verify(Math.abs(segments[1].width - grown) < 1, "selected segment carries selectedWeight");
            verify(Math.abs(segments[0].width - plain) < 1, "unselected segment carries weight 1");
            const sum = segments[0].width + segments[1].width + segments[2].width;
            verify(Math.abs(sum + group.gap * 2 - group.width) < 1, "segment widths fill the group");

            // Corners: outer edges stadium, shared edges inner; the
            // selected middle segment is stadium on both sides.
            verify(segments[0].rightCorner === group.innerCorner, "shared edge keeps the inner corner");
            verify(segments[1].leftCorner > group.innerCorner, "selected segment rounds its shared edges");

            // Radio semantics: picking a new segment emits once.
            mouseClick(segments[0], segments[0].width / 2, segments[0].height / 2, Qt.LeftButton);
            wait(20);
            verify(root.picks.length === 1 && root.picks[0] === "saver", "click on unselected emits its value");

            // Spring grow: mid-flight the widths move, they do not snap.
            verify(segments[0].width < grown - 5, "grow must animate, not snap");
            wait(700);
            verify(Math.abs(segments[0].width - grown) < 1, "new selection settles at the grow width");
            verify(Math.abs(segments[1].width - plain) < 1, "old selection yields back to weight 1");
            verify(segments[1].leftCorner === group.innerCorner, "deselected shared edge returns to inner corner");

            // Clicking the already-selected segment stays quiet.
            mouseClick(segments[0], segments[0].width / 2, segments[0].height / 2, Qt.LeftButton);
            wait(20);
            verify(root.picks.length === 1, "click on selected segment must not re-emit");

            console.log("PASS: connected button group pointer contract");
        }
    }
}
