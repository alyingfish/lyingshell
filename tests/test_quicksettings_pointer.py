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
    ROOT / "tests" / "qml" / "tst_quicksettings_motion.qml",
    ROOT / "tests" / "qml" / "tst_powermode_matrix.qml",
    ROOT / "tests" / "qml" / "tst_wifi_detail_refresh.qml",
    ROOT / "tests" / "qml" / "tst_color_readout.qml",
)
MOCKS = ROOT / "tests" / "qml" / "mocks"


def main() -> None:
    if shutil.which("qml6") is None:
        print("SKIP: quick-settings pointer test requires qml6")
        return

    env = os.environ.copy()
    env["QT_QPA_PLATFORM"] = "offscreen"
    env["QT_FORCE_STDERR_LOGGING"] = "1"
    # The I18n mock reads the real en.json bundle over a file XHR.
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

    for test_file in TEST_FILES:
        result = subprocess.run(
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
            capture_output=True,
        )
        # qml6 exits 0 even when TestCase never ran (e.g. load errors that
        # only warn); require the explicit end-of-test marker.
        output = result.stdout + result.stderr
        if "PASS:" not in output or "FAIL" in output:
            raise SystemExit(
                f"{test_file.name} did not complete its assertions:\n{output}"
            )
    print("OK: quick-settings qml tests passed")


if __name__ == "__main__":
    main()
