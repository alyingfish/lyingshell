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
STILL_CAPTURE = ROOT / "Modules" / "Lock" / "LockStillCapture.qml"
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
TOAST = ROOT / "Modules" / "Toast" / "ToastOverlay.qml"

BAR_WINDOW = ROOT / "Modules" / "Bar" / "Bar.qml"
AUTO_SHAPE = ROOT / "Modules" / "Bar" / "AutoShape.js"
SYSTEM_TRAY = ROOT / "Modules" / "Bar" / "Widgets" / "SystemTray" / "SystemTray.qml"
BACKGROUND = ROOT / "Modules" / "Wallpaper" / "Background.qml"

PAM_CONFIG = ROOT / "assets" / "pam.d" / "lyingshell"
SCALLOP_FRAG = ROOT / "assets" / "shaders" / "frag" / "lock_scallop.frag"
SWEEP_FRAG = ROOT / "assets" / "shaders" / "frag" / "lock_sweep.frag"
DESK_FRAG = ROOT / "assets" / "shaders" / "frag" / "lock_desk.frag"
SCALLOP_QSB = ROOT / "assets" / "shaders" / "qsb" / "lock_scallop.frag.qsb"
SWEEP_QSB = ROOT / "assets" / "shaders" / "qsb" / "lock_sweep.frag.qsb"
DESK_QSB = ROOT / "assets" / "shaders" / "qsb" / "lock_desk.frag.qsb"


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
    # calls it — releaseAndOpen() behind its own mode-and-locked guard, plus
    # the reduced-motion cut.
    assert service.count("locked = false") == 1
    assert "function releaseLock() {\n        locked = false;\n    }" in service
    assert 'if (sweepMode !== "exit" || !locked) {' in service

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

    # Match GNOME's user portrait by resolving the current account through
    # AccountsService. Either lookup failure or image failure keeps the tonal
    # initial; there is no competing shell-specific avatar setting.
    assert '"org.freedesktop.Accounts", "FindUserByName"' in service
    assert '"org.freedesktop.Accounts.User", "IconFile"' in service
    assert "root.accountAvatar = root.busctlData(stdout.text);" in service
    assert "readonly property string portrait: Lock.accountAvatar" in avatar
    assert "Settings.options.lock.avatar" not in avatar
    assert "portrait.length > 0 && portraitImage.status === Image.Ready" in avatar

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
    # The capture and exit windows ride the Overlay layer above the desktop;
    # the entry circle itself rides the lock surfaces, because nothing can be
    # composited beneath a session-lock surface.
    assert "WlrLayershell.layer: WlrLayer.Overlay" in screen
    assert "lock_sweep.frag.qsb" in screen
    assert "lock_desk.frag.qsb" in screen
    assert SWEEP_FRAG.exists() and SWEEP_QSB.exists()
    assert DESK_FRAG.exists() and DESK_QSB.exists()

    # --- nothing renders behind the lock -----------------------------------
    # The compositor sends frame callbacks only to surfaces it draws, and
    # while locked it draws nothing but the lock surfaces: a window forced to
    # render then stalls its render thread and can wedge the whole shell.
    # These are the load-bearing pieces of the fix.
    #
    # Only the exit raises windows; the entry needs none of its own.
    assert 'property string sweepMode: ""' in service
    assert 'readonly property bool sweepActive: sweepMode !== ""' in service
    assert 'model: Lock.sweepMode === "exit" ? Quickshell.screens : []' in screen
    # The session locks BEFORE the circle moves: each output's bar window
    # grabs one frozen screencopy frame of its desktop OFFSCREEN — mapping
    # fresh fullscreen windows at lock time stuttered the entry and provoked
    # a Qt wl_surface.enter crash — the lock is requested the moment every
    # output has answered (or the cap gives up waiting), and a late delivery
    # changes nothing.
    still_capture = read(STILL_CAPTURE)
    assert "ScreencopyView {" in still_capture
    assert "live: false" in still_capture
    assert still_capture.count("Lock.deliverDesktopStill(") == 2
    assert 'readonly property bool armed: Lock.sweepMode === "enter" && root.screen !== null && !root.hold' in still_capture
    # The shot is serialized behind the host window's own overlays fading
    # shut plus a two-frame settle: a still taken mid-fade carries the
    # half-closed quick-settings panel through the whole entry sweep, and
    # firing the screencopy in the same dispatch as the panel teardown is
    # where the stale-screen wl_surface.enter crash reproduced.
    assert "property bool hold: false" in still_capture
    assert "id: settle" in still_capture
    bar_window = read(BAR_WINDOW)
    assert "LockStillCapture {" in bar_window
    assert "hold: root.overlayExpanded" in bar_window
    assert "function deliverDesktopStill(name, grab)" in service
    assert 'if (sweepMode !== "enter" || locked) {' in service
    assert "id: captureBail" in service
    assert "var captureBailMs" in motion
    # The circle starts to move only once the compositor confirms every
    # output is covered — on the lock surfaces themselves.
    assert "function beginEntryReveal()" in service
    # The entry circle is the desktop still drawn ABOVE the scene, clipped to
    # the circle: every failure resolves to transparency and a plain cut to
    # the scene, never to a hole over nothing.
    assert 'readonly property var entryStill: Lock.desktopStills[surface.screen ? surface.screen.name : ""] || null' in screen
    assert "active: surface.entryStill !== null" in screen
    # The exit sweep holds a STILL of the hello pose, grabbed from the real
    # lock surface (which the compositor is actively drawing); the fresh exit
    # window buffers it as its first frame — the one render a hidden window
    # can always complete — and reports the frame so the release follows it.
    assert "grabToImage" in screen
    assert "function onSweepSnapshotWanted()" in screen
    assert "Lock.deliverSweepSnapshot(name, grab);" in screen
    assert "function onFrameSwapped()" in screen
    assert screen.count("Lock.sweepSurfacePainted();") == 1
    # Both gates are timer-driven end to end: a lost capture or grab, an
    # unpainted cover — each degrades its sweep to a cut, and never gates
    # the lock or the release.
    assert "id: snapshotBail" in service
    assert "id: unlockHandoff" in service
    assert "var snapshotBailMs" in motion
    assert "var sweepHandoffMs" in motion
    # Nothing else may animate an overlay the lock hides: toasts wait, and
    # the bar and wallpaper windows park (asserted with the bar below).
    toast = read(TOAST)
    assert "visible: Toast.active && !Lock.locked" in toast
    # The exit sweep runs over a live desktop it must never take anything
    # from: no keyboard, click-through from its first frame. (The entry
    # holds no grab either — the capture is offscreen and invisible, and the
    # few pre-lock frames where keys still reach the desktop are the price
    # of raising no surface that could crash or stutter the entry.)
    assert "WlrLayershell.keyboardFocus: WlrKeyboardFocus.None" in screen
    assert "mask: blockNothing" in screen
    # The circle is anchored on where the avatar rests, from the one set of
    # landmarks the scene also lays out with.
    assert "var sweepOriginYCqh = authTopCqh + avatarCqh / 2;" in motion
    assert "readonly property real avatarSize: LockMotion.avatarCqh * cqh" in scene
    assert "readonly property real authTop: LockMotion.authTopCqh * cqh" in scene
    assert screen.count("Qt.vector2d(0.5, LockMotion.sweepOriginYCqh / 100)") == 2

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
    # The hero pose uses the actual MD3 Expressive slow-spatial physics, not a
    # duration-based Bezier replay. One dimensionless value keeps size and
    # travel synchronized, while a separate default-spatial channel lets hover
    # resize the crown without moving its top edge.
    assert "FrameAnimation {" in clock
    assert "Motion.stepSpring(root.pose, root.poseVelocity, root.targetPose, Motion.spatialSlow" in clock
    assert "Motion.stepSpring(root.hoverPose, root.hoverVelocity, root.targetHover, Motion.spatialDefault" in clock
    assert "Behavior on fontSize" not in clock
    assert "Behavior on blockY" not in clock
    # Surface geometry is applied after the dimensionless pose. A real lock
    # surface is born at 0x0, so cqh must not itself be an animated property or
    # the sweep handoff exposes a second clock growing from zero.
    assert "readonly property real crownTop: crownCentreY - crownSize * lineHeightScale" in clock
    assert "readonly property real blockY: crownTop + (fullTop - crownTop) * pose" in clock
    # Text is laid out once at maximum size. CurveRendering is intended for
    # large/transformed text and avoids the default distance field's facets;
    # continuous transform scale also avoids integer pixelSize stepping.
    assert "font.pixelSize: root.fullSize" in clock
    assert "renderType: Text.CurveRendering" in clock
    assert "scale: root.clockScale" in clock
    assert "font.weight: 700" in clock
    # Hover owns a fixed maximum-size target rather than the changing glyph
    # bounds, preventing geometry -> hover -> geometry feedback.
    assert "readonly property real hoverOvershootScale: hoverScale * 1.016" in clock
    assert "readonly property real glyphOverhang:" in clock
    assert "width: column.width * root.hoverOvershootScale" in clock
    assert "height: (column.height + 2 * root.glyphOverhang) * root.hoverOvershootScale" in clock
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
    # Peeking changes presentation without transferring focus to the eye. A
    # post-click forceActiveFocus is too late: the pressed frame has already
    # dropped the field's focus styling and selection.
    eye = field[field.index("MD.IconButton {"):field.index("// ---- the field")]
    assert "focusPolicy: Qt.NoFocus" in eye
    assert "input.forceActiveFocus()" not in eye
    # BusyIndicator writes its own `visible`; binding it strands the spinner.
    assert "visible: root.busy" not in field
    assert 'name: "arrow_forward"' in field

    # --- Escape unwinds one layer at a time -------------------------------
    assert "function unwind()" in tray
    assert "if (tray && tray.unwind()) {" in scene
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
    # The bar deliberately does NOT track the lock: no shape morph on
    # lock/unlock (the desktop the sweep reveals already looks like the
    # desktop), and the window parks while locked so nothing forces frames
    # onto a surface the compositor no longer draws. The wallpaper parks for
    # the same reason.
    bar_surface = read(BAR_SURFACE)
    bar_window = read(BAR_WINDOW)
    assert "Lock.locked" not in bar_surface
    assert "lockscreenShape" not in read(AUTO_SHAPE)
    assert "updatesEnabled: !Lock.locked" in bar_window
    assert "updatesEnabled: !Lock.locked" in read(BACKGROUND)
    # A parked window keeps its stale buffer, and unparking does not repaint
    # by itself: the panel and popover close the moment the lock gesture
    # starts, and one tick after unlock the bar pokes a pixel so a current
    # frame replaces whatever the park froze.
    assert "onSessionLockingChanged: if (sessionLocking)" in read(QS_BUTTON)
    assert "onSessionLockingChanged: if (sessionLocking)" in read(SYSTEM_TRAY)
    assert "unparkNudge" in bar_window

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
    # The prototype's 108% Ask-state wallpaper remains the default, but its
    # overscan can be disabled without also removing blur or the auth wash.
    assert "Settings.options.lock.wallpaperZoom ? 0.04 : 0" in scene
    assert "x: -root.wallpaperZoomInset * root.width" in scene
    assert "width: (1 + 2 * root.wallpaperZoomInset) * root.width" in scene
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
