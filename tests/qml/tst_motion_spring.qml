import QtQuick
import QtQuick.Window
import QtTest
import "../../Material"

// Runtime contract for the live M3E spring used by lock visibility and the bar
// reveal. The critical behavior is interruption: changing the target must not
// replace the spring with a new from-rest animation.
Window {
    id: root

    visible: true
    width: 320
    height: 200

    property bool shown: false
    property bool springEnabled: true

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function verifyClose(actual, expected, tolerance, message) {
        if (Math.abs(actual - expected) > tolerance)
            throw new Error(message + ": expected " + expected + " +/- " + tolerance + ", got " + actual);
    }

    MotionSpring {
        id: motion

        target: root.shown ? 1 : 0
        motionEnabled: root.springEnabled
    }

    TestCase {
        id: tester

        name: "MotionSpring"

        function test_live_spring() {
            try {
                root.verifyClose(motion.value, 0, 0.000001, "initial value snaps to its target");
                root.verify(!motion.animating, "initial target does not replay an entrance");

                root.shown = true;
                tester.wait(65);
                root.verify(motion.animating, "target change starts the spring");
                root.verify(motion.value > 0.05 && motion.value < 0.95,
                    "spring exposes a continuous mid-flight value, got " + motion.value);
                root.verify(motion.velocity > 0, "entrance carries outward velocity");

                const interruptedVelocity = motion.velocity;
                root.shown = false;
                root.verifyClose(motion.velocity, interruptedVelocity, 0.000001,
                    "retargeting preserves velocity synchronously");
                tester.wait(1);
                root.verify(motion.velocity > 0,
                    "the first return instant retains outward momentum");
                tester.wait(650);
                root.verifyClose(motion.value, 0, 0.000001, "spring settles exactly at hidden");
                root.verifyClose(motion.velocity, 0, 0.000001, "settled spring clears velocity");
                root.verify(!motion.animating, "settled spring stops its frame driver");

                root.springEnabled = false;
                root.shown = true;
                root.verifyClose(motion.value, 1, 0.000001, "disabled motion snaps on target change");
                root.verify(!motion.animating, "disabled motion never starts the frame driver");
                root.shown = false;
                root.verifyClose(motion.value, 0, 0.000001, "disabled reverse also snaps");

                root.springEnabled = true;
                root.shown = true;
                tester.wait(40);
                root.verify(motion.animating, "re-enabled motion resumes spring behavior");
                tester.wait(650);
                root.verifyClose(motion.value, 1, 0.000001, "re-enabled spring settles at shown");

                console.log("PASS: live motion spring");
            } catch (error) {
                console.warn("FAIL: live motion spring: " + error.message);
                Qt.exit(1);
            }
        }
    }
}
