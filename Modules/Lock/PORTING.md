# Foyer lock screen — where the port differs from the prototype

The source of truth is `web-prototype/src/lock/` plus `src/theme/` and
`css/lock.css`. Everything not listed here is a straight port: the four states
and their transitions, the wake tiers, the two-tone clock, the scallop avatar,
the drawn password row, the caps-lock chip, the shake and error chip, the
Escape order, and the minimized clock as the way back out.

Each entry says what changed and what forced it.

## Platform

**1. The entry circle rides the lock surface; only the captures ride
layer-shell.**
The prototype clips the desktop (`#desk`) to a circle and rides it above the
lock scene. Under Wayland nothing can be composited beneath an
`ext-session-lock` surface — niri renders the lock surface plus an opaque
colour and returns (`ref-libs/niri/src/niri.rs`) — and a screencopy taken while
locked captures the lock screen, not the desktop. So the desktop in the entry
circle is a still, captured BEFORE the lock is requested: one frozen
wlr-screencopy frame per output (`ScreencopyView` + `grabToImage`), taken by
short-lived capture windows on the Overlay layer, and the session locks the
moment every output has answered (bounded by `captureBailMs`). Each lock
surface then draws that still above its scene, clipped to the shrinking circle
(`lock_desk.frag`). The gesture the user sees is the prototype's: a circle of
desktop, centred on the avatar, riding above a lock scene that never moves —
the price is that the desktop inside the circle is frozen for the ~900ms of
travel.

*Where the time goes:* the sweep CLOCK starts on the tap, not on the lock.
The circle's full radius overshoots every screen corner, so the prototype's
own curve spends its first ~102ms beyond the corners where nothing visible
moves — and the capture pipeline runs inside that lead-in instead of in
front of it. `LockMotion.entryLeadInMs/entryHoldPoint/entryTailMs/
entryTailCurve` are the exact de Casteljau split of the sweep curve at that
point: when the gates pass, `deskHole` snaps (invisibly — the hold point
still covers every corner on any aspect ratio) to where the prototype would
be and replays the curve's own tail. The gates are `secure` (niri sends it
only after every output has PRESENTED a locked frame), the lead-in, and
each delivered still's first painted frame; `entryBailMs` bounds them all,
sitting just past niri's own 1s surface deadline. A panel open at the tap is
cut, not faded (the quick-settings close transition and the tray popover
slide are disabled during the entry), and the capture handshakes one
committed host frame (`captureHandshakeBailMs`) so the copy — ordered after
that commit on the same Wayland connection — can never carry the panel. The
first wlr-screencopy of a session can lose a race inside a cold capture
backend, so `LockScreen.qml` primes it once at startup with a throwaway
view.

*What this buys:* the session is strictly locked BEFORE the circle moves, not
after it lands; the animation runs on the one window the locked compositor
draws, so it always has frame callbacks; and a keystroke lands on the live
scene from the first locked frame — typing mid-sweep wakes the prompt instead
of dying against an overlay that swallows keys. The captures raise no windows
at all: they render offscreen inside the bar windows
(`LockStillCapture.qml`), because mapping fresh fullscreen surfaces at lock
time stuttered the entry's first frames and provoked a crash in Qt's
`wl_surface.enter` handler (QtWaylandClient dereferences a stale screen while
logging "Ignoring unexpected wl_surface.enter"). The price is that the few
pre-lock frames of capture leave keys on the desktop — the same exposure any
external locker has between invocation and lock.

*Constraint the sweep windows live under:* niri sends per-frame callbacks
only to surfaces it draws, and while locked it draws nothing but the lock
surfaces (`Niri::send_frame_callbacks` gates on the primary scanout output;
everything else falls back to `send_frame_callbacks_on_fallback_timer`,
~1Hz). A window forced to render in that state stalls its render thread on
buffers the compositor releases only at that trickle, and the stall can
wedge the shell's GUI thread — the original port did exactly that on unlock,
which froze the lock screen the moment the avatar's success step finished,
and again on lock, where the bar's shape morph starved and deadened the
keyboard for seconds. So the windows exist only while their sweep runs, and
nothing may require one to render per-frame while `locked` is true:

- *Entry* captures are delivered before the lock is requested, offscreen in
  the bar windows, which park while locked. The circle itself animates on
  the lock surfaces, which the locked compositor draws. The still is drawn
  ABOVE the scene and clipped to the circle, so a lost capture or an
  undecoded image degrades to a plain cut — never to a hole over black.
- The bar and the wallpaper follow the same rule from the desktop's side:
  their windows park while `Lock.locked` (`Modules/Bar/Bar.qml`,
  `Modules/Wallpaper/Background.qml`), and the bar deliberately has no
  lockscreen shape — no morph at lock (it would force frames onto a starved
  window), none at unlock (the desktop the sweep reveals already carries the
  bar in place).
