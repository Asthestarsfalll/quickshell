#!/usr/bin/env python3
"""Inspect and safely manage user XDG Autostart entries."""

from __future__ import annotations

import argparse
import configparser
import json
import os
from pathlib import Path
import re
import shlex
import tempfile
from typing import Any


class AutostartError(RuntimeError):
    pass


def config_home() -> Path:
    value = os.environ.get("XDG_CONFIG_HOME", "").strip()
    return Path(value) if value else Path.home() / ".config"


def config_dirs() -> list[Path]:
    result = [config_home()]
    result.extend(Path(item) for item in os.environ.get(
        "XDG_CONFIG_DIRS", "/etc/xdg"
    ).split(":") if item)
    return result


def data_dirs() -> list[Path]:
    home = os.environ.get("XDG_DATA_HOME", "").strip()
    result = [Path(home) if home else Path.home() / ".local/share"]
    result.extend(Path(item) for item in os.environ.get(
        "XDG_DATA_DIRS", "/usr/local/share:/usr/share"
    ).split(":") if item)
    return result


def safe_name(value: str) -> str:
    text = value.replace("\\", "\\\\").replace("\n", "\\n").strip()
    if not text:
        raise AutostartError("entry name cannot be empty")
    return text


def safe_id(value: str) -> str:
    identifier = re.sub(r"[^A-Za-z0-9_.-]+", "-", value.strip()).strip(".-")
    if not identifier:
        raise AutostartError("invalid desktop entry id")
    return identifier + ("" if identifier.endswith(".desktop") else ".desktop")


