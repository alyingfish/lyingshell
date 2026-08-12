#!/usr/bin/env python3
"""Validate the lock screen's contract with the compositor, PAM, and the brief.

These are the decisions that are cheap to break by accident and expensive to
notice: the ones that make the lock secure, the ones the port was specified on
(turn the mask not the picture, animate the type size not the scale), and the
restricted-panel rule.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

LOCK_SERVICE = ROOT / "Services" / "Lock.qml"
SESSION = ROOT / "Services" / "Session.qml"
SCREEN = ROOT / "Modules" / "Lock" / "LockScreen.qml"
SCENE = ROOT / "Modules" / "Lock" / "LockScene.qml"
CLOCK = ROOT / "Modules" / "Lock" / "LockClock.qml"
AVATAR = ROOT / "Modules" / "Lock" / "LockAvatar.qml"
FIELD = ROOT / "Modules" / "Lock" / "LockPasswordField.qml"
TRAY = ROOT / "Modules" / "Lock" / "LockTray.qml"
MOTION = ROOT / "Modules" / "Lock" / "LockMotion.js"
LOCK_THEME = ROOT / "Commons" / "Theme" / "LockTheme.qml"
THEME = ROOT / "Commons" / "Theme" / "Theme.qml"
BAR_SURFACE = ROOT / "Modules" / "Bar" / "BarSurface.qml"
PANEL_HEADER = ROOT / "Modules" / "QuickSettings" / "Main" / "PanelHeader.qml"
SESSION_MENU = ROOT / "Modules" / "QuickSettings" / "Main" / "SessionMenu.qml"
POPUP = ROOT / "Modules" / "QuickSettings" / "QuickSettingsPopup.qml"
QS_BUTTON = ROOT / "Modules" / "Bar" / "Widgets" / "QuickSettingsButton.qml"

PAM_CONFIG = ROOT / "assets" / "pam.d" / "lyingshell"
SCALLOP_FRAG = ROOT / "assets" / "shaders" / "frag" / "lock_scallop.frag"
SWEEP_FRAG = ROOT / "assets" / "shaders" / "frag" / "lock_sweep.frag"
SCALLOP_QSB = ROOT / "assets" / "shaders" / "qsb" / "lock_scallop.frag.qsb"
SWEEP_QSB = ROOT / "assets" / "shaders" / "qsb" / "lock_sweep.frag.qsb"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> None:
    service = read(LOCK_SERVICE)
    screen = read(SCREEN)
    scene = read(SCENE)
    clock = read(CLOCK)
    avatar = read(AVATAR)
    field = read(FIELD)
    tray = read(TRAY)
    motion = read(MOTION)

    # --- the compositor seam ---------------------------------------------
    assert "import Quickshell.Wayland" in screen
    assert "WlSessionLock {" in screen
    assert "WlSessionLockSurface {" in screen
    # One lock, driven by one property. Nothing else may write it.
    assert "locked: Lock.locked" in screen
    # `secure` is the compositor's confirmation that every output is covered;
    # the sweep surfaces hold their frame until it lands.
    assert 'property: "secure"' in screen
    assert "value: sessionLock.secure" in screen
    assert "onSecureChanged: if (secure && locked)" in service

    # The lock is only ever released after PAM reports success: releaseLock()
    # is the single writer of `locked = false`, and only the unlock sequence
    # calls it.
    assert service.count("locked = false") == 1
    assert "function releaseLock() {\n        locked = false;\n    }" in service
    assert "root.releaseLock();" in service

    # --- PAM --------------------------------------------------------------
    assert "import Quickshell.Services.Pam" in service
    assert "PamContext {" in service
    assert "onResponseRequiredChanged:" in service
    assert "respond(root.password);" in service
    assert "result === PamResult.Success" in service
    assert "root.beginUnlock();" in service
    # A self-contained service, so a stock machine needs no root-owned file;
    # lock.pamConfig points at /etc/pam.d instead.
    assert 'config: root.usingSystemPam ? root.configuredPam : "lyingshell"' in service
    assert 'configDirectory: root.usingSystemPam ? "/etc/pam.d" : Quickshell.shellDir + "/assets/pam.d"' in service
    assert PAM_CONFIG.exists()
    assert "pam_unix.so" in read(PAM_CONFIG)

    # --- the four states --------------------------------------------------
    for phase in ('"glance"', '"ask"', '"pending"', '"hello"'):
        assert phase in service, phase
    # succeeded is NOT a phase: the room stays in pending while the avatar
    # plays its success step alone, and only then enters hello.
    assert "property bool succeeded: false" in service
    assert "succeeded = true;" in service
    assert "successHold.restart();" in service
    assert "phase = root.phaseHello;" in service

    # --- the sweep --------------------------------------------------------
    # ~900ms, overshooting the screen corners, on the prototype's own curve.
    assert "var sweepMs = 900;" in motion
    assert "var sweepCurve = [0.3, 1.06, 0.35, 1.0, 1.0, 1.0];" in motion
    assert "var successHoldMs = 520;" in motion
    assert "1.42 * Math.hypot(width, height) / Math.SQRT2" in motion
    # Two steps, in order, never overlapping: the avatar alone, then the circle.
    assert "interval: root.successHoldDuration" in service
    assert "onTriggered: root.runUnlockSweep()" in service
    # Reduced motion cuts the sweep to nothing; the avatar step still plays.
    assert "readonly property int sweepDuration: reducedMotion ? 0 : LockMotion.sweepMs" in service
    assert "enabled: !root.reducedMotion" in service
    # The circle rides layer-shell surfaces above the desktop, because nothing
    # can be composited beneath a session-lock surface.
    assert "WlrLayershell.layer: WlrLayer.Overlay" in screen
    assert "WlrLayershell.keyboardFocus: Lock.locked ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive" in screen
    assert "mask: Lock.sweepPainting ? null : blockNothing" in screen
    assert "lock_sweep.frag.qsb" in screen
    assert SWEEP_FRAG.exists() and SWEEP_QSB.exists()

    # --- multi-monitor ----------------------------------------------------
    # Every output is covered; the focused one gets the prompt.
    assert "function isFull(name: string): bool" in screen
    assert "Settings.options.lock.focusedOutputOnly" in screen
    assert "focusedOutput.length === 0 || name === focusedOutput" in screen
    assert "property bool full: true" in scene
    # An output that carries no prompt holds its glance pose: the approach is
    # not a global state, it belongs to the output the prompt is on.
    assert "readonly property bool approached: root.full && Lock.phase !== Lock.phaseGlance" in scene
    assert "minimized: root.approached" in scene

    # --- the clock --------------------------------------------------------
    # Grows and shrinks on ONE MD3 Expressive spring, and what travels is the
    # type size: scaling a Text blows up a texture drawn once at layout size.
    assert "property real fontSize: root.targetSize" in clock
    assert "font.pixelSize: root.fontSize" in clock
    assert clock.count("spring: Motion.spatialSlow") == 2
    assert "scale:" not in clock
    # Two tones, stacked, each line centred, proportional figures.
    assert "ink: LockTheme.clockHours" in clock
    assert "ink: LockTheme.clockMinutes" in clock
    assert '"pnum": 1' in clock
    assert "horizontalAlignment: Text.AlignHCenter" in clock
    # Minimized, it is the way back out.
    assert "onTapped: Lock.back()" in clock

    # --- the avatar -------------------------------------------------------
    # Turn the mask, not the picture: the rotation is a shader uniform, and
    # nothing counter-rotates.
    assert "lock_scallop.frag.qsb" in avatar
    assert "property real turn: root.turn * Math.PI / 180" in avatar
    # Exactly one thing turns, and it is the uniform. No item rotation anywhere
    # means there is nothing that could need a counter-turn.
    assert avatar.count("NumberAnimation on turn") == 1
    assert "rotation:" not in avatar
    assert SCALLOP_FRAG.exists() and SCALLOP_QSB.exists()
    scallop = read(SCALLOP_FRAG)
    assert "float angle = atan(centred.y, centred.x) - ubuf.turn;" in scallop
    # The curve is normalized so the crests never move: amp -> 0 is a circle of
    # the SAME diameter, which is what makes the success morph a breathe.
    assert "CREST * (1.0 + ubuf.amp * sin(angle * ubuf.lobes + HALF_PI)) / (1.0 + ubuf.amp)" in scallop
    # The prototype's SCALLOP_R over its 100-unit box: the disc is inset from
    # the slot it is laid out in, and reads 92% of the avatar's box, not 100%.
    assert "const float CREST = 0.46;" in scallop
    assert "property real lobes: 12" in avatar
    assert "property real amplitude: Lock.succeeded ? 0 : 0.10" in avatar
    # It is not interactive here — that is the greeter's user picker.
    assert "HoverHandler" not in avatar
    assert "TapHandler" not in avatar
    # On success the turning stops where it stands.
    assert "running: !Lock.succeeded" in avatar

    # --- the password field ----------------------------------------------
    # The input keeps the secret and stops painting; the row is drawn here.
    assert "echoMode: root.masked ? TextInput.Password : TextInput.Normal" in field
    assert "opacity: root.masked ? 0 : 1" in field
    assert "DotRow.plan(" in field
    assert "DotRow.scrollFor(" in field
    # In pending the arrow becomes the MD3 Expressive loading indicator.
    assert "MD.BusyIndicator {" in field
    assert "running: root.busy" in field
    # Arrival and departure ride one animated number. Assigning opacity/scale
    # imperatively would destroy the bindings that read it, and the departure
    # would silently never run.
    assert "property real presence: 0" in field
    assert "opacity: presence" in field
    assert "scale: 0.72 + 0.28 * presence" in field
    assert "onLeavingChanged: if (leaving)" in field
    assert "opacity = 0;" not in field
    # A TextInput does not accept the lock key, so the field has to, or the
    # scene's handler toggles the same press straight back.
    assert "if (event.key === Qt.Key_CapsLock) {" in field
    # BusyIndicator writes its own `visible`; binding it strands the spinner.
    assert "visible: root.busy" not in field
    assert 'name: "arrow_forward"' in field

    # --- Escape unwinds one layer at a time -------------------------------
    assert "function unwind()" in tray
    assert "if (tray.unwind()) {" in scene
    # The prompt is the only thing that takes typing, so everything that can
    # steal focus from it has to give it back — the tray pill is a Button and
    # claims focus on click, and a hidden panel field does not release it.
    assert "function returnFocus()" in scene
    assert "onPanelOpenChanged: if (!panelOpen)" in scene
    # Tab would move focus to a control the field can never get it back from.
    assert "event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab" in scene
    assert "Lock.back();" in scene
    # Panel layers first: detail view, power menu, expanded rows, then the panel.
    unwind = tray[tray.index("function unwind()"):]
    unwind = unwind[: unwind.index("QuickSettingsButton {")]
    order = [unwind.index(token) for token in ("panel.detail", "panel.sessionMenuOpen", "panel.toolsOpen", "panel.pmodeOpen", "pill.panelOpen = false")]
    assert order == sorted(order), "Escape must unwind the panel from the innermost layer out"

    # --- the restricted panel --------------------------------------------
    header = read(PANEL_HEADER)
    menu = read(SESSION_MENU)
    assert header.count("visible: !Lock.locked") == 2, "tools and settings are hidden while locked"
    assert menu.count("visible: !Lock.locked") == 2, "lock and log out are hidden while locked"
    assert "topRadius: rowLock.visible ? 0 : 14" in menu

    # --- reuse on the lock surface ---------------------------------------
    popup = read(POPUP)
    button = read(QS_BUTTON)
    assert "property Item overlayParent:" in popup
    assert "parent: root.overlayParent" in popup
    assert "property bool registerIpc: true" in button
    assert "Component.onCompleted: if (root.registerIpc)" in button
    assert "registerIpc: false" in tray

    # --- the seams the brief named ---------------------------------------
    session = read(SESSION)
    assert "swaylock" not in session
    assert "Lock.lock();" in session
    bar_surface = read(BAR_SURFACE)
    assert "readonly property bool locked: Lock.locked" in bar_surface

    # --- the lock's own palette ------------------------------------------
    lock_theme = read(LOCK_THEME)
    theme = read(THEME)
    assert "Theme.accentOverride" in lock_theme
    assert "property string accentOverride: " in theme
    assert "MD.Token.color.accentColor = effectiveAccentColor;" in theme
    # The desktop's own seed is what still goes out to external apps.
    assert "accentPush.run(requestedAccentColor, effectiveMode, matugenDir);" in theme
    # Off-spec roles are composed from spec roles, never invented.
    assert "readonly property color onWall: oppositeScheme.surface" in lock_theme
    assert "MD.MdColorMgr {" in lock_theme
    assert "readonly property color clockHours: MD.Token.color.primary" in lock_theme
    assert "readonly property color clockMinutes: MD.Token.color.tertiary" in lock_theme

    # --- the photo is shown as it was shot --------------------------------
    # Only the approach blur and the auth wash ever come between it and the
    # eye, and both are gated on the approach.
    assert "blurEnabled: true" in scene
    assert "color: LockTheme.authScrim" in scene
    # Both are invisible at glance and both fade on the approach, so nothing
    # sits on the photograph until the prompt is asked for. The glance line is
    # the one thing that goes the other way.
    assert scene.count("opacity: root.approached ? 1 : 0") == 3
    assert scene.count("opacity: root.approached ? 0 : 1") == 1
    # No shadow on the ink, and nothing else laid over the photo.
    assert "layer.effect" not in scene
    assert "DropShadow" not in scene

    print("OK: lock contract")


if __name__ == "__main__":
    main()
