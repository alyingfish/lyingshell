#!/usr/bin/env bash
# Single check gate for this repo: QML lint + python test suite.
# Used by agents before every commit, by the PostToolUse hook (--file), and by CI.
#
#   scripts/check.sh              lint all tracked QML, then run all tests
#   scripts/check.sh --file F     lint a single QML file (hook mode), no tests
#   CHECK_SKIP_LINT=1 scripts/check.sh   tests only (e.g. CI without QML deps)
set -euo pipefail
cd "$(dirname "$0")/.."

# Quickshell targets Qt6; the Qt5 qmllint (reports "qmllint 1.0") is a
# syntax-only checker that crashes on Quickshell.Wayland imports. Require Qt6.
find_qmllint() {
    local c
    for c in qmllint-qt6 /usr/lib/qt6/bin/qmllint qmllint; do
        if command -v "$c" >/dev/null 2>&1 &&
            "$c" --version 2>/dev/null | grep -q ' 6\.'; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

lint() {
    local qmllint
    if ! qmllint=$(find_qmllint); then
        echo "check.sh: no Qt6 qmllint found; set CHECK_SKIP_LINT=1 to skip lint" >&2
        return 1
    fi
    # Warnings (unqualified/import noise from the qs.* Quickshell namespace)
    # are printed but only hard errors (non-zero exit) fail the gate.
    "$qmllint" -I "$HOME/.local/lib" -I . "$@"
}

if [[ "${1:-}" == "--file" ]]; then
    [[ -n "${2:-}" ]] || { echo "usage: check.sh --file <file.qml>" >&2; exit 64; }
    lint "$2"
    exit 0
fi

if [[ "${CHECK_SKIP_LINT:-0}" != "1" ]]; then
    # Loop rather than xargs so the failing file is named (51 files, fast enough).
    while IFS= read -r f; do
        lint "$f" || { echo "check.sh: qmllint FAILED on $f" >&2; exit 1; }
    done < <(git ls-files '*.qml' ':!tests/*')
    echo "check.sh: lint OK"
else
    echo "check.sh: lint skipped (CHECK_SKIP_LINT=1)"
fi

for t in tests/test_*.py; do
    python3 "$t" || { echo "check.sh: $t FAILED" >&2; exit 1; }
done
echo "check.sh: all checks passed"
