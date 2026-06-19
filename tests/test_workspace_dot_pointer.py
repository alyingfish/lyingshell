#!/usr/bin/env python3
"""Run Qt Quick pointer-event tests for workspace widgets."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEST_FILES = (
    ROOT / "tests" / "qml" / "tst_workspace_dot_pointer.qml",
    ROOT / "tests" / "qml" / "tst_workspaces_pointer.qml",
)


def create_settings_mock(import_root: Path) -> None:
    settings_dir = import_root / "qs" / "Commons" / "Settings"
    settings_dir.mkdir(parents=True)
    (settings_dir / "qmldir").write_text(
        "module qs.Commons.Settings\nsingleton Settings 1.0 Settings.qml\n",
        encoding="utf-8",
    )
    (settings_dir / "Settings.qml").write_text(
        """pragma Singleton
import QtQml

QtObject {
    readonly property QtObject options: QtObject {
        readonly property QtObject bar: QtObject {
            readonly property QtObject workspaces: QtObject {
                property bool reverseScroll: false
                property bool scrollLoop: true
                property bool urgentPulse: true
            }
        }
    }
}
""",
        encoding="utf-8",
    )


def main() -> None:
    if shutil.which("qml6") is None:
        print("SKIP: workspace pointer test requires qml6")
        return

    with tempfile.TemporaryDirectory(prefix="lyingshell-qml-pointer-imports-") as temp_import_root:
        import_root = Path(temp_import_root)
        create_settings_mock(import_root)

        env = os.environ.copy()
        env["QT_QPA_PLATFORM"] = "offscreen"
        env["QML_IMPORT_PATH"] = os.pathsep.join(
            path
            for path in (
                str(import_root),
                str(Path.home() / ".local/lib"),
                env.get("QML_IMPORT_PATH", ""),
            )
            if path
        )

        for test_file in TEST_FILES:
            subprocess.run(
                [
                    "qml6",
                    "-I",
                    str(import_root),
                    "-I",
                    str(Path.home() / ".local/lib"),
                    str(test_file),
                ],
                cwd=ROOT,
                env=env,
                text=True,
                check=True,
                timeout=10,
            )


if __name__ == "__main__":
    main()
