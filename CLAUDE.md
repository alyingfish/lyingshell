# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

Lying Shell is a Quickshell desktop shell for the Niri compositor, styled with
Material Design 3 via the QmlMaterial library. Import namespace is `qs.*`
(e.g. `import qs.Commons.Settings`).

## Commands

- `scripts/install.sh` — build QmlMaterial and install its QML module to `~/.local/lib`.
- `scripts/run.sh` — launch the shell (Quickshell with this repo as shell path; sets `QML_IMPORT_PATH=~/.local/lib` plus GPU/memory tuning).
- `scripts/check.sh` — the check gate: Qt6 qmllint over all tracked production
  QML, then the full python test suite. Run it before every commit; CI runs the
  same script. `CHECK_SKIP_LINT=1` runs tests only; `--file <f.qml>` lints one
  file (used by the PostToolUse hook). Note the plain `qmllint` on PATH may be
  Qt5's syntax-only checker — check.sh resolves a Qt6 qmllint itself.
- `python3 tests/test_<name>.py` — run a single test. Each test file is a
  standalone script with a `main()` (they are **not** pytest-collected; run
  them directly).
- QML behavior tests (`tests/qml/tst_*.qml`) are driven by the python wrappers
  via `qml6` offscreen with mocks from `tests/qml/mocks/`; they print `SKIP`
  and exit 0 when `qml6` is missing. A failing `verify()` under `qml6` aborts
  silently — the wrappers treat a missing `PASS:` marker as failure.
- `tests/qml/visual_*.qml` dump PNGs for eyeballing against the web prototype;
  they are not part of the gate. `visual_lock*.qml` must run in a REAL graphics
  session (no `QT_QPA_PLATFORM=offscreen`): the offscreen plugin loads the
  software scene-graph backend, which silently draws nothing for a
  `ShaderEffect`, and both the avatar's scallop and the sweep's circle are
  shaders. They open a 48px stub window and grab a full-size item instead.
- `tests/e2e/` tests need a live Niri session, refuse to run if quickshell is
  already running, and restore any system state they touch.

## Architecture

- `shell.qml` — thin entrypoint holding only `//@ pragma` directives; all
  composition happens in `App/Shell.qml`. Keep it that way.
- `Commons/` — app-wide singletons:
  - `Settings/Settings.qml` — defaults + runtime JSON persisted at
    `~/.config/lyingshell/settings.json`.
  - `I18n/I18n.qml` — `I18n.t()` lookups over locale bundles
    (`locales/en.json`, `locales/zh-CN.json`); a `version` property
    invalidates bindings on locale change.
  - `Theme/` — MD3 theme setup (QmlMaterial + matugen accent colors).
- `Services/` — one singleton per system concern (Audio, Brightness,
  NightLight, PowerMode, Time, Weather, …). `Services/Niri/` is the single
  source of truth for compositor state (event-stream protocol in
  `NiriProtocol.js` / `NiriState.js`).
- `Modules/` — user-facing surfaces composed from Services + Commons:
  `Bar/` (per-monitor top bar with widgets), `QuickSettings/`, `Wallpaper/`,
  `Lock/` (ext-session-lock surfaces + the layer-shell surfaces the lock/unlock
  sweep runs on; state and PAM live in `Services/Lock.qml`).
- `Material/` — custom MD3 building blocks and motion tokens (`Motion.js`,
  `MotionAnimation.qml`); motion values are contract-tested by
  `tests/test_motion_tokens.py`.

Test layers: `tests/test_*_contract.py` parse QML source and assert structure;
`tests/test_*_pointer.py` run QML `TestCase`s offscreen against mocks;
`tests/e2e/` drives the real shell over quickshell IPC on a live session.

The checked-in `.claude/` provides the `worktree-task` skill (how to
start/finish a task in its own worktree), the permission allowlist, and a
PostToolUse hook that lints every QML edit via `scripts/check.sh --file`.
Because it is committed, every task worktree gets the same hook, permissions,
and skill. Follow the skill when starting parallel work.

## Rules

- Use QmlMaterial components and tokens for visible UI; custom widgets go in `Material/`.
- Route every static visible string through I18n tokens; update both
  `Commons/I18n/locales/en.json` and `zh-CN.json` in the same commit, and keep
  keys alphabetically sorted at every nesting level (enforced by
  `tests/test_i18n_locales_contract.py`) so parallel branches don't all
  conflict at the end of the file.
- Contract tests pin QML structure on purpose: when you intentionally change a
  contract (a property value, a wiring pattern), update the matching
  `tests/test_*_contract.py` in the same commit.
- Prefer Quickshell built-in services over spawning external commands.
- Read compositor state only through the `Niri` singleton.
- Niri is the only target compositor; no compatibility shims for others.
