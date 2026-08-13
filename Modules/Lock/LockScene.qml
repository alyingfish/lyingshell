import QtQuick
import QtQuick.Effects
import Qcm.Material as MD
import qs.Commons.I18n
import qs.Commons.Settings
import qs.Commons.Theme
import qs.Services
import qs.Material

import "../../Material/Motion.js" as Motion
import "LockMotion.js" as LockMotion
import "WakeRules.js" as WakeRules

// One output's lock scene: everything the prototype's #screen holds, laid out
// in the same units it is.
//
// The prototype sizes the whole screen in container-query units — 1cqw / 1cqh
// are 1% of the surface — so the composition keeps its proportions on any
// display instead of shrinking into the middle of a big one. That is carried
// over literally: every number below is the prototype's own, and `cqw` / `cqh`
// are what make them mean the same thing here.
//
// The photograph is shown as it was shot. Nothing is laid over it at glance —
// no scrim, no gradient, no dim that follows state, no filter — and nothing on
// the wall wears a shadow. The approach blur and the auth wash are the only
// things that ever come between the photo and the eye, and they belong to
// approach and auth.
FocusScope {
    id: root

    // Wallpaper and clock only, for the outputs that are not the focused one.
    property bool full: true
    property string screenName: ""
    // The sweep windows paint a copy of the scene; theirs must never take a
    // key or a click away from the real lock surface underneath.
    property bool interactive: true

    readonly property real cqw: width / 100
    readonly property real cqh: height / 100

    // The approach belongs to the output that carries the prompt. An output
    // showing only wallpaper and a clock has nothing to approach, so it holds
    // its glance pose: no blur, no wash, and the clock stays full size rather
    // than shrinking to crown a cluster that is not there.
    readonly property bool approached: root.full && Lock.phase !== Lock.phaseGlance
    readonly property bool prompting: root.full && Lock.phase === Lock.phaseAsk
    readonly property real wallpaperZoomInset: Settings.options.lock.wallpaperZoom ? 0.04 : 0

    // ---- the identity column's one beat ---------------------------------
    // The pill's distance below the avatar sets it, and the crown above the
    // avatar answers with the same span, so clock, avatar and password read as
    // three even steps down the centre of the screen. The avatar's landmarks
    // live in LockMotion.js: the sweep is anchored on where it rests, and the
    // exit windows need that point without a scene to measure it.
    readonly property real avatarSize: LockMotion.avatarCqh * cqh
    readonly property real authTop: LockMotion.authTopCqh * cqh
    readonly property real avatarCentreY: authTop + avatarSize / 2
    readonly property real labelLine: 1.9375 * cqw
    readonly property real idStep: 6 * cqh + 4.05 * cqh + labelLine + 2.6 * cqh

    // The sweep's origin: where the avatar RESTS, not where its approach
    // transform has it mid-flight.
    readonly property real sweepOriginX: width / 2
    readonly property real sweepOriginY: avatarCentreY

    function wake(seed) {
        Lock.wake(seed);
    }

    // The prompt is the only thing on this screen that takes typing, so
    // anything that could have taken focus away from it has to give it back.
    // The tray pill is a Button and claims focus on click; the panel's own
    // fields claim it too, and a hidden item does NOT release active focus —
    // without this, closing quick settings leaves the lock screen keyboard-dead
    // and the password going into a panel field nobody can see.
    function returnFocus() {
        if (!root.interactive || !root.full) {
            return;
        }
        if (Lock.phase === Lock.phaseAsk) {
            prompt.forceFocus();
        } else {
            root.forceActiveFocus();
        }
    }

    // ---- the photograph --------------------------------------------------

    Image {
        id: wall

        anchors.fill: parent
        source: LockTheme.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        sourceSize: Qt.size(Math.ceil(root.width), Math.ceil(root.height))
    }

    // Blur and wash are full-screen effects, so they share the Expressive
    // slow-effects spring. Their critically damped channel never borrows the
    // overshoot reserved for spatial movement.
    MotionSpring {
        id: approachEffects

        target: root.approached ? 1 : 0
        spring: Motion.effectsSlow
        motionEnabled: !Settings.options.appearance.reducedMotion
    }

    // The approach blur. With wallpaperZoom enabled, inset by -4% so the
    // blur's own transparent margin never reaches the screen edge, exactly as
    // the prototype's 108% box does. A zero inset preserves the blur and wash
    // while removing the Glance <-> Ask zoom.
    MultiEffect {
        source: wall
        x: -root.wallpaperZoomInset * root.width
        y: -root.wallpaperZoomInset * root.height
        width: (1 + 2 * root.wallpaperZoomInset) * root.width
        height: (1 + 2 * root.wallpaperZoomInset) * root.height
        blurEnabled: true
        blur: 1.0
        blurMax: 34
        saturation: 0.12
        autoPaddingEnabled: false
        opacity: Math.max(0, Math.min(1, approachEffects.value))
        visible: root.approached || approachEffects.animating || approachEffects.value > 0.001
    }

    Rectangle {
        anchors.fill: parent
        color: LockTheme.authScrim
        opacity: Math.max(0, Math.min(1, approachEffects.value))
        visible: root.approached || approachEffects.animating || approachEffects.value > 0.001
    }

    // A click that reaches the wall wakes the prompt; interactive surfaces
    // above handle themselves.
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive && root.full && Lock.phase === Lock.phaseGlance

        onClicked: root.wake("")
    }

    // ---- glance line -----------------------------------------------------

    // The line is a partial-screen element: position uses default-spatial and
    // alpha uses default-effects. Separate channels are required by the M3E
    // scheme, and both retain velocity if Escape reverses the approach.
    MotionSpring {
        id: glanceSpatialMotion

        target: root.approached ? 0 : 1
        spring: Motion.spatialDefault
        motionEnabled: !Settings.options.appearance.reducedMotion
    }

    MotionSpring {
        id: glanceEffectsMotion

        target: root.approached ? 0 : 1
        spring: Motion.effectsDefault
        motionEnabled: !Settings.options.appearance.reducedMotion
    }

    Row {
        id: glanceLine

        anchors.horizontalCenter: parent.horizontalCenter
        y: 20.6 * root.cqh
        spacing: 0.9 * root.cqw
        opacity: Math.max(0, Math.min(1, glanceEffectsMotion.value))
        visible: !root.approached || glanceSpatialMotion.animating || glanceEffectsMotion.animating || glanceEffectsMotion.value > 0.001

        transform: Translate {
            y: -2.2 * root.cqh * (1 - glanceSpatialMotion.value)
        }

        MD.Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.format(I18n.t("lock.dateFormat"))
            color: LockTheme.onWall
            font.family: Theme.textTypeface
            font.pixelSize: 1.25 * root.cqw
            font.weight: 560
            font.letterSpacing: 0.015 * 1.25 * root.cqw
        }

        MD.Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "·"
            color: LockTheme.onWall
            opacity: 0.55
            font.family: Theme.textTypeface
            font.pixelSize: 1.25 * root.cqw
        }

        MD.Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Weather.conditionIconName
            size: 1.5 * root.cqw
            color: LockTheme.onWall
        }

        MD.Text {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("bar.temperatureCelsius", {
                "temperature": Weather.temperatureCelsius
            })
            color: LockTheme.onWall
            font.family: Theme.textTypeface
            font.pixelSize: 1.25 * root.cqw
            font.weight: 560
        }
    }

    // ---- the clock -------------------------------------------------------

    LockClock {
        cqw: root.cqw
        cqh: root.cqh
        crownCentreY: root.avatarCentreY - root.idStep
        minimized: root.approached
        returnable: root.prompting && root.interactive
        enabled: root.interactive
    }

    // ---- the identity column --------------------------------------------
    // Rises together on the approach after one shared entrance beat. One
    // normalized spatial spring drives travel and one effects spring drives
    // alpha, so pixel geometry arriving on a new lock surface cannot trigger a
    // false 0px -> resting-pose animation.

    component Rising: Item {
        id: rising

        property int enterDelay: 0
        property bool shown: root.approached
        property bool revealReleased: shown
        readonly property bool reducedMotion: Settings.options.appearance.reducedMotion

        opacity: Math.max(0, Math.min(1, effectsMotion.value))
        visible: root.full && (shown || spatialMotion.animating || effectsMotion.animating || effectsMotion.value > 0.001)
        enabled: root.interactive && Lock.phase === Lock.phaseAsk

        transform: Translate {
            y: 3.2 * root.cqh * (1 - spatialMotion.value)
        }

        function retarget() {
            enterPause.stop();
            if (!shown || reducedMotion) {
                revealReleased = shown;
                return;
            }
            // Stagger only an entrance from hidden rest. Reversing a departure
            // must retarget immediately and preserve the velocity already in
            // both springs.
            if (enterDelay > 0 && spatialMotion.atRest && effectsMotion.atRest && spatialMotion.value < 0.0005 && effectsMotion.value < 0.0005) {
                revealReleased = false;
                enterPause.restart();
            } else {
                revealReleased = true;
            }
        }

        onShownChanged: retarget()
        onReducedMotionChanged: retarget()

        Timer {
            id: enterPause

            interval: rising.enterDelay
            onTriggered: if (rising.shown)
                rising.revealReleased = true
        }

        MotionSpring {
            id: spatialMotion

            target: rising.revealReleased ? 1 : 0
            spring: Motion.spatialDefault
            motionEnabled: !Settings.options.appearance.reducedMotion
        }

        MotionSpring {
            id: effectsMotion

            target: rising.revealReleased ? 1 : 0
            spring: Motion.effectsDefault
            motionEnabled: !Settings.options.appearance.reducedMotion
        }
    }

    Rising {
        id: avatarSlot

        enterDelay: 60
        x: (root.width - width) / 2
        y: root.authTop
        width: root.avatarSize
        height: root.avatarSize

        LockAvatar {
            anchors.fill: parent
            cqw: root.cqw
        }
    }

    Rising {
        enterDelay: 60
        x: (root.width - width) / 2
        y: root.authTop + root.avatarSize + 1.85 * root.cqh
        width: nameLabel.implicitWidth
        height: root.labelLine

        MD.Text {
            id: nameLabel

            anchors.centerIn: parent
            text: Lock.displayName
            color: LockTheme.onWall
            font.family: Theme.textTypeface
            font.pixelSize: 1.25 * root.cqw
            font.weight: Font.DemiBold
        }
    }

    Rising {
        id: promptSlot

        enterDelay: 60
        x: (root.width - width) / 2
        y: root.authTop + root.avatarSize + 4.05 * root.cqh + root.labelLine
        width: prompt.implicitWidth
        height: prompt.implicitHeight + chips.implicitHeight

        Column {
            id: chipColumn

            anchors.horizontalCenter: parent.horizontalCenter

            LockPasswordField {
                id: prompt

                cqw: root.cqw
                cqh: root.cqh

                onSubmitted: Lock.submit()
            }

            // Sized off the pill rather than off the column that holds both:
            // taking the column's width here would make the column's own
            // implicit width depend on it.
            Item {
                id: chips

                implicitWidth: prompt.implicitWidth
                implicitHeight: Math.max(capsChip.implicitHeight, errorChip.implicitHeight)
                width: implicitWidth
                height: implicitHeight

                LockChip {
                    id: capsChip

                    anchors.horizontalCenter: parent.horizontalCenter
                    cqw: root.cqw
                    cqh: root.cqh
                    shown: Lock.capsLock && Lock.phase === Lock.phaseAsk && !Lock.refused
                    icon: "keyboard_capslock"
                    text: I18n.t("lock.capsLock")
                }

                LockChip {
                    id: errorChip

                    anchors.horizontalCenter: parent.horizontalCenter
                    cqw: root.cqw
                    cqh: root.cqh
                    shown: Lock.refused
                    icon: "error"
                    text: I18n.t("lock.wrongPassword")
                    background: MD.Token.color.error_container
                    ink: MD.Token.color.on_error_container
                }
            }
        }
    }

    // ---- the tray --------------------------------------------------------
    // The pill drags the whole quick-settings tree with it (~90ms to
    // construct), and a lock surface pays that on the GUI thread at the
    // worst moment — between the lock request and the compositor confirming
    // coverage. Defer it one tick past the scene's first paint: the lock
    // covers the screen that much sooner, and at glance the pill is
    // invisible anyway.

    readonly property Item tray: trayLoader.item

    property bool trayReady: false

    Timer {
        interval: 0
        running: true
        onTriggered: root.trayReady = true
    }

    Loader {
        id: trayLoader

        anchors.right: parent.right
        anchors.top: parent.top
        active: root.trayReady

        sourceComponent: LockTray {
            visible: root.full
            enabled: root.interactive
            overlayParent: root

            onPanelOpenChanged: if (!panelOpen)
                root.returnFocus()
        }
    }

    // ---- keys ------------------------------------------------------------

    focus: root.interactive

    Keys.onPressed: function (event) {
        Lock.capsLock = WakeRules.capsState(event.key, event.text, event.modifiers, Lock.capsLock);

        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            // One layer at a time: the panel's own layers first (detail view,
            // expanded row, then the panel), then the lock's. The tray is
            // deferred a tick, so it can be absent for the first frames.
            if (tray && tray.unwind()) {
                return;
            }
            Lock.back();
            root.returnFocus();
            return;
        }

        var panelUp = tray ? tray.panelOpen : false;

        if (Lock.phase !== Lock.phaseGlance) {
            // The prompt has exactly one place to type. Qt's default tab
            // navigation would move focus to the reveal eye or the tray pill,
            // and the field declines tab focus, so it could never be reached
            // again — every following keystroke would land nowhere. Swallow it
            // unless the panel is up, where its own fields may want it.
            if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && !panelUp) {
                event.accepted = true;
                root.returnFocus();
            }
            return;
        }

        var verdict = WakeRules.classify(event.key, event.text, event.modifiers, panelUp);
        if (verdict === WakeRules.IGNORE) {
            return;
        }
        event.accepted = true;
        root.wake(verdict === WakeRules.TYPE ? event.text : "");
    }

    // The compositor routes the keyboard to the lock surface, but Qt-internal
    // focus is still ours to hold: a surface that comes up without it swallows
    // the first keystroke, and that keystroke is the one carrying the wake
    // character.
    Component.onCompleted: if (interactive)
        forceActiveFocus()

    onVisibleChanged: if (visible && interactive)
        forceActiveFocus()
}
