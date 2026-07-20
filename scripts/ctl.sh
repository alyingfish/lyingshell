#!/usr/bin/env bash
# CLI entry point for external processes (niri binds, scripts):
#
#   scripts/ctl.sh panels toggle quicksettings
#   scripts/ctl.sh tools colorPicker
#   scripts/ctl.sh show                # list every target/function
#
# Wraps `qs ipc --path <repo>` so the call addresses the shell instance
# launched from this checkout (run.sh starts quickshell with the same path).
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"

bin=qs
command -v "$bin" >/dev/null || bin=quickshell
command -v "$bin" >/dev/null || {
  echo "Missing required command: quickshell (qs)" >&2
  exit 1
}

if [[ "${1:-}" == "show" ]]; then
  exec "$bin" ipc --path "$repo_dir" show
fi

exec "$bin" ipc --path "$repo_dir" call "$@"
