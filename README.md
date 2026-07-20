# Lying Shell

A Quickshell desktop shell for [Niri](https://github.com/YaLTeR/niri), built
with Material Design 3 through QmlMaterial.

Lying Shell is early-stage software. The current shell is intentionally small:
it provides the project foundation, a top bar, shared settings/theme/I18n
services, and the service boundaries needed for Niri-first desktop shell work.

## Features

Implemented:

- Quickshell entrypoint and app composition.
- Per-monitor top bar.
- Date/time display.
- English and Simplified Chinese locale bundles.
- Runtime JSON settings loaded from `~/.config/lyingshell/settings.json`.
- Material Design 3 theme setup through QmlMaterial.
- Time, weather placeholder, and Niri service boundaries.
- Niri workspace and focused-window UI.
- System tray.
- Quick settings.

Planned:

- Notification panel.
- Settings window.
- Weather integration.

## Requirements

- Linux Wayland session using Niri.
- [Quickshell](https://quickshell.org/).
- Qt 6 QML tooling, including `qmllint` for development checks.
- `git`, `git-lfs`, and `cmake` for the bundled dependency installer.
- `wl-clipboard` (`wl-copy`) for the quick-settings color picker's copy-to-clipboard.

## Install Dependencies

Run from this repository root:

```bash
scripts/install.sh
```

The installer builds QmlMaterial and installs its QML module under
`~/.local/lib`.

## Run

```bash
scripts/run.sh
```

The launcher starts Quickshell with this repository as the shell path and adds
`~/.local/lib` to `QML_IMPORT_PATH`.

## CLI and niri keybindings

External processes drive the shell through Quickshell IPC. `scripts/ctl.sh`
wraps the instance addressing:

```bash
scripts/ctl.sh panels toggle quicksettings   # toggle the panel on the focused monitor
scripts/ctl.sh panels list                   # registered panel names
scripts/ctl.sh tools colorPicker             # run the color picker flow
scripts/ctl.sh show                          # list every IPC target/function
```

niri cannot register keybindings at runtime, so bind keys in your niri
`config.kdl` to spawn the CLI (with the absolute path of this checkout):

```kdl
binds {
    Mod+G hotkey-overlay-title="Toggle Quick Settings" { spawn "/path/to/lyingshell/scripts/ctl.sh" "panels" "toggle" "quicksettings"; }
    Mod+P hotkey-overlay-title="Pick Color" { spawn "/path/to/lyingshell/scripts/ctl.sh" "tools" "colorPicker"; }
}
```

`Mod` is the Super/Win key in a regular niri session. The command layer is
extensible: new panels register with `Services/ShellIpc.qml` per screen, and
new tools add a typed function to its `tools` handler.

## Settings

On first launch, Lying Shell creates
`~/.config/lyingshell/settings.json` from the defaults in
`Commons/Settings/Settings.qml`. The file is plain JSON and is primarily a
persistence target for the planned settings window.

## Development

Useful checks:

```bash
qmllint -I "$HOME/.local/lib" shell.qml
python3 tests/test_settings_config.py
```

Repository layout:

```text
.
+-- shell.qml              Quickshell entrypoint
+-- App/                   Top-level shell composition
+-- Commons/               I18n, settings, theme, and shared icon mappings
+-- Material/              Custom Material building blocks (wrappers, motion)
+-- Modules/               User-facing shell surfaces (Bar, QuickSettings, ...)
+-- Services/              Runtime system and compositor services
+-- scripts/               Public install and run scripts
+-- tests/                 Product regression tests
```

Development rules:

- Keep `shell.qml` thin; compose the app in `App/Shell.qml`.
- Route static visible text through project I18n tokens.
- Use Quickshell services before external commands.

## Scope

Lying Shell is a desktop shell, not a full desktop environment. It focuses on
the visual and interactive layer around Niri: bars, panels, status surfaces,
notifications, settings, and compositor-aware shell UI.

Niri is the primary target. Compatibility with other compositors is not a goal
unless a specific compatibility layer is designed first.

## License

Lying Shell is licensed under the GNU General Public License version 3.0.
See `LICENSE`.

Third-party runtime and build dependencies are not vendored in this repository.
Notable dependencies include Quickshell (LGPL-3.0), QmlMaterial (MIT), Qt 6
(LGPL-3.0/GPL-3.0/commercial options), Niri (GPL-3.0), and Material Symbols
(Apache-2.0 through QmlMaterial).
