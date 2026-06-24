#!/usr/bin/env sh
# One-time, idempotent wiring so external apps load the matugen-generated color
# files. Run once after install. The shell (Commons/Theme/Theme.qml) regenerates
# the color files on every accent/mode change; this only points each app at them.
# ponytail: handles the common case (no existing color wiring). Apps with a
# pre-existing custom include are left alone with a printed manual hint.
# No `set -e`: each app's wiring is independent; one hiccup must not skip the rest.
set -u

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

note() { printf '  %s\n' "$1"; }

# ghostty: optional include (?prefix => no error before first generation).
if command -v ghostty >/dev/null 2>&1; then
    f="$cfg/ghostty/config"
    line='config-file = ?lyingshell-colors'
    mkdir -p "$cfg/ghostty"
    [ -f "$f" ] || : >"$f"
    if grep -qF 'lyingshell-colors' "$f"; then note "ghostty: already wired"
    else printf '\n%s\n' "$line" >>"$f"; note "ghostty: added '$line'"; fi
fi

# alacritty: needs [general] import. Only safe to auto-create when no config
# exists; otherwise print the line to add.
if command -v alacritty >/dev/null 2>&1; then
    d="$cfg/alacritty"; f="$d/alacritty.toml"
    imp='import = ["~/.config/alacritty/lyingshell-colors.toml"]'
    mkdir -p "$d"
    [ -f "$d/lyingshell-colors.toml" ] || : >"$d/lyingshell-colors.toml"
    if [ ! -f "$f" ]; then
        printf '[general]\n%s\n' "$imp" >"$f"; note "alacritty: created config with import"
    elif grep -qF 'lyingshell-colors' "$f"; then note "alacritty: already wired"
    else note "alacritty: add to $f -> [general] $imp"; fi
fi

# niri: include after the existing layout so these colors win. Needs the target
# file to exist (niri errors on a missing include), so seed an empty valid file.
if command -v niri >/dev/null 2>&1; then
    d="$cfg/niri"; f="$d/config.kdl"
    mkdir -p "$d"
    [ -f "$d/lyingshell-colors.kdl" ] || printf '// populated by Lying Shell\n' >"$d/lyingshell-colors.kdl"
    if [ ! -f "$f" ]; then note "niri: no config.kdl; add -> include \"lyingshell-colors.kdl\""
    elif grep -qF 'lyingshell-colors.kdl' "$f"; then note "niri: already wired"
    else printf '\ninclude "lyingshell-colors.kdl"\n' >>"$f"; note "niri: added include"; fi
fi

# kitty: standard `include current-theme.conf`. Most setups already have it.
if command -v kitty >/dev/null 2>&1; then
    f="$cfg/kitty/kitty.conf"
    if [ -f "$f" ] && grep -qF 'current-theme.conf' "$f"; then note "kitty: already wired"
    else note "kitty: ensure $f has -> include current-theme.conf"; fi
fi

# GTK 3/4: ~/.config/gtk-*/gtk.css is auto-loaded; no wiring needed.
note "gtk: gtk.css is auto-loaded; nothing to wire"

echo "Done. Restart apps (or trigger an accent/mode change) to apply colors."