def quote_exec_argument(value: str) -> str:
    if "\x00" in value or "\n" in value or "\r" in value:
        raise AutostartError("Exec argument contains an invalid control character")
    if re.fullmatch(r"[A-Za-z0-9_./:@%+=,-]+", value):
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`").replace("$", "\\$")
    return f'"{escaped}"'


def render_entry(name: str, command: list[str], hidden: bool = False) -> bytes:
    if not command or not command[0]:
        raise AutostartError("custom command cannot be empty")
    lines = [
        "[Desktop Entry]",
        "Type=Application",
        f"Name={safe_name(name)}",
        "Exec=" + " ".join(quote_exec_argument(item) for item in command),
        "Terminal=false",
        "Hidden=" + ("true" if hidden else "false"),
        "X-Clavis-Managed=true",
        "",
    ]
    return "\n".join(lines).encode()


def atomic_write(path: Path, payload: bytes) -> None:
    if path.parent.is_symlink():
        raise AutostartError(f"refusing symlinked autostart directory: {path.parent}")
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


def parse_entry(path: Path) -> dict[str, Any] | None:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read(path, encoding="utf-8")
        section = parser["Desktop Entry"]
    except (OSError, KeyError, configparser.Error):
        return None
    return {
        "id": path.name,
        "name": section.get("Name", path.stem),
        "exec": section.get("Exec", ""),
        "hidden": section.getboolean("Hidden", fallback=False),
        "path": str(path),
        "user": str(path).startswith(str(config_home() / "autostart")),
        "managed": section.getboolean("X-Clavis-Managed", fallback=False),
    }


def list_entries() -> list[dict[str, Any]]:
    effective: dict[str, dict[str, Any]] = {}
    system_dirs = [directory / "autostart" for directory in config_dirs()[1:]]
    for directory in reversed(system_dirs):
        if directory.is_dir():
            for path in sorted(directory.glob("*.desktop")):
                entry = parse_entry(path)
                if entry:
                    effective[path.name] = entry
    user_dir = config_home() / "autostart"
    if user_dir.is_dir():
        for path in sorted(user_dir.glob("*.desktop")):
            entry = parse_entry(path)
            if entry:
                effective[path.name] = entry
    return sorted(effective.values(), key=lambda item: (item["name"].lower(), item["id"]))


def list_applications() -> list[dict[str, Any]]:
    effective: dict[str, dict[str, Any]] = {}
    for directory in reversed(data_dirs()):
        application_dir = directory / "applications"
        if not application_dir.is_dir():
            continue
        for path in sorted(application_dir.glob("*.desktop")):
            entry = parse_entry(path)
            if entry and not entry["hidden"] and entry["exec"]:
                effective[path.name] = {
                    "id": path.name,
                    "name": entry["name"],
                    "exec": entry["exec"],
                    "path": str(path),
                }
    return sorted(effective.values(), key=lambda item: (item["name"].lower(), item["id"]))


def add_application(identifier: str) -> Path:
    entry_id = safe_id(identifier)
    source = next(
        (directory / "applications" / entry_id for directory in data_dirs()
         if (directory / "applications" / entry_id).is_file()),
        Path(),
    )
    if not source.is_file() or source.is_symlink():
        raise AutostartError(f"desktop application does not exist: {entry_id}")
    target = config_home() / "autostart" / entry_id
    if target.exists():
        existing = parse_entry(target)
        if not existing or not existing.get("managed", False):
            raise AutostartError(f"refusing to overwrite non-Clavis user entry: {target}")
    text = source.read_text(encoding="utf-8")
    if not re.search(r"^\[Desktop Entry\]\s*$", text, re.MULTILINE):
        raise AutostartError(f"invalid Desktop Entry: {source}")
    if re.search(r"^Hidden=.*$", text, re.MULTILINE):
        text = re.sub(r"^Hidden=.*$", "Hidden=false", text, count=1, flags=re.MULTILINE)
    else:
        text = text.replace("[Desktop Entry]", "[Desktop Entry]\nHidden=false", 1)
    if not re.search(r"^X-Clavis-Managed=.*$", text, re.MULTILINE):
        text = text.replace("[Desktop Entry]", "[Desktop Entry]\nX-Clavis-Managed=true", 1)
    atomic_write(target, text.encode())
    return target


def add_custom(identifier: str, name: str, command_text: str) -> Path:
    try:
        command = shlex.split(command_text, posix=True)
    except ValueError as error:
        raise AutostartError(f"invalid command: {error}") from error
    path = config_home() / "autostart" / safe_id(identifier)
    if path.exists():
        existing = parse_entry(path)
        if not existing or not existing.get("managed", False):
            raise AutostartError(f"refusing to overwrite non-Clavis user entry: {path}")
    atomic_write(path, render_entry(name, command))
    return path


def set_hidden(identifier: str, hidden: bool) -> Path:
    entry_id = safe_id(identifier)
    user_path = config_home() / "autostart" / entry_id
    source = user_path
    if not source.is_file():
        source = next(
            (directory / "autostart" / entry_id for directory in config_dirs()[1:]
             if (directory / "autostart" / entry_id).is_file()),
            Path(),
        )
    if not source.is_file():
        raise AutostartError(f"autostart entry does not exist: {entry_id}")
    text = source.read_text(encoding="utf-8")
    line = "Hidden=" + ("true" if hidden else "false")
    if re.search(r"^Hidden=.*$", text, re.MULTILINE):
        text = re.sub(r"^Hidden=.*$", line, text, count=1, flags=re.MULTILINE)
    else:
        marker = re.search(r"^\[Desktop Entry\]\s*$", text, re.MULTILINE)
        if not marker:
            raise AutostartError(f"invalid Desktop Entry: {source}")
        text = text[:marker.end()] + "\n" + line + text[marker.end():]
    atomic_write(user_path, text.encode())
    return user_path


def delete_user(identifier: str) -> None:
    path = config_home() / "autostart" / safe_id(identifier)
    if not path.is_file() or path.is_symlink():
        raise AutostartError(f"not a removable user entry: {path}")
    path.unlink()


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    result.add_argument("action", choices=[
        "list", "applications", "add-application", "add-custom", "set-hidden", "delete"
    ])
    result.add_argument("--id")
    result.add_argument("--name")
    result.add_argument("--command")
    result.add_argument("--hidden", choices=["true", "false"])
    return result


def main() -> int:
    arguments = parser().parse_args()
    try:
        if arguments.action == "list":
            print(json.dumps({"entries": list_entries()}))
            return 0
        if arguments.action == "applications":
            print(json.dumps({"applications": list_applications()}))
            return 0
        if not arguments.id:
            raise AutostartError("--id is required")
        if arguments.action == "add-application":
            path = add_application(arguments.id)
        elif arguments.action == "add-custom":
            if arguments.name is None or arguments.command is None:
                raise AutostartError("--name and --command are required")
            path = add_custom(arguments.id, arguments.name, arguments.command)
        elif arguments.action == "set-hidden":
            if arguments.hidden is None:
                raise AutostartError("--hidden is required")
            path = set_hidden(arguments.id, arguments.hidden == "true")
        else:
            delete_user(arguments.id)
            path = config_home() / "autostart" / safe_id(arguments.id)
    except (AutostartError, OSError) as error:
        print(str(error), file=os.sys.stderr)
        return 1
    print(json.dumps({"status": "ok", "path": str(path)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
