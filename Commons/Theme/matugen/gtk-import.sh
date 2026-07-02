#!/usr/bin/env sh
# Ensure <gtk dir>/gtk.css @imports the Lying Shell-generated lyingshell.css,
# non-destructively (mirrors noctalia's gtk-refresh.py import step). The shell
# runs this after each matugen gtk gen; it's idempotent and self-healing.
# Arg: a gtk config dir (e.g. ~/.config/gtk-4.0).
# ponytail: does not handle a read-only symlinked gtk.css (NixOS). Add
# copy-on-write like noctalia if that setup ever matters.
set -u

d="$1"
imp='@import url("lyingshell.css");'
f="$d/gtk.css"

[ -f "$d/lyingshell.css" ] || exit 0                  # nothing generated yet
if [ ! -f "$f" ]; then
    printf '%s\n' "$imp" > "$f"                        # fresh: just the import
elif ! grep -qF 'lyingshell.css' "$f"; then
    tmp=$(mktemp)                                      # prepend the import, keep content
    { printf '%s\n' "$imp"; cat "$f"; } > "$tmp" && mv "$tmp" "$f"
fi
