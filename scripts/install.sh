#!/usr/bin/env bash
set -euo pipefail

repo_url="https://github.com/hypengw/QmlMaterial.git"
source_dir="${XDG_CACHE_HOME:-$HOME/.cache}/QmlMaterial"
build_dir="$source_dir/build"
install_root="$HOME/.local/lib"

for cmd in git git-lfs cmake; do
  command -v "$cmd" >/dev/null || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

if [[ -d "$source_dir/.git" ]]; then
  git -C "$source_dir" pull --ff-only
elif [[ -e "$source_dir" ]]; then
  echo "Refusing to use non-git path: $source_dir" >&2
  exit 1
else
  GIT_LFS_SKIP_SMUDGE=1 git clone --depth=1 "$repo_url" "$source_dir"
fi

git -C "$source_dir" lfs pull

cmake -S "$source_dir" -B "$build_dir" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
  -DQML_INSTALL_DIR="$install_root" \
  -DQM_BUILD_EXAMPLE=OFF \
  -DQM_BUILD_TESTS=OFF

cmake --build "$build_dir" --target qml_materialplugin --parallel 2
cmake --install "$build_dir" --strip

echo
echo "Done!"
