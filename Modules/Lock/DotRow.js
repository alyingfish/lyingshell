.pragma library

// What the drawn row has to do to hold `length` characters: the cell the edit
// landed on, and how many dots leave and arrive there. Ported from the
// prototype's pwdfield.js `plan()`.
//
// A named range is the truth when there is one — it knows BOTH ends of what
// was replaced, which the caret afterwards cannot tell you, so a paste over a
// selection moves the dots the paste moved and a selection typed straight over
// is one cell changing rather than a row rebuilt. The prototype gets that range
// from `beforeinput`; Qt's TextInput has no equivalent, so the caller records
// the selection that stood immediately before the edit and passes it here. The
// two agree for everything a keyboard or a paste does; only an edit that
// changes the selection and the text in one indivisible step (an undo) falls
// through to the caret path.
//
// Without a range the caret marks the edit: characters arrive in the cells just
// behind it and leave from the cell just after it, so the row opens and closes
// where the eye already is instead of at the tail.
function plan(dots, length, caret, range) {
    if (range && range.end <= dots) {
        var removed = range.end - range.start;
        var added = length - dots + removed;
        if (added >= 0) {
            return {
                "at": range.start,
                "removed": removed,
                "added": added
            };
        }
    }
    if (length > dots) {
        var arriving = length - dots;
        return {
            "at": Math.max(0, caret - arriving),
            "removed": 0,
            "added": arriving
        };
    }
    return {
        "at": caret,
        "removed": dots - length,
        "added": 0
    };
}

// How far the row has to travel to keep the caret off both edges. The gutter
// rides past the last cell so a caret at the tail still has air; a parked
// surface (view of 0) is left alone rather than measured against nothing.
function scrollFor(previous, caret, length, cell, view, gutterCells) {
    if (!(view > 0) || !(cell > 0)) {
        return previous;
    }
    var caretX = caret * cell;
    var gutter = cell * gutterCells;
    var next = Math.min(previous, caretX - gutter);
    next = Math.max(next, caretX + gutter - view);
    return Math.max(0, Math.min(next, Math.max(0, length * cell + gutter - view)));
}
