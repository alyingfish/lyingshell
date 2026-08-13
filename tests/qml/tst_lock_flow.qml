import QtQml
import Quickshell
import LockFlowTest
import qs.Commons.Theme

// The lock flow's guarantees, walked on the REAL Services/Lock.qml (staged
// under the LockFlowTest module by tests/test_lock_flow.py, with the mock
// Quickshell/Pam/Io modules standing in for the compositor and the stack).
// The surfaces are simulated by hand: this file plays the part of
// LockScreen.qml and LockStillCapture.qml, delivering stills, snapshots,
// paint reports and `secure` exactly where the real views would.
//
// What is pinned here is the ARCHITECTURE, not pixels:
//
//   entry  the sweep clock starts on the tap and the pipeline overlaps the
//          lead-in; the lock is requested the moment every output answers;
//          the visible sweep waits for secure + lead-in + every delivered
//          still's painted frame — and a null (failed) capture must not
//          hold that gate;
//   exit   the release is GATED on every cover's first presented frame (one
//          report is not enough), and a cover that never paints trips the
//          bounded bail into a clean cut with the covers torn down;
//   relock a tap during the open sweep cuts the tail and locks again
//          instead of being dropped.
QtObject {
    id: root

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function verifyEqual(actual, expected, message) {
        if (actual !== expected)
            throw new Error(message + ": expected " + expected + ", got " + actual);
    }

    function grab(tag) {
        return {
            "url": "fake://" + tag
        };
    }

    // Drive Lock from glance to the hello handoff the way PAM would.
    function driveToUnlock() {
        Lock.wake("f");
        verifyEqual(Lock.phase, Lock.phaseAsk, "wake reaches ask");
        Lock.submit();
        verifyEqual(Lock.phase, Lock.phasePending, "submit reaches pending");
        Lock.beginUnlock();
        verify(Lock.succeeded, "success step begins");
        verifyEqual(Lock.phase, Lock.phasePending, "the avatar goes first, alone");
    }

    // [delay after the previous step, name, body]
    readonly property var plan: [
        // ---- A. entry: the pipeline overlaps the lead-in, gates hold ----
        [1, "A: tap", function () {
                Quickshell.screens = [
                    {
                        "name": "A"
                    },
                    {
                        "name": "B"
                    }
                ];
                Lock.secure = false;
                Lock.lock();
                root.verifyEqual(Lock.entryStage, "capture", "the tap opens the capture stage");
                root.verify(!Lock.locked, "the lock waits for the stills");
                root.verifyEqual(Lock.deskHole, 1, "the desktop owns the screen");
                root.verify(LockTheme.active, "the lock palette is seeded on the tap");
                Lock.deliverDesktopStill("A", root.grab("a"));
                root.verify(!Lock.locked, "one output is not every output");
                Lock.deliverDesktopStill("B", root.grab("b"));
                root.verify(Lock.locked, "the lock is requested the moment every output answers");
                root.verifyEqual(Lock.entryStage, "arming", "the gates arm once the lock is requested");
                Lock.secure = true;
                Lock.entryStillPainted();
                Lock.entryStillPainted();
                // All of the above ran in one tick, so unless the machine
                // paused for >102ms the lead-in must still be holding.
                if (!Lock.leadInElapsed) {
                    root.verifyEqual(Lock.entryStage, "arming", "secure + paints alone do not start the sweep: the lead-in is a gate");
                }
            }],
        [300, "A: sweeping", function () {
                root.verifyEqual(Lock.entryStage, "sweep", "all gates passed, the circle moves");
                root.verify(Lock.deskHole <= 0.6174 + 0.0001, "the sweep continues from the hold point, never above it");
            }],
        [1100, "A: landed", function () {
                root.verifyEqual(Lock.entryStage, "", "the entry retires when the circle lands");
                root.verifyEqual(Lock.deskHole, 0, "the scene owns the screen");
                root.verifyEqual(Object.keys(Lock.desktopStills).length, 0, "the stills are released on landing");
            }],
        // ---- B. exit: the release is gated on every cover's paint -------
        [1, "B: authenticate", function () {
                root.driveToUnlock();
            }],
        [700, "B: hello grabs", function () {
                root.verifyEqual(Lock.phase, Lock.phaseHello, "the success hold ends in hello");
                root.verifyEqual(Lock.exitStage, "snapshot", "hello asks the surfaces for their pose");
                root.verify(Lock.locked, "still locked while the pose is grabbed");
                Lock.deliverSweepSnapshot("A", root.grab("pose-a"));
                root.verifyEqual(Lock.exitStage, "snapshot", "one snapshot is not every snapshot");
                Lock.deliverSweepSnapshot("B", root.grab("pose-b"));
                root.verifyEqual(Lock.exitStage, "cover", "the covers raise once every pose landed");
                root.verify(Lock.locked, "still locked while the covers buffer");
                Lock.sweepSurfacePainted();
                root.verify(Lock.locked, "one painted cover is not every painted cover: the release is gated");
                Lock.sweepSurfacePainted();
                root.verify(!Lock.locked, "every cover reported, the lock drops");
                root.verifyEqual(Lock.exitStage, "open", "the circle opens over the live desktop");
            }],
        [1100, "B: opened", function () {
                root.verifyEqual(Lock.exitStage, "", "the exit retires when the circle lands");
                root.verifyEqual(Lock.phase, Lock.phaseGlance, "the room is reset for the next lock");
                root.verify(!LockTheme.active, "the desktop's own seed comes back after the sweep");
                root.verifyEqual(Lock.deskHole, 1, "the desktop owns the screen again");
            }],
        // ---- C. failures stay bounded and clean --------------------------
        [1, "C: lock with one dead capture", function () {
                Lock.secure = false;
                Lock.lock();
                Lock.deliverDesktopStill("A", null);
                Lock.deliverDesktopStill("B", root.grab("b2"));
                root.verify(Lock.locked, "a failed capture never delays the lock");
                root.verifyEqual(Object.keys(Lock.desktopStills).length, 1, "a null grab is counted, never stored");
                Lock.secure = true;
                Lock.entryStillPainted();
            }],
        [300, "C: null still held no gate", function () {
                root.verifyEqual(Lock.entryStage, "sweep", "the painted gate waits only for stills that exist");
            }],
        [1000, "C: authenticate again", function () {
                root.verifyEqual(Lock.entryStage, "", "second entry landed");
                root.driveToUnlock();
            }],
        [700, "C: covers that never paint", function () {
                root.verifyEqual(Lock.exitStage, "snapshot", "second hello grabs");
                Lock.deliverSweepSnapshot("A", root.grab("pose-a2"));
                Lock.deliverSweepSnapshot("B", root.grab("pose-b2"));
                root.verifyEqual(Lock.exitStage, "cover", "covers raised");
                // ...and no sweepSurfacePainted() ever arrives.
            }],
        [400, "C: the unlock is delayed, not broken", function () {
                root.verify(Lock.locked, "the release waits for the covers inside the bail window");
            }],
        [900, "C: the bail cut", function () {
                root.verify(!Lock.locked, "the bail released the lock");
                root.verifyEqual(Lock.exitStage, "", "the covers are gone: a clean cut, no late flash");
                root.verifyEqual(Lock.phase, Lock.phaseGlance, "the room is reset after the cut");
            }],
        // ---- D. a lock during the open sweep is not dropped ---------------
        [1, "D: lock, unlock to open", function () {
                Lock.secure = false;
                Lock.lock();
                Lock.deliverDesktopStill("A", root.grab("a3"));
                Lock.deliverDesktopStill("B", root.grab("b3"));
                Lock.secure = true;
                Lock.entryStillPainted();
                Lock.entryStillPainted();
            }],
        [1100, "D: authenticate", function () {
                root.verifyEqual(Lock.entryStage, "", "third entry landed");
                root.driveToUnlock();
            }],
        [700, "D: open, then re-lock mid-sweep", function () {
                Lock.deliverSweepSnapshot("A", root.grab("pose-a3"));
                Lock.deliverSweepSnapshot("B", root.grab("pose-b3"));
                Lock.sweepSurfacePainted();
                Lock.sweepSurfacePainted();
                root.verifyEqual(Lock.exitStage, "open", "the circle is opening");
                root.verify(!Lock.locked, "unlocked while it opens");
                Lock.lock();
                root.verifyEqual(Lock.exitStage, "", "the re-lock cut the exit's tail");
                root.verifyEqual(Lock.entryStage, "capture", "the re-lock began a fresh entry instead of being dropped");
                Lock.deliverDesktopStill("A", root.grab("a4"));
                Lock.deliverDesktopStill("B", root.grab("b4"));
                root.verify(Lock.locked, "the re-lock took the session lock");
            }]
    ]

    property int step: 0

    property Timer driver: Timer {
        interval: 1
        onTriggered: root.advance()
    }

    function advance() {
        var entry = plan[step];
        try {
            entry[2]();
        } catch (error) {
            console.warn("FAIL at '" + entry[1] + "': " + error.message);
            Qt.exit(1);
            return;
        }
        step++;
        if (step >= plan.length) {
            console.log("PASS: lock flow");
            Qt.exit(0);
            return;
        }
        driver.interval = Math.max(1, plan[step][0]);
        driver.restart();
    }

    Component.onCompleted: {
        driver.interval = Math.max(1, plan[0][0]);
        driver.restart();
    }
}
