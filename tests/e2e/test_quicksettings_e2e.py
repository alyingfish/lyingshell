#!/usr/bin/env python3
"""Quick-settings end-to-end test.

Runs the real shell on the live niri session and drives the quick-settings
pill/panel over quickshell IPC: panel open/close geometry, screenshot pixel
probe, and the system functions (volume/mute via wpctl, brightness via
brightnessctl, night light via wlsunset, dark style via gsettings +
settings.json, do-not-disturb via makoctl). Every system state it touches is
saved and restored.

Requires: a running niri session, quickshell, grim, PIL. Skips (exit 0) when
the environment is missing. Refuses to run if quickshell already runs.

Artifacts land in $LYINGSHELL_E2E_ARTIFACTS or a temp dir.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SETTINGS = Path.home() / ".config" / "lyingshell" / "settings.json"


def skip(reason: str) -> None:
    print(f"SKIP: {reason}")
    sys.exit(0)


def fail(reason: str) -> None:
    print(f"FAIL: {reason}")
    sys.exit(1)


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=15, **kwargs)


def wait_for(predicate, timeout: float, what: str):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.25)
    fail(f"timeout waiting for {what}")


class Shell:
    def __init__(self, artifacts: Path):
        self.artifacts = artifacts
        self.proc: subprocess.Popen | None = None
        self.settings_backup: bytes | None = None

    def ipc(self, *args: str) -> str:
        result = run(["quickshell", "ipc", "--path", str(ROOT), "call", "quicksettings", *args])
        if result.returncode != 0:
            fail(f"ipc {args} failed: {result.stderr.strip()}")
        return result.stdout.strip()

    def state(self) -> dict:
        return json.loads(self.ipc("state"))

    def start(self) -> None:
        env = os.environ.copy()
        env["LYINGSHELL_QS_E2E_DRIVER"] = str(ROOT / "tests" / "e2e" / "QuickSettingsIpcDriver.qml")
        log = open(self.artifacts / "quickshell.log", "w")
        self.proc = subprocess.Popen(
            [str(ROOT / "scripts" / "run.sh")],
            stdout=log,
            stderr=subprocess.STDOUT,
            env=env,
            cwd=ROOT,
        )
        wait_for(lambda: self._ipc_ready(), 20, "quick settings IPC")

    def _ipc_ready(self) -> bool:
        result = run(["quickshell", "ipc", "--path", str(ROOT), "call", "quicksettings", "state"])
        return result.returncode == 0 and result.stdout.strip().startswith("{")

    def cleanup(self) -> None:
        if self.proc is not None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        if self.settings_backup is not None:
            SETTINGS.write_bytes(self.settings_backup)


def screenshot(artifacts: Path, name: str):
    from PIL import Image

    path = artifacts / f"{name}.png"
    subprocess.run(["grim", path.as_posix()], check=True)
    return Image.open(path)


def wpctl_volume() -> tuple[float, bool]:
    out = run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]).stdout
    match = re.search(r"Volume:\s*([0-9.]+)", out)
    if not match:
        fail(f"cannot parse wpctl output: {out!r}")
    return float(match.group(1)), "[MUTED]" in out


def main() -> None:
    for tool in ("quickshell", "grim", "niri", "wpctl"):
        if shutil.which(tool) is None:
            skip(f"missing {tool}")
    if not os.environ.get("WAYLAND_DISPLAY"):
        skip("no wayland session")
    try:
        from PIL import Image  # noqa: F401
    except ImportError as error:
        skip(f"missing python module: {error}")
    if run(["pgrep", "-x", "quickshell"]).returncode == 0:
        skip("quickshell already running; stop it before the quick-settings e2e test")

    artifacts = Path(os.environ.get("LYINGSHELL_E2E_ARTIFACTS", tempfile.mkdtemp(prefix="qs-e2e-")))
    artifacts.mkdir(parents=True, exist_ok=True)
    print(f"artifacts: {artifacts}")

    shell = Shell(artifacts)
    if SETTINGS.exists():
        shell.settings_backup = SETTINGS.read_bytes()

    volume0, muted0 = None, None
    try:
        shell.start()

        # --- state sanity ---------------------------------------------------
        state = shell.state()
        for section in ("audio", "brightness", "network", "bluetooth", "powerMode",
                        "nightLight", "airplane", "doNotDisturb", "battery", "geometry"):
            assert section in state, f"state missing {section}"
        assert state["panelOpen"] is False

        # --- panel open geometry + pixel probe --------------------------------
        closed_shot = screenshot(artifacts, "panel-closed")
        shell.ipc("openPanel")
        state = wait_for(
            lambda: (s := shell.state())["panelOpen"] and s["expanded"] and s or None,
            5, "panel to open",
        )
        time.sleep(0.8)  # settle the open/height animations before geometry asserts
        state = shell.state()
        geometry = state["geometry"]
        card = geometry["card"]
        pill = geometry["pill"]
        assert card["y"] >= geometry["barBottom"], f"card overlaps bar: {card}"
        assert card["width"] > 300 and card["height"] > 200, f"card too small: {card}"
        # Right-aligned near the pill, clamped to the screen.
        assert card["x"] + card["width"] <= pill["right"] + 16, (
            f"card not anchored to pill: card {card} pill {pill}"
        )

        open_shot = screenshot(artifacts, "panel-open")
        # Probe the card center: it must differ from the closed screenshot.
        # The card is clamped near the screen's right edge, so logical screen
        # width ≈ card right edge + margin; that gives the physical scale.
        logical_width = max(card["x"] + card["width"] + 8, pill["right"])
        ratio = open_shot.width / logical_width
        cx = int((card["x"] + card["width"] / 2) * ratio)
        cy = int((card["y"] + card["height"] / 2) * ratio)
        if not (0 <= cx < open_shot.width and 0 <= cy < open_shot.height):
            fail(f"card center probe out of bounds: {cx},{cy}")
        if open_shot.getpixel((cx, cy)) == closed_shot.getpixel((cx, cy)):
            fail("panel card not visible in screenshot (probe pixel unchanged)")

        # --- hover-wheel page flip over tiles and the gap between them --------
        if state["pageCount"] > 1:
            assert state["page"] == 0, f"panel must open on page 0, got {state['page']}"
            shell.ipc("wheelTiles", "-120")  # wheel down over a tile = next page
            wait_for(lambda: shell.state()["page"] == 1, 5, "wheel over tile flips forward")
            time.sleep(0.5)
            screenshot(artifacts, "panel-page2")
            shell.ipc("wheelTileGap", "120")  # wheel up over the empty gap = back
            wait_for(lambda: shell.state()["page"] == 0, 5, "wheel over gap flips back")

        # --- volume + mute (wpctl round-trip) ---------------------------------
        if state["audio"]["hasSink"]:
            volume0, muted0 = wpctl_volume()
            shell.ipc("setVolume", "0.37")
            wait_for(lambda: abs(wpctl_volume()[0] - 0.37) < 0.02, 5, "volume 0.37")
            shell.ipc("toggleMuted")
            wait_for(lambda: wpctl_volume()[1] is not muted0, 5, "mute toggled")
            shell.ipc("toggleMuted")
            wait_for(lambda: wpctl_volume()[1] is muted0, 5, "mute restored")

            # Hover-wheel on the volume row: one notch = a 5% step.
            shell.ipc("setVolume", "0.50")
            wait_for(lambda: abs(wpctl_volume()[0] - 0.50) < 0.02, 5, "volume 0.5")
            shell.ipc("wheelVolume", "120")  # wheel up = +5%
            wait_for(lambda: abs(wpctl_volume()[0] - 0.55) < 0.02, 5, "wheel volume +5%")
            shell.ipc("wheelVolume", "-120")  # wheel down = -5%
            wait_for(lambda: abs(wpctl_volume()[0] - 0.50) < 0.02, 5, "wheel volume -5%")

        # --- brightness (hardware round-trip) ---------------------------------
        if state["brightness"]["available"] and shutil.which("brightnessctl"):
            before = run(["brightnessctl", "-m", "-c", "backlight"]).stdout
            percent0 = state["brightness"]["percent"]
            target = 0.5 if abs(percent0 - 0.5) > 0.05 else 0.6
            shell.ipc("setBrightness", str(target))

            def brightness_moved() -> bool:
                out = run(["brightnessctl", "-m", "-c", "backlight"]).stdout
                match = re.search(r",(\d+)%,", out)
                return bool(match) and abs(int(match.group(1)) / 100 - target) <= 0.02

            wait_for(brightness_moved, 5, f"brightness {target}")
            shell.ipc("setBrightness", str(percent0))
            print(f"brightness restored toward {percent0} (was: {before.strip()})")

        # --- night light (wlsunset lifecycle) -----------------------------------
        if shutil.which("wlsunset"):
            assert shell.state()["nightLight"]["enabled"] is False, "night light should start off"
            shell.ipc("toggleNightLight")
            wait_for(lambda: run(["pgrep", "-x", "wlsunset"]).returncode == 0, 8, "wlsunset start")
            wait_for(lambda: shell.state()["nightLight"]["active"], 5, "night light active")
            shell.ipc("toggleNightLight")
            wait_for(lambda: run(["pgrep", "-x", "wlsunset"]).returncode != 0, 8, "wlsunset stop")

        # --- dark style (gsettings + settings.json round-trip) -------------------
        scheme0 = run(["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]).stdout.strip()
        dark0 = shell.state()["darkStyle"]
        shell.ipc("toggleDarkStyle")
        wait_for(lambda: shell.state()["darkStyle"] is not dark0, 5, "dark style flip")
        wait_for(
            lambda: json.loads(SETTINGS.read_text())["theme"]["mode"] == ("light" if dark0 else "dark"),
            5, "settings.json theme.mode write",
        )
        wait_for(
            lambda: run(["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]).stdout.strip() != scheme0,
            8, "gsettings color-scheme push",
        )
        time.sleep(1.0)
        screenshot(artifacts, "panel-toggled-style")
        shell.ipc("toggleDarkStyle")
        wait_for(lambda: shell.state()["darkStyle"] is dark0, 5, "dark style restore")
        wait_for(
            lambda: run(["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]).stdout.strip() == scheme0,
            8, "gsettings color-scheme restore",
        )

        # --- do not disturb (makoctl round-trip) ---------------------------------
        if shell.state()["doNotDisturb"]["available"]:
            shell.ipc("toggleDoNotDisturb")
            wait_for(
                lambda: "do-not-disturb" in run(["makoctl", "mode"]).stdout.split(),
                5, "mako do-not-disturb mode",
            )
            shell.ipc("toggleDoNotDisturb")
            wait_for(
                lambda: "do-not-disturb" not in run(["makoctl", "mode"]).stdout.split(),
                5, "mako mode restore",
            )

        # --- detail pages keep the main-view dimensions ------------------------
        main_height = shell.state()["geometry"]["card"]["height"]
        for detail in ("wifi", "bluetooth", "output"):
            shell.ipc("setDetail", detail)
            wait_for(lambda d=detail: shell.state()["detail"] == d, 5, f"detail {detail!r}")
            time.sleep(0.6)  # settle any height animation before measuring
            card = shell.state()["geometry"]["card"]
            assert abs(card["height"] - main_height) < 2, (
                f"{detail} detail resized the panel: {card['height']} vs main {main_height}"
            )
            screenshot(artifacts, f"panel-detail-{detail}")
            if detail == "wifi":
                # Overlong list scrolls inside the fixed-height card; catch
                # the MD scrollbar while the flick is still settling.
                for _ in range(3):
                    shell.ipc("wheelDetail", "-120")
                time.sleep(0.15)
                screenshot(artifacts, "panel-detail-wifi-scrolled")
        shell.ipc("setDetail", "")
        wait_for(lambda: shell.state()["detail"] == "", 5, "back to main view")

        # --- close -------------------------------------------------------------------
        shell.ipc("closePanel")
        wait_for(lambda: shell.state()["panelOpen"] is False, 5, "panel close")
        wait_for(lambda: shell.state()["expanded"] is False, 5, "collapse after animation")

        print("OK: quick-settings e2e passed")
    finally:
        if volume0 is not None:
            run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", str(volume0)])
            run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1" if muted0 else "0"])
        shell.cleanup()


if __name__ == "__main__":
    main()
