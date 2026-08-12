#!/usr/bin/env python3
"""Run the lock screen's pure-rule and clock-motion QML tests offscreen."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOCKS = ROOT / "tests" / "qml" / "mocks"
TEST_FILES = (
    (ROOT / "tests" / "qml" / "tst_lock_rules.qml", "PASS: lock rules"),
    (ROOT / "tests" / "qml" / "tst_lock_clock.qml", "PASS: lock clock motion"),
)


def main() -> None:
    if shutil.which("qml6") is None:
        print("SKIP: lock rules test requires qml6")
        return

    env = os.environ.copy()
    env["QT_QPA_PLATFORM"] = "offscreen"
    env["QT_FORCE_STDERR_LOGGING"] = "1"
    # The shared I18n mock reads the real English bundle from the repository.
    env["QML_XHR_ALLOW_FILE_READ"] = "1"
    env["QML_IMPORT_PATH"] = os.pathsep.join(
        path
        for path in (
            str(MOCKS),
            str(Path.home() / ".local/lib"),
            env.get("QML_IMPORT_PATH", ""),
        )
        if path
    )

    for test_file, pass_marker in TEST_FILES:
        result = subprocess.run(
            [
                "qml6",
                "-I",
                str(MOCKS),
                "-I",
                str(Path.home() / ".local/lib"),
                str(test_file),
            ],
            cwd=ROOT,
            env=env,
            text=True,
            check=True,
            timeout=30,
            capture_output=True,
        )
        # A failing verify() aborts silently under qml6, so the explicit marker
        # is what proves the file ran to the end.
        output = result.stdout + result.stderr
        assert pass_marker in output, f"{test_file.name} did not report PASS:\n{output}"

    print("OK: lock QML tests passed")


if __name__ == "__main__":
    main()
