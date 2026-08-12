#!/usr/bin/env python3
"""Run the lock screen's wake-tier and drawn-row QML tests offscreen."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST_FILES = (ROOT / "tests" / "qml" / "tst_lock_rules.qml",)


def main() -> None:
    if shutil.which("qml6") is None:
        print("SKIP: lock rules test requires qml6")
        return

    env = os.environ.copy()
    env["QT_QPA_PLATFORM"] = "offscreen"
    env["QT_FORCE_STDERR_LOGGING"] = "1"
    env["QML_IMPORT_PATH"] = os.pathsep.join(
        path
        for path in (str(Path.home() / ".local/lib"), env.get("QML_IMPORT_PATH", ""))
        if path
    )

    for test_file in TEST_FILES:
        result = subprocess.run(
            ["qml6", "-I", str(Path.home() / ".local/lib"), str(test_file)],
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
        assert "PASS: lock rules" in output, f"{test_file.name} did not report PASS:\n{output}"

    print("OK: lock rules qml tests passed")


if __name__ == "__main__":
    main()
