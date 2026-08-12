.pragma library

// What a key does to a lock screen sitting at `glance`. Three tiers, ported
// from the prototype's window keydown handler (src/lock/stage/auth.js):
//
//   ignore   Tab, Escape, anything held with Alt/Ctrl/Meta, and any key at all
//            while quick settings is open — the panel is a real surface while
//            locked, and its own keys are not a wake.
//   wake     every other non-character key: Enter, Backspace, arrows, F-keys,
//            Shift on its own, and so on. The prompt opens with an empty field.
//   type     a single-character key, space included. The prompt opens AND that
//            character lands in the field, in the same event.
//
// Qt key/modifier codes are spelled out rather than imported: a .pragma library
// has no QML engine context, so Qt.Key_* is not in scope here.
var KEY_ESCAPE = 0x01000000;
var KEY_TAB = 0x01000001;
var KEY_BACKTAB = 0x01000002;
var KEY_CAPSLOCK = 0x01000024;

var MOD_SHIFT = 0x02000000;
var MOD_CONTROL = 0x04000000;
var MOD_ALT = 0x08000000;
var MOD_META = 0x10000000;
// Shift alone is not a hold: it wakes, and Shift+a types "A".
var HOLD_MODIFIERS = MOD_CONTROL | MOD_ALT | MOD_META;

var IGNORE = "ignore";
var WAKE = "wake";
var TYPE = "type";

// A key "sends a character" when Qt hands it exactly one printable one. Enter
// ("\r"), Backspace ("\b"), Tab ("\t") and Escape ("\x1b") all report text of
// length 1 too, which is why the control range has to be excluded rather than
// the length trusted on its own. Space (0x20) is a character.
function isPrintable(text) {
    if (typeof text !== "string" || text.length !== 1) {
        return false;
    }
    var code = text.charCodeAt(0);
    return code >= 0x20 && code !== 0x7f;
}

// Caps Lock, worked out from the keys themselves. Qt exposes no CapsLock
// modifier to QML the way the DOM's getModifierState does, so two signals are
// used together: the lock key's own transition is authoritative, and any
// letter that arrives in the wrong case for the Shift being held reveals the
// state without waiting for the user to toggle it. A screen that starts with
// Caps Lock already on therefore learns it from the first letter typed, which
// is exactly when the warning matters.
function capsState(key, text, modifiers, current) {
    if (key === KEY_CAPSLOCK) {
        return !current;
    }
    if (typeof text === "string" && text.length === 1) {
        var lower = text.toLowerCase();
        var upper = text.toUpperCase();
        if (lower !== upper) {
            var shifted = (modifiers & MOD_SHIFT) !== 0;
            return (text === upper) !== shifted;
        }
    }
    return current;
}

function classify(key, text, modifiers, quickSettingsOpen) {
    if (quickSettingsOpen) {
        return IGNORE;
    }
    if (key === KEY_TAB || key === KEY_BACKTAB || key === KEY_ESCAPE) {
        return IGNORE;
    }
    if ((modifiers & HOLD_MODIFIERS) !== 0) {
        return IGNORE;
    }
    return isPrintable(text) ? TYPE : WAKE;
}
