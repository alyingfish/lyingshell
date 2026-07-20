#!/usr/bin/env python3
"""Shell IPC contract test: the ShellIpc command layer, its typed handler
functions, the per-screen quick-settings registration, and the ctl.sh CLI."""

from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL_IPC = ROOT / "Services" / "ShellIpc.qml"
QS_BUTTON = ROOT / "Modules" / "Bar" / "Widgets" / "QuickSettingsButton.qml"
BAR_QML = ROOT / "Modules" / "Bar" / "Bar.qml"
CTL_SH = ROOT / "scripts" / "ctl.sh"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> None:
    # --- service shape -----------------------------------------------------
    ipc = read(SHELL_IPC)
    assert ipc.startswith("pragma Singleton"), "ShellIpc must be a singleton"
    assert 'target: "panels"' in ipc and 'target: "tools"' in ipc, (
        "command namespaces are `panels` and `tools`"
    )

    # Handler functions must be fully typed or qs silently drops them.
    for signature in [
        r'function toggle\(name: string\): string',
        r'function open\(name: string\): string',
        r'function close\(name: string\): string',
        r'function list\(\): string',
        r'function colorPicker\(\): string',
    ]:
        assert re.search(signature, ipc), f"missing typed handler: {signature}"

    # Routing goes through the focused output, read from the Niri singleton.
    assert "import qs.Services.Niri" in ipc
    assert "Niri.focusedOutputName" in ipc, "panel routing must follow focus"

    # --- per-screen registration ------------------------------------------
    button = read(QS_BUTTON)
    assert 'ShellIpc.registerPanel("quicksettings", screenName' in button, (
        "quick-settings must register with the command layer"
    )
    assert 'ShellIpc.unregisterPanel("quicksettings"' in button, (
        "registration must be released on teardown"
    )
    for api in ['"isOpen"', '"setOpen"', '"pickColor"']:
        assert api in button, f"registered api must provide {api}"
    assert "menu.panel.beginColorPick()" in button, (
        "the IPC pick must reuse the panel's full pick flow"
    )

    bar = read(BAR_QML)
    assert re.search(r"screenName:\s*root\.screen", bar), (
        "Bar must feed the output name into QuickSettingsButton"
    )

    # --- CLI wrapper -------------------------------------------------------
    ctl = read(CTL_SH)
    assert os.access(CTL_SH, os.X_OK), "ctl.sh must be executable"
    assert re.search(r'ipc\s+--path\s+"\$repo_dir"', ctl), (
        "ctl.sh must address the instance by shell path"
    )

    print("OK: shell IPC contract holds")


if __name__ == "__main__":
    main()
