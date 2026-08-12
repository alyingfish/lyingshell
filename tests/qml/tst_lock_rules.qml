import QtQml
import "../../Modules/Lock/WakeRules.js" as WakeRules
import "../../Modules/Lock/DotRow.js" as DotRow

// The two pieces of the lock screen that are pure decisions rather than
// pixels: what a key does to a screen sitting at glance, and what the drawn
// password row has to do to match an edit that already happened.
QtObject {
    id: root

    // Qt key/modifier codes, spelled the way a KeyEvent delivers them.
    readonly property int keyA: 0x41
    readonly property int keyEscape: 0x01000000
    readonly property int keyTab: 0x01000001
    readonly property int keyBacktab: 0x01000002
    readonly property int keyReturn: 0x01000004
    readonly property int keyBackspace: 0x01000003
    readonly property int keyLeft: 0x01000012
    readonly property int keyF5: 0x01000034
    readonly property int keyShift: 0x01000020
    readonly property int keyCapsLock: 0x01000024
    readonly property int keySpace: 0x20

    readonly property int modShift: 0x02000000
    readonly property int modControl: 0x04000000
    readonly property int modAlt: 0x08000000
    readonly property int modMeta: 0x10000000

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function verifyEqual(actual, expected, message) {
        if (JSON.stringify(actual) !== JSON.stringify(expected))
            throw new Error(message + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual));
    }

    Component.onCompleted: {
        try {
            // ---- tier 1: no wake --------------------------------------
            verifyEqual(WakeRules.classify(root.keyTab, "\t", 0, false), WakeRules.IGNORE, "Tab does not wake");
            verifyEqual(WakeRules.classify(root.keyBacktab, "\t", root.modShift, false), WakeRules.IGNORE, "Shift+Tab does not wake");
            verifyEqual(WakeRules.classify(root.keyEscape, "", 0, false), WakeRules.IGNORE, "Escape does not wake");
            verifyEqual(WakeRules.classify(root.keyA, "a", root.modControl, false), WakeRules.IGNORE, "Ctrl held does not wake");
            verifyEqual(WakeRules.classify(root.keyA, "a", root.modAlt, false), WakeRules.IGNORE, "Alt held does not wake");
            verifyEqual(WakeRules.classify(root.keyA, "a", root.modMeta, false), WakeRules.IGNORE, "Meta held does not wake");
            // The panel is a real surface while locked — its own keys are not a wake.
            verifyEqual(WakeRules.classify(root.keyA, "a", 0, true), WakeRules.IGNORE, "quick settings open swallows every key");
            verifyEqual(WakeRules.classify(root.keyReturn, "\r", 0, true), WakeRules.IGNORE, "quick settings open swallows Enter too");

            // ---- tier 2: wake, type nothing ---------------------------
            verifyEqual(WakeRules.classify(root.keyReturn, "\r", 0, false), WakeRules.WAKE, "Enter wakes without typing");
            verifyEqual(WakeRules.classify(root.keyBackspace, "\b", 0, false), WakeRules.WAKE, "Backspace wakes without typing");
            verifyEqual(WakeRules.classify(root.keyLeft, "", 0, false), WakeRules.WAKE, "an arrow wakes without typing");
            verifyEqual(WakeRules.classify(root.keyF5, "", 0, false), WakeRules.WAKE, "an F-key wakes without typing");
            verifyEqual(WakeRules.classify(root.keyShift, "", root.modShift, false), WakeRules.WAKE, "Shift alone wakes without typing");
            verifyEqual(WakeRules.classify(root.keyCapsLock, "", 0, false), WakeRules.WAKE, "CapsLock wakes without typing");

            // ---- tier 3: wake and type one char -----------------------
            verifyEqual(WakeRules.classify(root.keyA, "a", 0, false), WakeRules.TYPE, "a letter types");
            verifyEqual(WakeRules.classify(root.keyA, "A", root.modShift, false), WakeRules.TYPE, "Shift+letter types");
            verifyEqual(WakeRules.classify(root.keySpace, " ", 0, false), WakeRules.TYPE, "space is a character");
            verifyEqual(WakeRules.classify(0x2d, "-", 0, false), WakeRules.TYPE, "punctuation types");

            // ---- caps lock --------------------------------------------
            verify(WakeRules.capsState(root.keyCapsLock, "", 0, false), "the lock key's transition turns it on");
            verify(!WakeRules.capsState(root.keyCapsLock, "", 0, true), "and off again");
            verify(WakeRules.capsState(root.keyA, "A", 0, false), "an unshifted capital reveals caps lock");
            verify(!WakeRules.capsState(root.keyA, "A", root.modShift, true), "a shifted capital reveals it is off");
            verify(WakeRules.capsState(root.keyA, "a", root.modShift, false), "a shifted lowercase reveals caps lock");
            verifyEqual(WakeRules.capsState(root.keySpace, " ", 0, true), true, "a caseless key changes nothing");
            verifyEqual(WakeRules.capsState(root.keyLeft, "", 0, true), true, "a non-character key changes nothing");

            // ---- the drawn row ----------------------------------------
            // Typing at the tail: one cell opens where the caret is.
            verifyEqual(DotRow.plan(0, 1, 1, null), {
                "at": 0,
                "removed": 0,
                "added": 1
            }, "first character opens cell 0");
            verifyEqual(DotRow.plan(4, 5, 5, null), {
                "at": 4,
                "removed": 0,
                "added": 1
            }, "typing at the tail opens the last cell");
            // Typing in the middle: the cell opens where the eye is, not at the end.
            verifyEqual(DotRow.plan(4, 5, 3, null), {
                "at": 2,
                "removed": 0,
                "added": 1
            }, "typing mid-row opens behind the caret");
            // Backspace: the cell just before the caret leaves.
            verifyEqual(DotRow.plan(5, 4, 2, null), {
                "at": 2,
                "removed": 1,
                "added": 0
            }, "a delete closes the cell at the caret");
            // A named range is the truth: a selection typed straight over is one
            // cell changing, not a row rebuilt.
            verifyEqual(DotRow.plan(5, 3, 1, {
                "start": 0,
                "end": 3
            }), {
                "at": 0,
                "removed": 3,
                "added": 1
            }, "typing over a selection replaces exactly that range");
            // A paste over a selection moves the dots the paste moved.
            verifyEqual(DotRow.plan(5, 8, 6, {
                "start": 1,
                "end": 3
            }), {
                "at": 1,
                "removed": 2,
                "added": 5
            }, "a paste over a selection replaces exactly that range");
            // A stale range (it names more than the row holds) falls back to the caret.
            verifyEqual(DotRow.plan(2, 3, 3, {
                "start": 0,
                "end": 9
            }), {
                "at": 2,
                "removed": 0,
                "added": 1
            }, "a stale range is ignored");

            // ---- the scroll -------------------------------------------
            const cell = 11, view = 110, gutter = 0.75;
            // A caret inside the view leaves the row where it is.
            verifyEqual(DotRow.scrollFor(0, 3, 3, cell, view, gutter), 0, "a short password never scrolls");
            // Past the right edge the row travels just far enough to keep the
            // gutter beyond the caret.
            verifyEqual(DotRow.scrollFor(0, 20, 20, cell, view, gutter), 20 * cell + 0.75 * cell - view, "a long password scrolls to keep the caret off the edge");
            // Walking back left pulls the row back, and never past the start.
            verifyEqual(DotRow.scrollFor(120, 0, 20, cell, view, gutter), 0, "the row cannot scroll before the first cell");
            // A parked surface (no view) is left alone rather than measured.
            verifyEqual(DotRow.scrollFor(42, 0, 0, cell, 0, gutter), 42, "an unmapped surface keeps its offset");

            console.log("PASS: lock rules");
        } catch (error) {
            console.warn("FAIL: " + error.message);
            Qt.exit(1);
        }
        Qt.exit(0);
    }
}
