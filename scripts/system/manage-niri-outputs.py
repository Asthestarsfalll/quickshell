#!/usr/bin/env python3
"""Safely write the Clavis-managed Niri output-scale fragment."""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import stat
import subprocess
import tempfile
from typing import Callable


class OutputConfigError(RuntimeError):
    pass


def escape_kdl_string(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def render_outputs(scales: dict[str, float]) -> str:
    lines = ["// Managed by Clavis. Manual edits will be replaced.\n"]
    for name in sorted(scales):
        scale = float(scales[name])
        if not math.isfinite(scale) or scale < 0.5 or scale > 4.0:
            raise OutputConfigError(f"invalid scale for {name}: {scale}")
        if abs(scale * 4 - round(scale * 4)) > 1e-6:
            raise OutputConfigError(f"scale must use 0.25 steps for {name}: {scale}")
        lines.extend(
            [
                f'output "{escape_kdl_string(name)}" {{\n',
                f"    scale {scale:.2f}\n",
                "}\n",
            ]
        )
    return "".join(lines)


def current_output_names(niri_command: str) -> set[str]:
    result = subprocess.run(
        [niri_command, "msg", "--json", "outputs"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise OutputConfigError(
            result.stderr.strip() or "unable to read current Niri outputs"
        )
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise OutputConfigError(f"invalid Niri outputs response: {error}") from error
    if not isinstance(payload, dict):
        raise OutputConfigError("Niri outputs response is not an object")
    return set(payload)


def atomic_write(
    path: Path,
    payload: bytes,
    replace: Callable[[str, str], None] = os.replace,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary_name, stat.S_IRUSR | stat.S_IWUSR)
        replace(temporary_name, path)
    except Exception:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def apply_output_scales(
    session_config: Path,
    target: Path,
    scales: dict[str, float],
    expected_outputs: set[str],
    niri_command: str = "niri",
    replace: Callable[[str, str], None] = os.replace,
    output_reader: Callable[[str], set[str]] = current_output_names,
) -> None:
    if session_config.resolve() == target.resolve():
        raise OutputConfigError("managed fragment cannot replace the session config")
    if not session_config.is_file():
        raise OutputConfigError(f"managed Niri session is missing: {session_config}")

    current_outputs = output_reader(niri_command)
    missing = sorted(expected_outputs - current_outputs)
    if missing:
        raise OutputConfigError("output disconnected before save: " + ", ".join(missing))
    unknown = sorted(set(scales) - current_outputs)
    if unknown:
        raise OutputConfigError("refusing unknown output: " + ", ".join(unknown))

    payload = render_outputs(scales).encode()
    target.parent.mkdir(parents=True, exist_ok=True)
    session_text = session_config.read_text(encoding="utf-8")
    escaped_target = escape_kdl_string(str(target))
    managed_include = f'include optional=true "{escaped_target}"'
    if managed_include not in session_text:
        raise OutputConfigError(
            "active config does not include the Clavis-managed outputs fragment"
        )

    fragment_fd, fragment_name = tempfile.mkstemp(
        prefix=".outputs.candidate.", suffix=".kdl", dir=target.parent
    )
    session_fd, session_name = tempfile.mkstemp(
        prefix=".session.candidate.", suffix=".kdl", dir=target.parent
    )
    try:
        with os.fdopen(fragment_fd, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        candidate_include = (
            f'include "{escape_kdl_string(fragment_name)}"'
        )
        candidate_session = session_text.replace(
            managed_include, candidate_include, 1
        )
        with os.fdopen(session_fd, "w", encoding="utf-8") as stream:
            stream.write(candidate_session)
            stream.flush()
            os.fsync(stream.fileno())

        validation = subprocess.run(
            [niri_command, "validate", "-c", session_name],
            check=False,
            capture_output=True,
            text=True,
        )
        if validation.returncode != 0:
            raise OutputConfigError(
                validation.stderr.strip() or "niri validation failed"
            )

        if target.is_file():
            atomic_write(target.with_name(target.name + ".last-good"), target.read_bytes())
        os.chmod(fragment_name, stat.S_IRUSR | stat.S_IWUSR)
        replace(fragment_name, target)
        fragment_name = ""
    finally:
        if fragment_name:
            try:
                os.unlink(fragment_name)
            except FileNotFoundError:
                pass
        try:
            os.unlink(session_name)
        except FileNotFoundError:
            pass


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session-config", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--scales-json", required=True)
    parser.add_argument("--expected-json", required=True)
    parser.add_argument("--niri", default="niri")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        scales_value = json.loads(arguments.scales_json)
        expected_value = json.loads(arguments.expected_json)
        if not isinstance(scales_value, dict) or not isinstance(expected_value, list):
            raise OutputConfigError("scale or output payload has the wrong type")
        scales = {str(name): float(value) for name, value in scales_value.items()}
        expected = {str(name) for name in expected_value}
        apply_output_scales(
            arguments.session_config,
            arguments.target,
            scales,
            expected,
            arguments.niri,
        )
    except (OutputConfigError, OSError, ValueError) as error:
        print(str(error), file=os.sys.stderr)
        return 1
    print(json.dumps({"status": "written", "outputs": sorted(scales)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
