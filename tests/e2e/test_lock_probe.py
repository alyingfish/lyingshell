#!/usr/bin/env python3
"""Lock-screen reachability probe. Needs a live session; NEVER locks it.

Two things this proves without putting the screen in a state you have to type
your way out of:

  1. The whole lock module tree constructs under the real Quickshell runtime —
     WlSessionLock, the scene, the fragment-shader avatar, the quick-settings
     pill, and the lock's own palette. QML load errors in that tree would
     otherwise only show up at the moment you lock, which is the worst possible
     time to find them.
  2. PAM is reachable: the shipped service resolves, a session starts for the
     current user, and the conversation reaches the "Password: " prompt the
     unlock flow answers. The probe aborts there — it never sends a response,
     so nothing is authenticated and no failure counter moves.

The probe QML has to sit at the repository root while it runs: Quickshell roots
the `qs.*` import namespace at the directory of the file it was given, so a
probe under tests/ could not import qs.Services. It is written and removed here.

Usage: python3 tests/e2e/test_lock_probe.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROBE = ROOT / "_lock_probe.qml"

PROBE_QML = """//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Services
import qs.Modules.Lock

// Written by tests/e2e/test_lock_probe.py and removed again. Loads the lock
// module and starts one PAM conversation WITHOUT ever locking the session.
ShellRoot {
    id: root

    // Inert: Lock.locked is false, so no surface is ever created.
    LockScreen {}

    // Construct the scene tree off-window, so a construction error surfaces
    // here rather than at lock time.
    Scope {
        LockScene {
            width: 1920
            height: 1080
            interactive: false
        }
    }

    PamContext {
        id: probe

        config: "lyingshell"
        configDirectory: Quickshell.shellDir + "/assets/pam.d"

        onPamMessage: {
            console.info("PROBE pam message=" + JSON.stringify(message) + " responseRequired=" + responseRequired);
            // Never answer: this is a reachability check, not an attempt.
            abort();
            quitTimer.restart();
        }
        onCompleted: function (result) {
            console.info("PROBE completed=" + PamResult.toString(result));
            quitTimer.restart();
        }
        onError: function (err) {
            console.warn("PROBE error=" + PamError.toString(err));
            quitTimer.restart();
        }
    }

    Timer {
        id: quitTimer
        interval: 250
        onTriggered: Qt.exit(0)
    }

    Timer {
        interval: 8000
        running: true
        onTriggered: {
            console.warn("PROBE timeout");
            Qt.exit(2);
        }
    }

    Component.onCompleted: {
        console.info("PROBE loaded locked=" + Lock.locked + " phase=" + Lock.phase + " user=" + Lock.displayName);
        console.info("PROBE pam.start=" + probe.start());
    }
}
"""


def main() -> None:
    if shutil.which("quickshell") is None:
        print("SKIP: lock probe requires quickshell")
        return
    if not os.environ.get("WAYLAND_DISPLAY"):
        print("SKIP: lock probe requires a live Wayland session")
        return

    env = os.environ.copy()
    env["QML_IMPORT_PATH"] = os.pathsep.join(
        path
        for path in (str(Path.home() / ".local/lib"), env.get("QML_IMPORT_PATH", ""))
        if path
    )

    PROBE.write_text(PROBE_QML, encoding="utf-8")
    try:
        result = subprocess.run(
            ["quickshell", "-p", str(PROBE)],
            cwd=ROOT,
            env=env,
            text=True,
            timeout=60,
            capture_output=True,
        )
    finally:
        PROBE.unlink(missing_ok=True)

    output = result.stdout + result.stderr
    if "Failed to load configuration" in output or "Type LockScreen unavailable" in output:
        print(output)
        sys.exit("FAIL: the lock module did not load")
    assert "PROBE loaded locked=false" in output, f"probe never reached Component.onCompleted:\n{output}"
    assert "PROBE pam.start=true" in output, f"PamContext.start() failed:\n{output}"
    assert "responseRequired=true" in output, f"PAM never asked for a password:\n{output}"

    print("OK: lock module loads and PAM reaches the password prompt")


if __name__ == "__main__":
    main()
