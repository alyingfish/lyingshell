# matugen accent push

Shell-owned matugen config + templates. On every accent/mode change,
`Commons/Theme/Theme.qml` runs matugen once per **installed** app (selective:
absent apps get nothing written) with `--config <this dir>/<app>.toml` and a
mode-appropriate set of fixed ANSI accent hues injected via
`--import-json-string`. Nothing is written under `~/.config/matugen`.

## Palette (hybrid, Comfortable)

- Terminal bg / fg / cursor / selection come from the Material seed
  (`surface`, `on_surface`, `primary`, …) and the `base16.base00..07` gray ramp,
  so the terminal frame matches the desktop and tracks light/dark.
- The 6 ANSI accent hues (red/green/yellow/blue/magenta/cyan) are fixed soft
  anchors per mode — recognizable, so git diffs and syntax stay readable.
  matugen's harmonized `base08-0F` are deliberately unused (they drift hues
  toward the seed).

## Targets

| App | Output | Reload |
|-----|--------|--------|
| kitty | `~/.config/kitty/current-theme.conf` | live via `SIGUSR1` post_hook (no remote control needed) |
| ghostty | `~/.config/ghostty/lyingshell-colors` | new windows |
| alacritty | `~/.config/alacritty/lyingshell-colors.toml` | auto |
| niri | `~/.config/niri/lyingshell-colors.kdl` | auto |
| GTK 3/4 | `~/.config/gtk-{3,4}.0/gtk.css` | app launch |

## One-time wiring

Run `sh wire.sh` once to point each installed app at its color file
(idempotent). GTK needs no wiring. Then start the shell or change the accent.
