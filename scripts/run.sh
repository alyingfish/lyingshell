#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$script_dir/.." && pwd)"

command -v quickshell >/dev/null || {
  echo "Missing required command: quickshell" >&2
  exit 1
}

export QML_IMPORT_PATH="$HOME/.local/lib${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"

exec quickshell --path "$repo_dir"
