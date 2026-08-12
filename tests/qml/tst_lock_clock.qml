import QtQuick
import QtQuick.Window
import QtTest
import "../../Modules/Lock"

// Runtime regression coverage for the lock clock's two interactive springs.
// This deliberately starts with a 0x0-equivalent container unit: a real
// WlSessionLockSurface is constructed before its output geometry arrives.
Window {
    id: root

    visible: true
    width: 800
    height: 600

    property real surfaceUnit: 0
    property bool minimizedState: false
    property bool returnableState: false
    property int hoverTransitions: 0

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function verifyClose(actual, expected, tolerance, message) {
        if (Math.abs(actual - expected) > tolerance)
            throw new Error(message + ": expected " + expected + " +/- " + tolerance + ", got " + actual);
    }

    LockClock {
        id: clock

        cqw: root.surfaceUnit * 4 / 3
        cqh: root.surfaceUnit
        crownCentreY: 300
        minimized: root.minimizedState
        returnable: root.returnableState
    }

    Connections {
        target: clock

        function onHoveredChanged() {
            root.hoverTransitions++;
        }
    }

    TestCase {
        id: tester

        name: "LockClockMotion"

        function test_clock_motion() {
            try {
                // Mapping a surface changes pixel geometry, not the logical
                // pose. It must paint its first real-sized frame already at
                // rest instead of replaying a 0px -> full-size entrance.
                root.verifyClose(clock.pose, 1, 0.000001, "unmapped clock starts at its target pose");
                root.verify(!clock.animating, "unmapped geometry does not start a spring");
                root.surfaceUnit = 6;
                tester.wait(50);
                root.verifyClose(clock.pose, 1, 0.000001, "mapping preserves the full-size pose");
                root.verifyClose(clock.clockScale, 1, 0.000001, "mapping paints at full scale immediately");
                root.verifyClose(clock.blockY, 150, 0.001, "mapped geometry is applied directly to the resting pose");
                root.verify(!clock.animating, "mapping alone never starts the clock animation");

                // A state transition does start the MD3 Expressive spring and
                // advances through continuous, non-integer pose values.
                root.minimizedState = true;
                tester.wait(65);
                root.verify(clock.animating, "minimize starts the hero spring");
                root.verify(clock.pose > 0.05 && clock.pose < 0.95,
                    "minimize has a mid-flight pose, got " + clock.pose);
                root.verify(clock.poseVelocity < 0, "minimize carries inward velocity");

                // Retargeting an interactive spring keeps its velocity. A
                // restarted easing animation would throw this value away and
                // reverse immediately, producing the artificial bounce the
                // clock used to show.
                const interruptedVelocity = clock.poseVelocity;
                root.minimizedState = false;
                root.verifyClose(clock.poseVelocity, interruptedVelocity, 0.000001,
                    "retargeting preserves the current spring velocity");
                tester.wait(1);
                root.verify(clock.poseVelocity < 0,
                    "the first return frame retains inward momentum");
                tester.wait(700);
                root.verifyClose(clock.pose, 1, 0.000001, "hero spring settles at full size");
                root.verify(!clock.animating, "hero spring stops at rest");

                // Return to the crown before exercising hover independently.
                root.minimizedState = true;
                tester.wait(750);
                root.verifyClose(clock.pose, 0, 0.000001, "hero spring settles at crown size");
                root.verify(!clock.animating, "settled crown is idle");

                root.returnableState = true;
                tester.wait(20);
                const crownY = clock.blockY;
                const fixedRight = clock.width / 2 + clock.width * clock.hoverOvershootScale / 2;
                const fixedHeight = (clock.height + 2 * clock.glyphOverhang) * clock.hoverOvershootScale;
                const fixedTop = -clock.glyphOverhang * clock.hoverOvershootScale;
                const edgeInset = Math.min(1, clock.width * clock.hoverOvershootScale * 0.05);

                // This point is still inside LockClock's maximum-size layout
                // box, but outside the explicit preview target. A handler on
                // the root item would turn the whole full-size clock box into
                // an invisible oversized button.
                tester.mouseMove(clock, fixedRight + edgeInset, fixedTop + fixedHeight / 2);
                tester.wait(20);
                root.verify(!clock.hovered, "the hover target ends at the fixed preview bounds");
                root.verify(root.hoverTransitions === 0,
                    "moving within the layout box does not spuriously enter hover");

                // Enter the outer rim of the maximum hover target. This point
                // starts outside the resting 0.24-scale ink but inside the
                // fixed 0.265 target; changing visual scale must never move
                // the target out from under it.
                tester.mouseMove(clock, fixedRight - edgeInset, fixedTop + fixedHeight / 2);
                tester.wait(40);
                root.verify(clock.hovered, "fixed outer rim accepts hover");
                root.verify(clock.hoverPose > 0 && clock.hoverPose < 1,
                    "hover uses a spring instead of snapping, got " + clock.hoverPose);
                const transitionsOnEntry = root.hoverTransitions;
                root.verify(transitionsOnEntry === 1,
                    "hover entered exactly once, got " + transitionsOnEntry + " transitions");

                for (let sample = 0; sample < 45; sample++) {
                    tester.wait(16);
                    root.verify(clock.hovered,
                        "hover target remained stable at sample " + sample);
                    root.verifyClose(clock.blockY, crownY, 0.001,
                        "hover changes size without moving the crown top");
                }
                root.verify(root.hoverTransitions === transitionsOnEntry,
                    "visual overshoot does not oscillate hover state");
                root.verifyClose(clock.hoverPose, 1, 0.000001, "hover spring settles at its target");
                root.verifyClose(clock.clockScale, clock.hoverScale, 0.000001,
                    "hover settles at the advertised preview scale");

                // The line boxes are deliberately tighter than their glyphs.
                // Their painted overhang remains part of the pointer target.
                tester.mouseMove(clock, clock.width / 2, fixedTop + edgeInset);
                tester.wait(20);
                root.verify(clock.hovered,
                    "visible glyph overhang remains inside the hover target");

                tester.mouseMove(clock, -20, -20);
                tester.wait(40);
                root.verify(!clock.hovered, "leaving the fixed target clears hover");
                root.verify(clock.hoverPose > 0 && clock.hoverPose < 1,
                    "hover-out also transitions through a spring pose, got " + clock.hoverPose);
                tester.wait(700);
                root.verifyClose(clock.hoverPose, 0, 0.000001, "hover-out settles at crown size");
                root.verifyClose(clock.clockScale, clock.crownScale, 0.000001,
                    "hover-out restores the crown scale");
                root.verify(root.hoverTransitions === 2,
                    "one entry and one exit occurred without oscillation");

                console.log("PASS: lock clock motion");
            } catch (error) {
                console.warn("FAIL: lock clock motion: " + error.message);
                Qt.exit(1);
            }
        }
    }
}
