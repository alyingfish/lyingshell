#!/usr/bin/env python3
"""Walk the REAL lock state machine through both sweeps, offscreen.

tests/qml/tst_lock_flow.qml drives Services/Lock.qml — the actual file, not a
mock — through entry, exit, the failure bails, and the re-lock race, playing
the surfaces' part by hand. The contract test pins what the source says; this
pins what it does: the release gated on every cover's paint report, a failed
capture never holding a gate, the bail cutting clean, a re-lock never dropped.

The mock tree cannot simply shadow qs.Services (the mock Lock lives there for
the pointer tests), so the real Lock.qml is staged into a scratch module —
LockFlowTest — beside a copy of LockMotion.js at the same relative path the
product file imports it from.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOCKS = ROOT / "tests" / "qml" / "mocks"
TEST_FILE = ROOT / "tests" / "qml" / "tst_lock_flow.qml"
PASS_MARKER = "PASS: lock flow"


def stage(tmp: Path) -> None:
    module = tmp / "LockFlowTest"
    module.mkdir(parents=True)
    shutil.copy2(ROOT / "Services" / "Lock.qml", module / "Lock.qml")
    (module / "qmldir").write_text(
        "module LockFlowTest\nsingleton Lock 1.0 Lock.qml\n", encoding="utf-8"
    )
    # Lock.qml imports "../Modules/Lock/LockMotion.js" relative to itself.
    motion = tmp / "Modules" / "Lock"
    motion.mkdir(parents=True)
    shutil.copy2(
        ROOT / "Modules" / "Lock" / "LockMotion.js", motion / "LockMotion.js"
    )


def main() -> None:
    if shutil.which("qml6") is None:
        print("SKIP: lock flow test requires qml6")
        return

    with tempfile.TemporaryDirectory(prefix="lockflow-") as tmpdir:
        tmp = Path(tmpdir)
        stage(tmp)

        env = os.environ.copy()
        env["QT_QPA_PLATFORM"] = "offscreen"
        env["QT_FORCE_STDERR_LOGGING"] = "1"
        env["QML_IMPORT_PATH"] = os.pathsep.join(
            path
            for path in (
                str(tmp),
                str(MOCKS),
                str(Path.home() / ".local/lib"),
                env.get("QML_IMPORT_PATH", ""),
            )
            if path
        )

        result = subprocess.run(
            [
                "qml6",
                "-I",
                str(tmp),
                "-I",
                str(MOCKS),
                "-I",
                str(Path.home() / ".local/lib"),
                str(TEST_FILE),
            ],
            cwd=ROOT,
            env=env,
            text=True,
            timeout=60,
            capture_output=True,
        )
        # A failing verify() aborts under qml6; the explicit marker is what
        # proves the walk ran to the end.
        output = result.stdout + result.stderr
        assert PASS_MARKER in output, (
            f"lock flow walk did not report PASS (exit {result.returncode}):\n{output}"
        )

    print("OK: lock flow behavior holds")


if __name__ == "__main__":
    main()
