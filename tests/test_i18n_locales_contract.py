#!/usr/bin/env python3
"""Locale bundles stay parallel and merge-friendly.

Every visible string ships in both bundles (en is the reference), and keys
are alphabetically sorted at every nesting level so parallel branches insert
translations at different lines instead of conflicting at the tail.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ROOT / "Commons" / "I18n" / "locales"
EN = LOCALES / "en.json"
ZH_CN = LOCALES / "zh-CN.json"


def key_paths(node: dict, prefix: str = "") -> set[str]:
    paths: set[str] = set()
    for key, value in node.items():
        path = f"{prefix}.{key}" if prefix else key
        paths.add(path)
        if isinstance(value, dict):
            paths |= key_paths(value, path)
    return paths


def unsorted_maps(node: dict, prefix: str = "") -> list[str]:
    offenders: list[str] = []
    keys = list(node.keys())
    if keys != sorted(keys):
        offenders.append(prefix or "<root>")
    for key, value in node.items():
        if isinstance(value, dict):
            offenders += unsorted_maps(value, f"{prefix}.{key}" if prefix else key)
    return offenders


def main() -> None:
    bundles = {}
    for path in (EN, ZH_CN):
        assert path.is_file(), f"missing locale bundle: {path}"
        bundles[path.name] = json.loads(path.read_text(encoding="utf-8"))

    en_paths = key_paths(bundles["en.json"])
    zh_paths = key_paths(bundles["zh-CN.json"])
    assert en_paths == zh_paths, (
        f"locale bundles diverge; only in en: {sorted(en_paths - zh_paths)}; "
        f"only in zh-CN: {sorted(zh_paths - en_paths)}"
    )

    for name, bundle in bundles.items():
        offenders = unsorted_maps(bundle)
        assert not offenders, f"{name} has unsorted keys under: {offenders}"

    print("OK: locale bundles are parallel and sorted")


if __name__ == "__main__":
    main()
