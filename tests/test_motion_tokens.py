#!/usr/bin/env python3
"""M3 Expressive motion-token and spring-integrator contract.

Material/Motion.js carries the official AndroidX physics, its QML Bezier
fallbacks track a from-rest response, and interactive callers can retain
velocity through a target change with the analytic integrator.
"""

from __future__ import annotations

import json
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOTION_JS = ROOT / "Material" / "Motion.js"

# androidx compose material3 tokens/ExpressiveMotionTokens.kt
OFFICIAL = {
    "spatialFast": (0.6, 800.0),
    "spatialDefault": (0.8, 380.0),
    "spatialSlow": (0.8, 200.0),
    "effectsFast": (1.0, 3800.0),
    "effectsDefault": (1.0, 1600.0),
    "effectsSlow": (1.0, 800.0),
}

TOL = 0.01  # settle envelope used by the generator
FIT_TOL = 0.015  # max bezier-vs-analytic deviation

NODE_SCRIPT = r"""
const fs = require("fs");
const vm = require("vm");
const source = fs.readFileSync(process.argv[2], "utf8")
    .split(/\r?\n/)
    .filter(line => !/^\s*\.(pragma|import)\b/.test(line))
    .join("\n");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);
process.stdout.write(JSON.stringify({
    spatialFast: context.spatialFast,
    spatialDefault: context.spatialDefault,
    spatialSlow: context.spatialSlow,
    effectsFast: context.effectsFast,
    effectsDefault: context.effectsDefault,
    effectsSlow: context.effectsSlow,
    integrated: context.stepSpring(0, 0, 1, context.spatialSlow, 0.137),
    interrupted: (() => {
        const outward = context.stepSpring(0, 0, 1, context.spatialSlow, 0.08);
        const retargeted = context.stepSpring(outward.value, outward.velocity, 0, context.spatialSlow, 0.001);
        return { outward, retargeted };
    })(),
}));
"""


def response(zeta: float, k: float):
    """Unit-mass damped spring step response: (y(t), settle_time)."""
    w0 = math.sqrt(k)
    if zeta >= 1.0:
        def y(t):
            return 1.0 - (1.0 + w0 * t) * math.exp(-w0 * t)

        lo, hi = 0.0, 50.0
        for _ in range(80):
            mid = (lo + hi) / 2
            if (1.0 + mid) * math.exp(-mid) > TOL:
                lo = mid
            else:
                hi = mid
        return y, lo / w0

    a = zeta * w0
    wd = w0 * math.sqrt(1.0 - zeta * zeta)

    def y(t):
        return 1.0 - math.exp(-a * t) * (math.cos(wd * t) + (a / wd) * math.sin(wd * t))

    env = math.sqrt(1.0 + (a / wd) ** 2)
    return y, math.log(env / TOL) / a


def bezier_y_at(curve: list[float], x: float) -> float:
    """Evaluate the piecewise BezierSpline (implicit (0,0) start) at x."""
    pts = [(0.0, 0.0)]
    for i in range(0, len(curve), 2):
        pts.append((curve[i], curve[i + 1]))
    # segments of 3 points each after the start
    for s in range(0, len(pts) - 1, 3):
        p0, p1, p2, p3 = pts[s], pts[s + 1], pts[s + 2], pts[s + 3]
        if not (p0[0] - 1e-9 <= x <= p3[0] + 1e-9):
            continue
        lo, hi = 0.0, 1.0
        for _ in range(60):
            mid = (lo + hi) / 2
            bx = ((1 - mid) ** 3 * p0[0] + 3 * (1 - mid) ** 2 * mid * p1[0]
                  + 3 * (1 - mid) * mid ** 2 * p2[0] + mid ** 3 * p3[0])
            if bx < x:
                lo = mid
            else:
                hi = mid
        t = (lo + hi) / 2
        return ((1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1]
                + 3 * (1 - t) * t ** 2 * p2[1] + t ** 3 * p3[1])
    raise AssertionError(f"x={x} outside curve domain")


def main() -> None:
    result = subprocess.run(
        ["node", "-", str(MOTION_JS)],
        input=NODE_SCRIPT,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr.strip()
    payload = json.loads(result.stdout)
    integrated = payload.pop("integrated")
    interrupted = payload.pop("interrupted")
    tokens = payload

    assert set(tokens) == set(OFFICIAL), "token set drifted"

    for name, (zeta, k) in OFFICIAL.items():
        tok = tokens[name]
        assert tok["damping"] == zeta, f"{name}: damping {tok['damping']} != {zeta}"
        assert tok["stiffness"] == k, f"{name}: stiffness {tok['stiffness']} != {k}"

        y, settle = response(zeta, k)
        assert abs(tok["duration"] - settle * 1000) <= 1, (
            f"{name}: duration {tok['duration']} vs analytic {settle * 1000:.1f}"
        )

        curve = tok["curve"]
        assert len(curve) % 6 == 0, f"{name}: curve must be whole cubic segments"
        assert curve[-2] == 1.0 and curve[-1] == 1.0, f"{name}: must settle at (1,1)"

        # BezierSpline needs monotone x across on-curve and control points.
        xs = curve[0::2]
        assert all(b >= a for a, b in zip(xs, xs[1:])), f"{name}: x not monotone"

        maxerr = max(
            abs(bezier_y_at(curve, j / 200) - y(j / 200 * settle))
            for j in range(1, 200)
        )
        assert maxerr < FIT_TOL, f"{name}: bezier fit off by {maxerr:.4f}"

        peak = max(bezier_y_at(curve, j / 400) for j in range(1, 401))
        if name.startswith("effects"):
            # Critically damped: never overshoots.
            assert peak <= 1.0 + 1e-6, f"{name}: effects curve overshoots ({peak:.4f})"
        elif name == "spatialFast":
            # zeta 0.6 => exp(-pi*zeta/sqrt(1-zeta^2)) ~ 9.5% overshoot.
            assert 1.05 < peak < 1.12, f"{name}: expected ~9.5% overshoot, got {peak:.4f}"

    # The closed-form step must match the same official spring exactly.
    exact, _ = response(*OFFICIAL["spatialSlow"])
    assert abs(integrated["value"] - exact(0.137)) < 1e-12

    # Retargeting carries positive outward velocity into the first return
    # frame. A restarted duration/easing curve would reset that velocity and
    # reverse immediately, which is the artificial hover bounce this API
    # exists to prevent.
    outward = interrupted["outward"]
    retargeted = interrupted["retargeted"]
    assert outward["velocity"] > 0
    assert retargeted["value"] > outward["value"]
    assert retargeted["velocity"] > 0

    print("OK: motion token contract holds")


if __name__ == "__main__":
    main()
