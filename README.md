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
- Runtime JSONC settings loaded from `~/.config/lyingshell/settings.jsonc`.
- Material Design 3 theme setup through QmlMaterial.
- Time, weather placeholder, and Niri service boundaries.

Planned:

- Niri workspace and focused-window UI.
- System tray.
- Quick settings.
- Notification panel.
- Settings window.
- Weather integration.

## Requirements

- Linux Wayland session using Niri.
- [Quickshell](https://quickshell.org/).
- Qt 6 QML tooling, including `qmllint` for development checks.
- `git`, `git-lfs`, and `cmake` for the bundled dependency installer.

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

## Settings

On first launch, Lying Shell creates
`~/.config/lyingshell/settings.jsonc` from the settings registry in
`Commons/Settings/SettingsSchema.js`. The runtime file supports `//` and
`/* ... */` comments.

User settings may define only the fields they want to override. Missing fields
use defaults. Unknown fields, malformed JSONC, or invalid values are rejected;
the bad file is left untouched and the shell keeps the previous valid settings,
or defaults during startup. Legacy `settings.json` files are ignored.

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
+-- Commons/               I18n, settings, and theme services
+-- Modules/               User-facing shell surfaces
+-- Services/              Runtime system and compositor services
+-- scripts/               Public install and run scripts
+-- tests/                 Product regression tests
```

Development rules:

- Keep `shell.qml` thin; compose the app in `App/Shell.qml`.
- Use PascalCase QML module directories and `qs.<Path>` imports.
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
