#!/usr/bin/env python3
"""Exercise Workspaces focus and wheel paths through opt-in Quickshell IPC."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT
TARGET_PATTERN = re.compile(r"^target (workspaces-.+)$", re.MULTILINE)
ERROR_PATTERN = re.compile(r"Binding loop|WARN scene|ERR|ERROR|TypeError|ReferenceError")
LIVE_ENV = "LYINGSHELL_WORKSPACES_IPC_LIVE"


def tool_available(name: str) -> bool:
    return shutil.which(name) is not None


def ipc_call(target: str, function_name: str, *args: object) -> str:
    result = subprocess.run(
        [
            "quickshell",
            "ipc",
            "--path",
            str(CONFIG_PATH),
            "call",
            target,
            function_name,
            *[str(arg) for arg in args],
        ],
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout.strip()


def workspace_ids_for(target: str) -> list[str]:
    return [value for value in ipc_call(target, "workspaceIds").split(",") if value]


def wait_for_target(*, minimum_workspaces: int, require_focused: bool = False) -> str:
    deadline = time.monotonic() + 8
    last_output = ""

    while time.monotonic() < deadline:
        result = subprocess.run(
            ["quickshell", "ipc", "--path", str(CONFIG_PATH), "show"],
            text=True,
            capture_output=True,
            check=False,
        )
        last_output = result.stdout + result.stderr
        targets = TARGET_PATTERN.findall(result.stdout)
        for target in targets:
            try:
                workspace_ids = workspace_ids_for(target)
                focused_workspace_id = ipc_call(target, "focusedWorkspaceId")
            except subprocess.CalledProcessError:
                continue

            if len(workspace_ids) < minimum_workspaces:
                continue
            if require_focused and len(focused_workspace_id) == 0:
                continue
            return target
        time.sleep(0.2)

    raise AssertionError(f"Workspaces IPC target was not registered:\n{last_output}")


def wait_for_active(target: str, workspace_id: str) -> None:
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        if ipc_call(target, "activeWorkspaceId") == workspace_id:
            return
        time.sleep(0.1)
    raise AssertionError(f"workspace {workspace_id} did not become active")


def base_environment() -> dict[str, str]:
    env = os.environ.copy()
    import_path = f"{Path.home() / '.local/lib'}{os.pathsep}{env.get('QML_IMPORT_PATH', '')}".rstrip(os.pathsep)
    env["QML_IMPORT_PATH"] = import_path
    env["QML2_IMPORT_PATH"] = import_path
    return env


def create_test_config(config_dir: Path) -> Path:
    for name in ("Commons", "Modules", "Services", "tests"):
        os.symlink(ROOT / name, config_dir / name, target_is_directory=True)

    shell_path = config_dir / "shell.qml"
    shell_path.write_text(
        'import "./tests/qml"\n\nWorkspacesIpcShell {}\n',
        encoding="utf-8",
    )
    return shell_path


def run_with_shell(env: dict[str, str], exercise: Callable[[], None]) -> None:
    global CONFIG_PATH

    with tempfile.TemporaryDirectory(prefix="lyingshell-workspaces-ipc-home-") as temp_home:
        env["HOME"] = temp_home
        log_path = Path(temp_home) / "quickshell.log"
        with tempfile.TemporaryDirectory(prefix="lyingshell-workspaces-ipc-config-") as temp_config:
            previous_config_path = CONFIG_PATH
            CONFIG_PATH = create_test_config(Path(temp_config))

            with log_path.open("w", encoding="utf-8") as log:
                process = subprocess.Popen(
                    ["quickshell", "--path", str(CONFIG_PATH), "--no-duplicate"],
                    env=env,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    text=True,
                )

                try:
                    exercise()
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=4)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=4)
                    CONFIG_PATH = previous_config_path

        log_text = log_path.read_text(encoding="utf-8")
        assert not ERROR_PATTERN.search(log_text), log_text


def run_mock_interaction() -> None:
    env = base_environment()
    env.pop(LIVE_ENV, None)

    def exercise() -> None:
        target = wait_for_target(minimum_workspaces=3)
        workspace_ids = workspace_ids_for(target)

        assert ipc_call(target, "activeWorkspaceId") == workspace_ids[1]
        assert ipc_call(target, "wheelTarget", -120) == workspace_ids[2]
        assert ipc_call(target, "wheel", -120) == workspace_ids[2]
        wait_for_active(target, workspace_ids[2])

        assert ipc_call(target, "focus", workspace_ids[0]) == "true"
        wait_for_active(target, workspace_ids[0])
        assert ipc_call(target, "wheelTarget", 120) == workspace_ids[-1]

    run_with_shell(env, exercise)


def run_live_interaction() -> None:
    if not os.environ.get("NIRI_SOCKET"):
        print("SKIP: live Workspaces IPC test requires NIRI_SOCKET")
        return

    env = base_environment()

    def exercise() -> None:
        target = wait_for_target(minimum_workspaces=2, require_focused=True)
        workspace_ids = workspace_ids_for(target)
        original_active_id = ipc_call(target, "activeWorkspaceId")
        original_focused_id = ipc_call(target, "focusedWorkspaceId")
        restore_id = original_focused_id if original_focused_id in workspace_ids else original_active_id
        next_id = next(workspace_id for workspace_id in workspace_ids if workspace_id != original_active_id)

        try:
            assert ipc_call(target, "focus", next_id) == "true"
            wait_for_active(target, next_id)

            wheel_target_id = ipc_call(target, "wheelTarget", 120)
            assert len(wheel_target_id) > 0
            assert ipc_call(target, "wheel", 120) == wheel_target_id
            wait_for_active(target, wheel_target_id)
        finally:
            if len(restore_id) > 0:
                ipc_call(target, "focus", restore_id)
                wait_for_active(target, restore_id)

    run_with_shell(env, exercise)


def main() -> None:
    if not os.environ.get("WAYLAND_DISPLAY") or not tool_available("quickshell"):
        print("SKIP: Workspaces IPC test requires Wayland and quickshell")
        return

    if os.environ.get(LIVE_ENV) == "1":
        run_live_interaction()
    else:
        run_mock_interaction()


if __name__ == "__main__":
    main()