- *Exit* never paints a scene at all. Each lock surface grabs its frozen
  hello pose into an image (an offscreen render of the one window the
  compositor is still drawing), a fresh window buffers that still at full
  cover as its FIRST frame — the one render a hidden window can always
  complete, because a fresh swapchain owes the compositor nothing; niri
  configures and maps new layer surfaces while locked, it merely does not
  draw them — and each window reports the frame presented. The release is
  GATED on every cover's report: the cover commits and the unlock request
  travel the same Wayland connection in that order, so the compositor swaps
  the lock surface for the pre-buffered covers with no gap, and the circle
  opens over the live desktop. The gate is what makes the handoff reliable;
  its deadline (`coverBailMs`) is a safety net for a wedged graphics stack,
  and when it fires the covers are torn down BEFORE the release — a cover
  left up would map late and flash the lock scene over the live desktop —
  so the failure is a clean cut.
- Every wait is bounded by a timer (`captureBailMs`, `entryBailMs`,
  `snapshotBailMs`, `coverBailMs`); deliveries and first-frame reports only
  ever end a wait early or hold a bounded gate. A lost grab degrades its
  output's sweep to a plain cut. The unlock can be DELAYED by rendering only
  up to `coverBailMs`; it can never be stopped by it. Toasts obey the same
  rule from the other side: `ToastOverlay` does not show while the session
  is locked, since the compositor would not draw it and its springs would
  animate an invisible, callback-starved window. A lock tapped while the
  exit circle is still opening cuts the tail and re-locks instead of being
  dropped.

**2. Masks are fragment shaders, not clip-paths.**
QML has no path clipping and cannot punch a hole in a surface, and
`QtQuick.Effects.MultiEffect`'s `maskSource` produces no usable texture in this
environment (verified: a trivial masked effect renders nothing). The masked
surfaces are `ShaderEffect`s over a texture source, following the repo's
existing wallpaper-shader pipeline — `assets/shaders/frag/lock_scallop.frag`,
`lock_sweep.frag` (the exit hole) and `lock_desk.frag` (the entry disc),
compiled to `.qsb` and checked in.

**3. The quick-settings pill is a second instance, not a reparented one.**
The prototype reparents the shell's own `#tray` onto the lock stage. A QML item
cannot move between windows, so the lock raises a second
`QuickSettingsButton` — same widget, same panel, same code. Three things
differ, and they are the only three: it wears glass, it does not claim the
output's `ShellIpc` registration (the bar keeps it), and it is handed a content
item to live in, because a `WlSessionLockSurface` is not a `QsWindow`.

**4. The pill has no backdrop blur of its own.**
The prototype gives the password pill and the tray pill
`backdrop-filter: blur(18px)`. `BackgroundEffect` is a `QsWindow` attached
object, so a lock surface cannot use it, and there is nothing behind a lock
surface to blur in any case. The approach blur already blurs the whole wall
behind both pills, so the local blur would be a blur of a blur; the pills keep
their translucent glass fill and drop it.

## Colour

**5. The lock palette is applied by re-seeding the process scheme.**
QmlMaterial's `MD.Token.color` is one process-wide `MdColorMgr`, and the
shell's own components read it directly. A second `MdColorMgr` handed down a
subtree via `MD.MProp.color` would re-tint the QmlMaterial parts and leave
every lyingshell component — including the quick-settings panel the brief
requires to follow the surface it serves — on the desktop palette. So
`Theme` gained `accentOverride`: while the lock is up the process wears the
lock wallpaper's matugen seed, and the desktop's own seed comes back when the
unlock sweep lands. Dark/light is untouched; it stays one setting. Nothing is
pushed to external apps — `pushAccentColor()` still uses the desktop accent, so
no terminal or GTK theme is rewritten on lock.

A second `MdColorMgr` *is* instantiated, for one role only: `onwall` is the
opposite mode's `surface`, and that is the only value the current scheme cannot
supply.

*Cost:* the desktop revealed during the unlock sweep wears the lock accent
until the sweep lands. The alternative was re-tinting the frozen lock scene
mid-sweep, which is exactly what `hello` forbids.

**6. Off-spec roles are composed, never invented** — as specified. `onwall`,
`onwallDim`, `glass`, `glassHigh` and `authScrim` are built from spec roles at
the prototype's own alphas (`Commons/Theme/LockTheme.qml`, mirroring
`src/lock/color/scheme.js`). The prototype's `hello*` wash roles are not
ported: nothing in `stage.css` reads them any more — the sweep replaced that
layer.

## Motion

**7. The lock transition rides real MD3 Expressive springs instead of the
prototype's hand-tuned curves.**
The prototype's `transform .62s cubic-bezier(.34,1.42,.46,1)` is replaced by
the spec's slow spatial spring (`Motion.spatialSlow`, ζ 0.8 / k 200). Unlike a
fixed-duration Bezier approximation, the analytic spring retains velocity when
the target reverses; that matters when the crown is clicked before its hover
response has landed. A single dimensionless pose drives both scale and travel,
while the small hover tug has its own default-spatial channel because it must
not move the crown's top edge.

