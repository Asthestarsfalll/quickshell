#!/usr/bin/env python3
"""Atomically install Clavis' Niri-bound systemd user units without starting them."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import tempfile


UNITS = ("clavis-shell.service", "clavis-clipboard.service")


class UnitInstallError(RuntimeError):
    pass


def atomic_write(path: Path, payload: bytes) -> None:
    if path.parent.is_symlink() or path.is_symlink():
        raise UnitInstallError(f"refusing symlinked unit path: {path}")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def systemd_quote(path: Path) -> str:
    return '"' + str(path).replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(source: Path, stable_key: Path) -> bytes:
    text = source.read_text(encoding="utf-8")
    if text.count("@CLAVIS_KEY@") != 1:
        raise UnitInstallError(f"unexpected @CLAVIS_KEY@ count in {source}")
    rendered = text.replace("@CLAVIS_KEY@", systemd_quote(stable_key))
    required = ("PartOf=niri.service", "WantedBy=niri.service", "Restart=on-failure")
    if any(value not in rendered for value in required):
        raise UnitInstallError(f"unsafe Niri session unit: {source}")
    return rendered.encode()


def install(source_dir: Path, target_dir: Path, stable_key: Path) -> list[Path]:
    if not stable_key.is_absolute() or not stable_key.is_file() or not os.access(stable_key, os.X_OK):
        raise UnitInstallError(f"stable key executable is unavailable: {stable_key}")
    payloads: list[tuple[Path, bytes]] = []
    for name in UNITS:
        source = source_dir / name
        if not source.is_file() or source.is_symlink():
            raise UnitInstallError(f"unit template is unavailable: {source}")
        payloads.append((target_dir / name, render(source, stable_key)))
    for target, payload in payloads:
        atomic_write(target, payload)
    return [target for target, _payload in payloads]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True, type=Path)
    parser.add_argument("--target-dir", required=True, type=Path)
    parser.add_argument("--stable-key", required=True, type=Path)
    arguments = parser.parse_args()
    try:
        paths = install(arguments.source_dir, arguments.target_dir, arguments.stable_key)
    except (OSError, UnitInstallError) as error:
        print(str(error), file=os.sys.stderr)
        return 1
    for path in paths:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
