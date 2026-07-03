#!/usr/bin/env python3
"""System tray end-to-end test.

Runs the real shell on the live niri session with fake StatusNotifierItem
apps, then drives it over quickshell IPC and asserts on IPC state, printed
logs, settings.json persistence, and grim screenshots (icon pixels).

Requires: a running niri session, quickshell, qml6 tooling, grim, PIL,
python-dbus + pygobject. Skips (exit 0) when the environment is missing.
The user's settings.json and any pre-existing quickshell instance are
restored/left alone: the test refuses to run if quickshell already runs.

Artifacts (screenshots, logs) land in $LYINGSHELL_E2E_ARTIFACTS or a temp dir.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SETTINGS = Path.home() / ".config" / "lyingshell" / "settings.json"

# Solid icon colors double as screenshot probes.
APPS = {
    "syncthing": ((0, 120, 215), True),  # pinned by default regex; has menu
    "e2e-alpha": ((16, 160, 16), False),
    "e2e-beta": ((200, 30, 30), False),
}


def skip(reason: str) -> None:
    print(f"SKIP: {reason}")
    sys.exit(0)


def fail(reason: str) -> None:
    print(f"FAIL: {reason}")
    sys.exit(1)


class Shell:
    def __init__(self, artifacts: Path):
        self.artifacts = artifacts
        self.procs: list[subprocess.Popen] = []
        self.settings_backup: bytes | None = None
        self.qs_log = artifacts / "quickshell.log"

    def ipc(self, *args: str) -> str:
        result = subprocess.run(
            ["quickshell", "ipc", "--path", str(ROOT), "call", "tray", *args],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            fail(f"ipc {args} failed: {result.stderr.strip()}")
        return result.stdout.strip()

    def state(self) -> dict:
        return json.loads(self.ipc("state"))

    def spawn(self, cmd: list[str], log: Path) -> subprocess.Popen:
        handle = open(log, "w")
        proc = subprocess.Popen(cmd, stdout=handle, stderr=subprocess.STDOUT, cwd=ROOT)
        self.procs.append(proc)
        return proc

    def cleanup(self) -> None:
        for proc in reversed(self.procs):
            proc.terminate()
        for proc in self.procs:
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
        if self.settings_backup is not None:
            SETTINGS.write_bytes(self.settings_backup)


def wait_for(predicate, timeout: float, what: str):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.25)
    fail(f"timeout waiting for {what}")


def screen_scale(image_width: int) -> float:
    outputs = json.loads(
        subprocess.run(
            ["niri", "msg", "--json", "outputs"], capture_output=True, text=True
        ).stdout
    )
    logical = next(iter(outputs.values()))["logical"]["width"]
    return image_width / logical


def screenshot(artifacts: Path, name: str):
    from PIL import Image

    path = artifacts / f"{name}.png"
    subprocess.run(["grim", path.as_posix()], check=True)
    return Image.open(path)


def color_present(image, region, rgb, tolerance=30) -> bool:
    crop = image.crop(region).convert("RGB")
    return any(
        all(abs(channel - want) <= tolerance for channel, want in zip(pixel, rgb))
        for pixel in crop.getdata()
    )


def assert_popover_under_button(state: dict, when: str) -> None:
    """The popover card must stay centered under the overflow button."""
    button = state["geometry"]["button"]
    card = state["geometry"]["card"]
    button_center = button["x"] + button["width"] / 2
    card_center = card["x"] + card["width"] / 2
    assert abs(button_center - card_center) <= 2, (
        f"popover not under button {when}: "
        f"button center {button_center}, card center {card_center}"
    )
    assert card["y"] >= state["geometry"]["barBottom"], (
        f"popover overlaps bar {when}: card {card}"
    )


def wait_for_color(artifacts, name, region, rgb, timeout=8.0):
    """Re-screenshot until rgb shows up in region (icons load async)."""
    last = None
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        last = screenshot(artifacts, name)
        if color_present(last, region, rgb):
            return last
        time.sleep(0.5)
    fail(f"color {rgb} never appeared in {name} region {region}")


def main() -> None:
    for tool in ("quickshell", "grim", "niri"):
        if shutil.which(tool) is None:
            skip(f"missing {tool}")
    if not os.environ.get("WAYLAND_DISPLAY"):
        skip("no wayland session")
    try:
        import dbus  # noqa: F401
        from PIL import Image  # noqa: F401
    except ImportError as error:
        skip(f"missing python module: {error}")
    if subprocess.run(["pgrep", "-x", "quickshell"], capture_output=True).returncode == 0:
        skip("quickshell already running; stop it before the tray e2e test")

    artifacts = Path(
        os.environ.get("LYINGSHELL_E2E_ARTIFACTS", tempfile.mkdtemp(prefix="tray-e2e-"))
    )
    artifacts.mkdir(parents=True, exist_ok=True)
    print(f"artifacts: {artifacts}")
    shell = Shell(artifacts)

    try:
        # Deterministic pinning default, restored afterwards.
        if SETTINGS.exists():
            shell.settings_backup = SETTINGS.read_bytes()
            data = json.loads(shell.settings_backup)
            data.setdefault("bar", {})["tray"] = {"pinnedRegexes": ["syncthing"]}
            SETTINGS.write_text(json.dumps(data))

        # Icons: solid colors we can find in screenshots.
        from PIL import Image, ImageDraw

        icon_dir = artifacts / "icons"
        icon_dir.mkdir(exist_ok=True)
        for app_id, (rgb, _) in APPS.items():
            icon = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
            ImageDraw.Draw(icon).rounded_rectangle([2, 2, 29, 29], radius=8, fill=rgb + (255,))
            icon.save(icon_dir / f"{app_id}.png")

        for app_id, (_, menu) in APPS.items():
            cmd = [
                sys.executable,
                str(ROOT / "tests" / "e2e" / "fake_tray_app.py"),
                "--id", app_id, "--title", app_id.title(),
                "--icon", app_id, "--icon-path", str(icon_dir),
            ] + (["--menu"] if menu else [])
            shell.spawn(cmd, artifacts / f"fake-{app_id}.log")

        os.environ["LYINGSHELL_TRAY_E2E_DRIVER"] = str(
            ROOT / "tests" / "e2e" / "TrayIpcDriver.qml"
        )
        shell.spawn([str(ROOT / "scripts" / "run.sh")], shell.qs_log)

        # 1. Partition: default regex pins syncthing, the rest overflow.
        def try_state():
            result = subprocess.run(
                ["quickshell", "ipc", "--path", str(ROOT), "call", "tray", "state"],
                capture_output=True, text=True,
            )
            if result.returncode != 0 or not result.stdout.strip():
                return None
            try:
                parsed = json.loads(result.stdout)
            except json.JSONDecodeError:
                return None
            if {"e2e-alpha", "e2e-beta"} <= set(parsed["overflow"]):
                return parsed
            return None

        state = wait_for(try_state, timeout=30, what="tray items to register")
        assert "syncthing" in state["pinned"], f"syncthing not pinned: {state}"
        print("OK partition:", state["pinned"], "/", state["overflow"])

        # 2. Pinned icon is actually rendered in the bar strip (right zone
        # only: keeps wallpaper pixels out of the probe). Icons load async,
        # so the probe re-screenshots until the color shows up.
        probe = screenshot(artifacts, "bar-collapsed")
        scale = screen_scale(probe.width)
        bar_strip = (int(probe.width * 0.75), 0, probe.width, int(state["geometry"]["barBottom"] * scale) + 8)
        image = wait_for_color(artifacts, "bar-collapsed", bar_strip, APPS["syncthing"][0])
        assert not color_present(image, bar_strip, APPS["e2e-alpha"][0]), "overflow icon leaked into bar"
        print("OK screenshot: pinned icon visible, overflow hidden")

        # 3. Popover opens below the bar and shows overflow icons.
        shell.ipc("openPopover")
        time.sleep(0.8)
        state = shell.state()
        assert state["popoverOpen"], "popover did not open"
        assert_popover_under_button(state, "at first open after startup")
        card = state["geometry"]["card"]
        card_region = tuple(int(v * scale) for v in (card["x"], card["y"], card["x"] + card["width"], card["y"] + card["height"]))
        image = wait_for_color(artifacts, "popover-open", card_region, APPS["e2e-alpha"][0])
        assert color_present(image, card_region, APPS["e2e-beta"][0]), "beta icon not in popover"
        print("OK popover: icons visible in card")

        # 4. Activate reaches the app over dbus.
        shell.ipc("activate", "e2e-alpha")
        wait_for(
            lambda: "Activate" in (artifacts / "fake-e2e-alpha.log").read_text(),
            timeout=5, what="Activate to reach fake app",
        )
        print("OK activate: dbus round trip")

        # 5. Context menu: dbusmenu layout is fetched and opened.
        shell.ipc("menu", "syncthing")
        wait_for(
            lambda: "MenuGetLayout" in (artifacts / "fake-syncthing.log").read_text(),
            timeout=5, what="menu layout fetch",
        )
        print("OK menu: dbusmenu layout fetched")

        # 6. Drag pin: alpha into the pinned row, caret index honored.
        state = shell.state()
        row = state["geometry"]["row"]
        target = shell.ipc("dragTo", "e2e-alpha", str(int(row["x"] + 2)), str(int(state["geometry"]["barBottom"] / 2)))
        assert json.loads(target)["dropZone"] == "pinned", f"expected pinned zone: {target}"
        screenshot(artifacts, "drag-pin")  # ghost + caret + keep badge
        shell.ipc("drop")
        time.sleep(0.3)  # let the pinned row relayout settle
        state = shell.state()
        assert state["pinned"][0] == "e2e-alpha", f"alpha not pinned first: {state['pinned']}"
        # The button shifted left (pinned row grew); the popover must follow.
        assert state["popoverOpen"], "popover closed after pin drag"
        assert_popover_under_button(state, "after drag pin")
        screenshot(artifacts, "popover-after-pin")

        def saved_regexes():
            return json.loads(SETTINGS.read_text())["bar"]["tray"]["pinnedRegexes"]

        # The adapter write-back is async; poll the file.
        wait_for(
            lambda: any(r in saved_regexes() for r in ("^e2e\\-alpha$", "^e2e-alpha$")),
            timeout=10, what="pin regex to persist",
        )
        print("OK drag pin: state + settings.json persisted")

        # 7. Drag unpin: syncthing into the popover card (fresh geometry —
        # the card reflowed after the pin).
        card = shell.state()["geometry"]["card"]
        target = shell.ipc("dragTo", "syncthing", str(int(card["x"] + card["width"] / 2)), str(int(card["y"] + card["height"] / 2)))
        assert json.loads(target)["dropZone"] == "overflow", f"expected overflow zone: {target}"
        shell.ipc("drop")
        time.sleep(0.3)  # let the pinned row relayout settle
        state = shell.state()
        assert "syncthing" in state["overflow"], f"syncthing not unpinned: {state}"
        assert_popover_under_button(state, "after drag unpin")
        wait_for(
            lambda: "syncthing" not in saved_regexes(),
            timeout=10, what="unpin regex removal to persist",
        )
        print("OK drag unpin: state + settings.json persisted")

        # 7b. Drag reorder inside the popover: last overflow item to the grid
        # head; order persists to bar.tray.overflowOrder.
        state = shell.state()
        last = state["overflow"][-1]
        card = state["geometry"]["card"]
        target = shell.ipc("dragTo", last, str(int(card["x"] + 10)), str(int(card["y"] + 10)))
        parsed = json.loads(target)
        assert parsed["dropZone"] == "overflow" and parsed["dropIndex"] == 0, f"expected overflow head: {target}"
        shell.ipc("drop")
        state = shell.state()
        assert state["overflow"][0] == last, f"reorder did not move {last} to head: {state}"
        wait_for(
            lambda: json.loads(SETTINGS.read_text())["bar"]["tray"].get("overflowOrder", [])[:1] == [last],
            timeout=10, what="overflow order to persist",
        )
        print("OK drag reorder: popover order + settings.json persisted")

        # 8. Blocked drag is a no-op.
        before = shell.state()["pinnedRegexes"]
        target = shell.ipc("dragTo", "e2e-beta", "500", "500")
        assert json.loads(target)["dropZone"] == "blocked", f"expected blocked: {target}"
        shell.ipc("drop")
        assert shell.state()["pinnedRegexes"] == before, "blocked drop mutated regexes"
        print("OK blocked drag: no-op")

        # 9. Popover closes; logs carry the lifecycle.
        shell.ipc("closePopover")
        time.sleep(0.6)
        assert not shell.state()["popoverOpen"], "popover did not close"
        log_text = shell.qs_log.read_text()
        for needle in ("[Tray] popover open", "[Tray] popover closed", "[Tray] activate e2e-alpha", "[Tray] pin e2e-alpha", "[Tray] unpin syncthing", "[Tray] reorder"):
            assert needle in log_text, f"missing log line: {needle}"
        print("OK logs: lifecycle lines present")

        print("PASS: tray e2e")
    finally:
        shell.cleanup()


if __name__ == "__main__":
    main()
