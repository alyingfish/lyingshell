#!/usr/bin/env sh
# Ensure <gtk dir>/gtk.css @imports the Lying Shell-generated lyingshell.css,
# non-destructively (mirrors noctalia's gtk-refresh.py import step). The shell
# runs this after each matugen gtk gen; it's idempotent and self-healing.
# Arg: a gtk config dir (e.g. ~/.config/gtk-4.0).
set -u

d="$1"
imp='@import url("lyingshell.css");'
f="$d/gtk.css"

[ -f "$d/lyingshell.css" ] || exit 0                  # nothing generated yet
if [ ! -f "$f" ]; then
    printf '%s\n' "$imp" > "$f"                        # fresh: just the import
    exit 0
fi
grep -qF 'lyingshell.css' "$f" && exit 0              # already imported

# Prepend the import, preserving existing content. Handle a symlinked gtk.css
# like noctalia's gtk-refresh.py: edit a writable target in place (keeps a
# dotfiles symlink intact), detach a read-only target (e.g. a NixOS store path)
# to a local copy since mv would otherwise clobber the symlink.
target="$f"
if [ -L "$f" ]; then
    if [ -w "$f" ]; then                              # -w follows the link to the target
        target=$(readlink -f "$f")
    else
        cp "$f" "$f.new" && rm "$f" && mv "$f.new" "$f"
    fi
fi
tmp=$(mktemp)
{ printf '%s\n' "$imp"; cat "$target"; } > "$tmp" && mv "$tmp" "$target"
