#!/usr/bin/env python3
"""Run quick-settings widget pointer QML tests offscreen."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST_FILES = (
    ROOT / "tests" / "qml" / "tst_quick_toggle_pointer.qml",
    ROOT / "tests" / "qml" / "tst_connected_group_pointer.qml",
)
MOCKS = ROOT / "tests" / "qml" / "mocks"


def main() -> None:
    if shutil.which("qml6") is None:
        print("SKIP: quick-settings pointer test requires qml6")
        return

    env = os.environ.copy()
    env["QT_QPA_PLATFORM"] = "offscreen"
    env["QT_FORCE_STDERR_LOGGING"] = "1"
    env["QML_IMPORT_PATH"] = os.pathsep.join(
        path
        for path in (
            str(MOCKS),
            str(Path.home() / ".local/lib"),
            env.get("QML_IMPORT_PATH", ""),
        )
        if path
    )

    for test_file in TEST_FILES:
        subprocess.run(
            [
                "qml6",
                "-I", str(MOCKS),
                "-I", str(Path.home() / ".local/lib"),
                str(test_file),
            ],
            cwd=ROOT,
            env=env,
            text=True,
            check=True,
            timeout=30,
        )
    print("OK: quick-settings qml tests passed")


if __name__ == "__main__":
    main()
