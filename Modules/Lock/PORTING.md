# Foyer lock screen — where the port differs from the prototype

The source of truth is `web-prototype/src/lock/` plus `src/theme/` and
`css/lock.css`. Everything not listed here is a straight port: the four states
and their transitions, the wake tiers, the two-tone clock, the scallop avatar,
the drawn password row, the caps-lock chip, the shake and error chip, the
Escape order, and the minimized clock as the way back out.

Each entry says what changed and what forced it.

## Platform

**1. The sweep rides layer-shell surfaces, not the lock surface.**
The prototype clips the desktop (`#desk`) to a circle and rides it above the
lock scene. Under Wayland nothing can be composited beneath an
`ext-session-lock` surface — niri renders the lock surface plus an opaque
colour and returns (`ref-libs/niri/src/niri.rs`) — and a screencopy taken while
locked captures the lock screen, not the desktop. So the circle is instead a
hole cut in the lock scene, drawn on ordinary layer-shell surfaces on the
Overlay layer, which sit above the desktop and below the lock. The gesture the
user sees is the prototype's: a circle of desktop, centred on the avatar,
riding above a lock scene that never moves — and the desktop showing through it
is live rather than a still.

*Cost:* the session is strictly locked only for the second half of the entry
gesture. For the ~900ms the circle takes to shrink, the sweep surface holds
exclusive keyboard focus over the desktop, and `WlSessionLock.locked` goes true
when the circle lands. Locking first and animating after would mean animating
over a black screen, since there is nothing to reveal.

**2. Masks are fragment shaders, not clip-paths.**
QML has no path clipping and cannot punch a hole in a surface, and
`QtQuick.Effects.MultiEffect`'s `maskSource` produces no usable texture in this
environment (verified: a trivial masked effect renders nothing). Both masked
surfaces are `ShaderEffect`s over a `ShaderEffectSource`, following the repo's
existing wallpaper-shader pipeline — `assets/shaders/frag/lock_scallop.frag`
and `lock_sweep.frag`, compiled to `.qsb` and checked in.

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

**7. The clock rides an MD3 Expressive spring instead of the prototype's
hand-tuned curve.**
As asked, the type size animates rather than `scale`. The prototype's
`transform .62s cubic-bezier(.34,1.42,.46,1)` is replaced by the spec's slow
spatial spring (`Motion.spatialSlow`, ζ 0.8 / k 200, 452ms) — the brief asked
for one MD3 Expressive spring, and `Material/Motion.js` deliberately carries
only androidx's own token values. The visible difference is a little less
overshoot.

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
comes from `lock.fullName`, falling back to `$USER`; the portrait from
`lock.avatar`, falling back to the tonal plate with the account's initial.

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
