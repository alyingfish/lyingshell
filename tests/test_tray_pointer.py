#!/usr/bin/env python3
"""Run tray logic + pointer-event QML tests offscreen."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEST_FILES = (
    ROOT / "tests" / "qml" / "tst_tray_pinning.qml",
    ROOT / "tests" / "qml" / "tst_tray_item_pointer.qml",
)


def main() -> None:
    if shutil.which("qml6") is None:
        print("SKIP: tray pointer test requires qml6")
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
        subprocess.run(
            ["qml6", "-I", str(Path.home() / ".local/lib"), str(test_file)],
            cwd=ROOT,
            env=env,
            text=True,
            check=True,
            timeout=30,
        )
    print("OK: tray qml tests passed")


if __name__ == "__main__":
    main()
