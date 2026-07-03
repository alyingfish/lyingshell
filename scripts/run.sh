#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"

command -v quickshell >/dev/null || {
  echo "Missing required command: quickshell" >&2
  exit 1
}

export QML_IMPORT_PATH="$HOME/.local/lib${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"

# The shell renders on the iGPU via Mesa; without these glvnd also maps the
# whole NVIDIA userspace (EGL + GLX, ~200MB RSS) just to enumerate it.
mesa_icd="/usr/share/glvnd/egl_vendor.d/50_mesa.json"
[[ -f "$mesa_icd" ]] && export __EGL_VENDOR_LIBRARY_FILENAMES="$mesa_icd"
export __GLX_VENDOR_LIBRARY_NAME=mesa

# Quickshell runs ~38 threads; unbounded glibc arenas fragment the heap RSS.
export MALLOC_ARENA_MAX=2

exec quickshell --path "$repo_dir"
