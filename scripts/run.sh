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

# Vulkan (RADV/ACO) scenegraph: the GL path on this iGPU holds ~120MB more
# anon RSS (glthread marshal buffers + per-window GL contexts). Measured
# 478MB -> 330MB on 2026-07-06, identical rendering.
export QSG_RHI_BACKEND=vulkan

# RADV still links libLLVM; its constructors leave ~95MB of clean,
# never-executed-again pages resident. Run the shell in its own scope and
# evict them once startup settles; anything hot just refaults from page cache.
# Measured 330MB -> ~225MB. Without systemd we simply skip the trim.
if command -v systemd-run >/dev/null; then
  unit="lyingshell-$$"
  (
    sleep 20
    cg="$(systemctl --user show -P ControlGroup "$unit.scope" 2>/dev/null)" || exit 0
    # EAGAIN when less than the full amount is reclaimable; that's fine.
    echo 256M >"/sys/fs/cgroup$cg/memory.reclaim" 2>/dev/null || true
  ) &
  exec systemd-run --user --scope --quiet --collect --unit="$unit" \
    quickshell --path "$repo_dir"
fi

exec quickshell --path "$repo_dir"