The glyphs are laid out at the full pose and transformed only downward. Qt's
GPU curve rasterizer keeps that transformed outline sharp; its default distance
field renderer visibly facets text at this size. Keeping layout size fixed also
avoids `font.pixelSize`'s integer relayout steps, and lets a fixed hit target
enclose the complete hover gesture without feeding animated bounds back into
hover state.

Glance, avatar, account name, and password-field visibility follow the same
rule: travel uses `Motion.spatialDefault`, alpha uses
`Motion.effectsDefault`, and the full-screen blur/wash uses
`Motion.effectsSlow`. `MotionSpring` advances the token physics directly, so
an Escape during Ask does not restart an easing curve and discard the current
velocity. Each visual property is derived from a dimensionless spring value;
mapping a 0×0 lock surface at its real pixel size therefore cannot replay an
entrance accidentally. The shared spring driver also snaps these channels and
removes their entrance delay when reduced motion is enabled.

The lock quick-settings pill does not fade independently. It is treated as the
floating bar's continuation and shares `BarMotion.hiddenOffset` plus the same
default-spatial reveal spring as `BarSurface`: hidden clears the complete
floating bar and shadow above the output, and Ask settles it at the bar's
configured floating inset. The pill becomes non-interactive as soon as it
leaves Ask.

**8. The loading indicator is QmlMaterial's, not the prototype's.**
`MD.BusyIndicator` is the real MD3 Expressive seven-shape morphing indicator
(SoftBurst → Cookie9 → Pentagon → Pill → Sunny → Cookie4 → Oval, 650ms per
shape on a ζ0.6/k200 spring). The prototype re-implements that by hand in
`auth.js` because CSS cannot do it; the brief allows the library one, and it
matches.

**9. Reduced motion is a new setting.**
The shell had none, so `appearance.reducedMotion` was added. It cuts the sweep
to nothing and drops the refusal shake; the avatar's success step still plays,
because it is a morph in place rather than travel and it is the only thing that
says the password landed.

## Input

**10. `beforeinput` has no Qt equivalent.**
The prototype reconciles the drawn dot row against the range `beforeinput`
names, which knows both ends of what was replaced. Qt's `TextInput` has no such
event, so the port records the selection standing immediately before each edit
and uses that as the named range (`LockPasswordField.recordRange`). The two
agree for everything a keyboard or a paste does; only an edit that changes the
selection and the text in one indivisible step (an undo) falls through to the
caret path, which is the prototype's own fallback.

**11. Caps lock has no modifier state in QML.**
The DOM has `getModifierState('CapsLock')`; Qt exposes nothing equivalent. The
lock key's own transition is authoritative, as in the prototype, and is
combined with a letter-case check — any letter that arrives in the wrong case
for the Shift being held reveals the state — so a screen that starts with caps
already on learns it from the first letter typed.

## Content

**12. Fonts.** The prototype ships RF Display / RF Text. The port uses the
configured shell typeface (`appearance.font`, Noto Sans by default), and drops
the clock's `font-stretch: 96%`, which needs a variable font.

**13. The glance line reads the shell's own services** — `Services/Time` and
`Services/Weather` — instead of the prototype's mock. `Weather` is still a
placeholder in this shell (a fixed 24° and `sunny`), so that line shows
placeholder weather until the planned weather integration lands.

**14. The account is `$USER`.** The prototype's roster is demo data. The name
comes from `lock.fullName`, falling back to `$USER`; the portrait comes from
the current user's AccountsService `IconFile`, falling back to the tonal plate
with the account's initial.

## Scope

**15. Not ported, as instructed:** the login/greeter surface — the user picker
(`stage/users.js`), the session picker (`stage/sessions.js`), and the avatar's
hover ring, chevrons and hover scale, all of which sit behind
`data-mode="login"`. The avatar here answers to nothing. The dev bar
(`src/lock/dev/`) is not ported either.

**16. Multi-monitor.** Every output is covered — the protocol requires it, and
it is what makes the lock secure. The focused output gets the whole thing
(avatar, prompt, tray); the rest get the wallpaper and the clock and nothing to
type into, so the prompt is where the user is already looking. Set
`lock.focusedOutputOnly` to false to put the full scene on every output.

**17. Restricted panel while locked.** Hidden: the tools button (screenshot,
colour pick, clipboard — all act on the desktop behind the lock) and the
settings button (it launches an application, which is the oldest lock-screen
bypass there is). The session menu drops **Lock Screen** (meaningless from
behind the lock) and **Log Out** (it would tear the session down without ever
authenticating), and keeps Suspend, Restart and Power Off — physical-button
parity, and GNOME's own rule.

## Verifying

`tests/qml/visual_lock.qml` and `visual_lock_sweep.qml` dump one PNG per state
at the prototype's own 1600×1000 for side-by-side comparison. They need a real
graphics session — see the note in `CLAUDE.md`. `tests/e2e/test_lock_probe.py`
proves the module loads and PAM reaches the password prompt without ever
locking the session.
