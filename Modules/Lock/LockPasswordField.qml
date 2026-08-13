import QtQuick
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Services
import qs.Material

import "../../Material/Motion.js" as Motion
import "DotRow.js" as DotRow
import "WakeRules.js" as WakeRules
import "LockMotion.js" as LockMotion

// The password pill: an MD3 text field at desktop scale that draws its own
// mask.
//
// A masked TextInput stamps each bullet the instant the key lands and cuts the
// caret across with it — the one moment of the approach that arrives with no
// motion at all. So the input keeps everything that has to stay native (the
// secret, focus, the clipboard, undo, selection) and stops painting entirely,
// while this file renders what is actually seen: a label that leaves as the
// first character lands, dots that settle in, departures that collapse the row
// behind them, and a caret, selection band and long-password scroll that glide.
// Revealing the password hands the glyphs back to the input — the one time its
// own rendering is what you want, and the mask cuts off then.
//
// Every position is an index times one cell, so label, dots, caret, band and
// scroll all move on the same grid and stay in step through each other's
// motion.
Item {
    id: root

    required property real cqw
    required property real cqh

    signal submitted

    // 1dp, counted the way the prototype counts it.
    readonly property real dp: 0.0625 * cqw

    readonly property real cell: 0.6875 * cqw
    readonly property real dotSize: 0.375 * cqw
    readonly property real caretWidth: 0.125 * cqw
    readonly property real caretHeight: 2.1 * cqh
    readonly property real bandHeight: 2.8 * cqh
    // How much of the row is kept beyond the caret before the track scrolls.
    readonly property real caretGutter: 0.75

    readonly property bool busy: Lock.phase === Lock.phasePending
    readonly property bool masked: !Lock.reveal

    // Spatial motion is the part that cannot be asked of a vestibular reader,
    // so travel and the caret's blink stop and everything else carries on: a
    // fade is not motion, and the discs' own arrival and exit have to keep
    // running either way — the exit is what retires the dot.
    readonly property bool reducedMotion: Settings.options.appearance.reducedMotion

    property real shakeOffset: 0
    property real scrollPx: 0

    implicitWidth: 15.5 * cqw
    implicitHeight: 5.2 * cqh

    transform: Translate {
        x: root.shakeOffset
    }

    function forceFocus() {
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
    }

    ShakeAnimation {
        id: shake

        item: root
        unit: root.cqw
    }

    Connections {
        target: Lock

        function onShakeGenerationChanged() {
            // A refusal returns from pending without moving the field, so the
            // caret goes straight back and the whole secret is selected — the
            // next keystroke replaces it.
            input.forceActiveFocus();
            input.selectAll();
            if (!root.reducedMotion) {
                shake.restart();
            }
        }

        function onPhaseChanged() {
            if (Lock.phase === Lock.phaseAsk) {
                input.forceActiveFocus();
            }
        }
    }

    // ---- the pill --------------------------------------------------------

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: height / 2
        color: LockTheme.glassHigh
    }

    // Focus is the field's own outline thickening and nothing else: 1dp of
    // outline at rest, 2dp of primary once the caret is in it, both drawn ON
    // the pill so the thick one lands without moving a pixel of the row. A
    // refusal recolours that same stroke rather than adding one — error
    // outranks focus, as the spec's own state order has it.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: root.dp
        // The spec's disabled outline is the same hairline at 12%, which is
        // what says the pill is not answering just now.
        border.color: root.busy ? Qt.rgba(MD.Token.color.on_surface.r, MD.Token.color.on_surface.g, MD.Token.color.on_surface.b, 0.12) : MD.Token.color.outline
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: root.dp * 2
        border.color: Lock.refused ? MD.Token.color.error : MD.Token.color.primary
        opacity: Lock.refused || input.activeFocus ? 1 : 0

        Behavior on opacity {
            MotionAnimation {
                spring: Motion.effectsFast
            }
        }
    }

    MD.Icon {
        id: lead

        anchors.left: parent.left
        anchors.leftMargin: 1.67 * root.cqh
        anchors.verticalCenter: parent.verticalCenter
        name: "lock"
        size: 1.15 * root.cqw
        color: MD.Token.color.on_surface_variant
    }

    // ---- the buttons -----------------------------------------------------

    Item {
        id: goButton

        readonly property real diameter: 3.7 * root.cqh

        anchors.right: parent.right
        anchors.rightMargin: 0.74 * root.cqh
        anchors.verticalCenter: parent.verticalCenter
        width: diameter
        height: diameter
        enabled: !root.busy

        scale: goHover.hovered && !root.busy ? 1.05 : 1

        Behavior on scale {
            MotionAnimation {}
        }

        Rectangle {
            anchors.fill: parent
            // The arrow's own container turns transparent under the indicator,
            // which is the uncontained MD3 loading indicator's whole point.
            color: root.busy ? "transparent" : MD.Token.color.primary
            // 50% at rest, squaring off a little under the pointer.
            radius: (goHover.hovered && !root.busy ? 0.32 : 0.5) * width

            Behavior on radius {
                MotionAnimation {}
            }
            Behavior on color {
                MotionColorAnimation {}
            }
        }

        MD.Icon {
            anchors.centerIn: parent
            name: "arrow_forward"
            size: 1.2 * root.cqw
            color: MD.Token.color.on_primary
            opacity: root.busy ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.Linear
                }
            }
        }

        // MD3 Expressive's uncontained loading indicator, straight from
        // QmlMaterial — the seven-shape morph the prototype redraws by hand in
        // auth.js. Its `visible` is written imperatively by the control, so
        // `running` is the only thing bound here.
        MD.BusyIndicator {
            anchors.centerIn: parent
            implicitWidth: goButton.diameter
            implicitHeight: goButton.diameter
            indicatorSize: goButton.diameter
            colors: [MD.Token.color.primary]
            running: root.busy
        }

        HoverHandler {
            id: goHover

            enabled: !root.busy
            cursorShape: root.busy ? Qt.WaitCursor : Qt.PointingHandCursor
        }

        TapHandler {
            enabled: !root.busy

            onTapped: root.submitted()
        }
    }

    MD.IconButton {
        id: eye

        anchors.right: goButton.left
        anchors.rightMargin: 0.3 * root.cqw
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 3.7 * root.cqh
        implicitHeight: 3.7 * root.cqh
        enabled: !root.busy
        // Revealing changes only the password's presentation. The eye must
        // never take active focus away from the input, even for the pressed
        // frame before onClicked runs.
        focusPolicy: Qt.NoFocus
        mdState.type: MD.Enum.IBtStandard
        mdState.size: MD.Enum.XS
        icon.name: Lock.reveal ? "visibility_off" : "visibility"
        icon.width: 1.1 * root.cqw
        icon.height: 1.1 * root.cqw

        onClicked: {
            // Peeking is not an edit: carry the caret across the swap and put
            // it back, so the place the eye was called from is not lost.
            var at = input.cursorPosition;
            var selStart = input.selectionStart;
            var selEnd = input.selectionEnd;
            Lock.reveal = !Lock.reveal;
            if (selEnd > selStart) {
                input.select(selStart, selEnd);
            } else {
                input.cursorPosition = at;
            }
        }
    }

    // ---- the field -------------------------------------------------------

    Item {
        id: field

        anchors.left: lead.right
        anchors.leftMargin: 0.3 * root.cqw
        anchors.right: eye.left
        anchors.rightMargin: 0.3 * root.cqw
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        // The input holds the secret and, while masked, paints nothing at all.
        // Zero OPACITY rather than a transparent colour: a selection is drawn
        // with the platform's own highlight pair on any backend that declines
        // a fully transparent one, and that pair brings the agent's bullets
        // back on their own metrics, right over this row.
        TextInput {
            id: input

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            opacity: root.masked ? 0 : 1
            enabled: !root.busy
            echoMode: root.masked ? TextInput.Password : TextInput.Normal
            passwordMaskDelay: 0
            // NOT `text: Lock.password`: a declarative binding here is torn
            // down by the user's first keystroke, and after that the service
            // can no longer put anything in the field — including the wake
            // character. The two are kept in step by hand instead, in both
            // directions, guarded against echoing each other back.
            Component.onCompleted: text = Lock.password
            color: MD.Token.color.on_surface
            selectionColor: MD.Token.color.primary
            selectedTextColor: MD.Token.color.on_primary
            selectByMouse: true
            font.family: Theme.textTypeface
            font.pixelSize: 0.94 * root.cqw
            font.letterSpacing: 0.12 * 0.94 * root.cqw
            font.weight: 520
            activeFocusOnTab: false

            onTextChanged: {
                if (text !== Lock.password) {
                    Lock.setPassword(text);
                }
                Qt.callLater(root.reconcile);
            }
            onCursorPositionChanged: {
                root.recordRange();
                Qt.callLater(root.reconcile);
            }
            onSelectionStartChanged: root.recordRange()
            onSelectionEndChanged: root.recordRange()

            // Attached Keys handlers run before the input's own, which is the
            // only place caps lock can be read once the field owns the
            // keyboard — every character key stops here.
            Keys.onPressed: function (event) {
                Lock.capsLock = WakeRules.capsState(event.key, event.text, event.modifiers, Lock.capsLock);
                if (event.key === Qt.Key_CapsLock) {
                    // A TextInput does not accept the lock key, so without this
                    // the same press walks up to the scene's handler and toggles
                    // the flag straight back — leaving the warning unable to
                    // answer the one key it is about.
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    event.accepted = true;
                    root.submitted();
                }
            }
        }

        // The label is ours in both modes: at zero opacity the input cannot
        // draw its own placeholder, and when it can, a second one under ours
        // would double. It starts on the same vertical the first dot does,
        // which leaves the caret the cell boundary it marks rather than the
        // shoulder of the P.
        MD.Text {
            anchors.verticalCenter: parent.verticalCenter
            x: (root.cell - root.dotSize) / 2
            text: I18n.t("lock.passwordLabel")
            color: MD.Token.color.on_surface_variant
            font.family: Theme.textTypeface
            font.pixelSize: 0.94 * root.cqw
            font.weight: 480
            opacity: Lock.password.length === 0 ? 1 : 0

            Behavior on opacity {
                MotionAnimation {
                    spring: Motion.effectsFast
                }
            }
        }

        Item {
            id: track

            anchors.fill: parent
            visible: root.masked
            x: -root.scrollPx

            // Everything in this track travels on the standard scheme's fast
            // spatial spring, not the expressive one. Geometry belongs on a
            // spatial spring — an effects spring is for colour and alpha — but
            // expressive damps its spatial springs at ζ 0.6, and a caret and a
            // row of 6dp discs each overshooting 9.5% of a cell on their own
            // reads as slop rather than as expression at this size. ζ 0.9 is
            // the same category, quieted: the two schemes differ in nothing
            // else, and their effects springs are identical numbers.
            Behavior on x {
                enabled: !root.reducedMotion

                MotionAnimation {
                    spring: Motion.standardSpatialFast
                }
            }

            // A selection is a filled surface with its own ink, the way every
            // other selected thing in the system is. Both band and dots are
            // addressed by cell index, so they can never drift apart mid-motion.
            Rectangle {
                id: band

                readonly property int span: input.selectionEnd - input.selectionStart

                x: input.selectionStart * root.cell
                anchors.verticalCenter: parent.verticalCenter
                width: span * root.cell
                height: root.bandHeight
                radius: 0.25 * root.cqw
                color: MD.Token.color.primary
                // Painted only while someone is holding it: a saturated bar
                // left standing on a blurred or submitting field says the
                // opposite of what is true.
                opacity: span > 0 && input.activeFocus ? 1 : 0

                Behavior on x {
                    enabled: !root.reducedMotion

                    MotionAnimation {
                        spring: Motion.standardSpatialFast
                    }
                }
                Behavior on width {
                    enabled: !root.reducedMotion

                    MotionAnimation {
                        spring: Motion.standardSpatialFast
                    }
                }
                Behavior on opacity {
                    MotionAnimation {
                        spring: Motion.effectsFast
                    }
                }
            }

            Repeater {
                id: dots

                model: ListModel {
                    id: dotModel
                }

                delegate: Item {
                    id: dot

                    required property int index
                    required property int slot
                    required property bool leaving

                    readonly property bool selected: !leaving && slot >= input.selectionStart && slot < input.selectionEnd

                    x: slot * root.cell + (root.cell - root.dotSize) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.dotSize
                    height: root.dotSize
                    // Depth is declared, not inherited from insertion order: a
                    // retiring dot must not paint over the live one sliding
                    // into its cell.
                    z: leaving ? 1 : 2

                    Behavior on x {
                        enabled: !root.reducedMotion

                        MotionAnimation {
                            spring: Motion.standardSpatialFast
                        }
                    }

                    // Arrival and departure are one number, animated directly.
                    // The obvious spelling — bindings on opacity/scale plus a
                    // Component.onCompleted that assigns them — cannot work:
                    // an imperative assignment DESTROYS the binding, so the
                    // departure would never fire and a deleted dot would sit
                    // fully drawn until its row was reaped. Nothing writes
                    // `presence` except the animation below, so the two
                    // bindings that read it stay live for the whole life of
                    // the dot.
                    Rectangle {
                        id: disc

                        property real presence: 0

                        anchors.fill: parent
                        radius: width / 2
                        color: dot.selected && input.activeFocus ? MD.Token.color.on_primary : MD.Token.color.on_surface
                        // The cell carries the slide, the disc inside it
                        // carries the arrival — one transform each, so the
                        // row's glide stays clean under the dot's own fade.
                        // The scale is a settle, not a pop: it starts near full
                        // size and only takes the edge off the stamp.
                        opacity: presence
                        scale: 0.72 + 0.28 * presence

                        NumberAnimation {
                            id: presenceAnimation

                            target: disc
                            property: "presence"
                            duration: Motion.effectsFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.effectsFast.curve
                        }

                        function settle(to) {
                            presenceAnimation.to = to;
                            presenceAnimation.restart();
                        }

                        Component.onCompleted: settle(1)

                        // The ink crosses on the same fast effects spring the
                        // disc arrived on: a dot picked up by a selection is
                        // one moment with the band that carries it, not a
                        // slower wash trailing behind it.
                        Behavior on color {
                            MotionColorAnimation {
                                spring: Motion.effectsFast
                            }
                        }
                    }

                    // The dot leaves the row the moment the character does; the
                    // ones after it slide down a cell over its corpse while it
                    // shrinks out of the way.
                    onLeavingChanged: if (leaving)
                        disc.settle(0)

                    // Corpses go: an exit that never lands would pile the row
                    // up with invisible dots the grid still counts.
                    Timer {
                        running: dot.leaving
                        interval: Motion.effectsFast.duration + 20
                        onTriggered: root.reap(dot.index)
                    }
                }
            }

            // A caret that blinks through its own move reads as a stutter, so
            // the phase restarts on every move and it is solid while the row
            // is in motion.
            Rectangle {
                id: caret

                property bool blinkOn: true

                // A caret blinking on its own is the one thing left on this
                // row that moves without being asked to, so reduced motion
                // stands it still rather than dimming it.
                readonly property bool blinking: visible && !root.reducedMotion

                x: input.cursorPosition * root.cell
                anchors.verticalCenter: parent.verticalCenter
                width: root.caretWidth
                height: root.caretHeight
                radius: width / 2
                color: Lock.refused ? MD.Token.color.error : MD.Token.color.primary
                z: 3
                visible: input.activeFocus && input.selectionEnd === input.selectionStart && !root.busy
                opacity: blinking && !blinkOn ? 0 : 1

                // The timer is driven from here rather than bound, and that is
                // not a style choice: restart() ASSIGNS `running`, so a
                // `running:` binding would be destroyed by the first keystroke
                // that moved the caret — after which nothing could stop the
                // blink again, neither this setting nor losing the caret.
                function restartBlink() {
                    blinkOn = true;
                    if (blinking) {
                        blink.restart();
                    } else {
                        blink.stop();
                    }
                }

                onXChanged: restartBlink()
                onBlinkingChanged: restartBlink()
                Component.onCompleted: restartBlink()

                Behavior on x {
                    enabled: !root.reducedMotion

                    MotionAnimation {
                        spring: Motion.standardSpatialFast
                    }
                }

                Timer {
                    id: blink

                    repeat: true
                    interval: 530
                    onTriggered: caret.blinkOn = !caret.blinkOn
                }
            }
        }

        // The invisible input is still what the pointer hits, and it hit-tests
        // against bullet glyphs that are not what is on screen. Place the caret
        // against the cells instead, so it lands where it was aimed.
        MouseArea {
            id: pointer

            property int anchorIndex: 0

            anchors.fill: parent
            enabled: root.masked && !root.busy
            cursorShape: Qt.IBeamCursor

            function indexAt(mouseX) {
                return Math.max(0, Math.min(input.text.length, Math.round((mouseX + root.scrollPx) / root.cell)));
            }

            onPressed: function (mouse) {
                input.forceActiveFocus();
                anchorIndex = indexAt(mouse.x);
                input.cursorPosition = anchorIndex;
                input.select(anchorIndex, anchorIndex);
            }
            onPositionChanged: function (mouse) {
                if (!pressed) {
                    return;
                }
                var to = indexAt(mouse.x);
                input.select(anchorIndex, to);
            }
            // A masked field has no words to pick out, so the whole secret is
            // the target.
            onDoubleClicked: input.selectAll()
        }
    }

    // ---- reconciliation --------------------------------------------------

    property int lastLength: 0
    property var pendingRange: null

    function recordRange() {
        // Only a selection that still describes the CURRENT text can name what
        // the next edit replaces.
        if (input.text.length !== lastLength) {
            return;
        }
        pendingRange = {
            "start": input.selectionStart,
            "end": input.selectionEnd
        };
    }

    function liveCount() {
        var n = 0;
        for (var i = 0; i < dotModel.count; i++) {
            if (!dotModel.get(i).leaving) {
                n++;
            }
        }
        return n;
    }

    // Live dots get consecutive slots; a leaving dot keeps the slot it died
    // on, so the row closes over its corpse instead of dragging it along.
    function reslot() {
        var slot = 0;
        for (var i = 0; i < dotModel.count; i++) {
            if (dotModel.get(i).leaving) {
                continue;
            }
            dotModel.setProperty(i, "slot", slot);
            slot++;
        }
    }

    // The model index of the `nth` live dot, or -1.
    function liveIndex(nth) {
        var seen = 0;
        for (var i = 0; i < dotModel.count; i++) {
            if (dotModel.get(i).leaving) {
                continue;
            }
            if (seen === nth) {
                return i;
            }
            seen++;
        }
        return -1;
    }

    function reap(index) {
        if (index >= 0 && index < dotModel.count && dotModel.get(index).leaving) {
            dotModel.remove(index);
        }
    }

    function reconcile() {
        var length = input.text.length;
        var caret = input.cursorPosition;
        var range = pendingRange;
        pendingRange = null;

        var edit = DotRow.plan(liveCount(), length, caret, range);

        for (var r = 0; r < edit.removed; r++) {
            var victim = liveIndex(Math.min(edit.at, liveCount() - 1));
            if (victim >= 0) {
                dotModel.setProperty(victim, "leaving", true);
            }
        }
        for (var a = 0; a < edit.added; a++) {
            var before = liveIndex(edit.at + a);
            var row = {
                "slot": edit.at + a,
                "leaving": false
            };
            if (before >= 0) {
                dotModel.insert(before, row);
            } else {
                dotModel.append(row);
            }
        }
        reslot();

        scrollPx = DotRow.scrollFor(scrollPx, caret, length, cell, field.width, caretGutter);
        lastLength = length;
    }

    // A value set in code announces nothing at all — the wake character, a
    // reset — so the row is squared up against it directly.
    function wipe() {
        dotModel.clear();
        scrollPx = 0;
        lastLength = 0;
        pendingRange = null;
    }

    Connections {
        target: Lock

        function onPasswordChanged() {
            if (input.text === Lock.password) {
                return;
            }
            // Bidirectional sync without a declarative binding, which a
            // TextInput's own edits would break.
            if (Lock.password.length === 0) {
                root.wipe();
            }
            input.text = Lock.password;
            input.cursorPosition = input.text.length;
            Qt.callLater(root.reconcile);
        }
    }
}
