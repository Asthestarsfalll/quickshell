#!/usr/bin/env python3
"""Manage only the user's XDG Autostart directory for Clavis."""

from __future__ import annotations

import argparse
import configparser
import json
import os
from pathlib import Path
import re
import stat
import tempfile
from typing import Any


SCHEMA_VERSION = 1


class AutostartError(RuntimeError):
    pass


def config_home() -> Path:
    value = os.environ.get("XDG_CONFIG_HOME", "").strip()
    if value:
        path = Path(value).expanduser()
        if not path.is_absolute():
            raise AutostartError("XDG_CONFIG_HOME must be an absolute path")
        return path
    return Path.home() / ".config"


def autostart_dir() -> Path:
    return config_home() / "autostart"


def safe_id(value: str) -> str:
    raw = str(value or "").strip()
    identifier = re.sub(r"[^A-Za-z0-9_.-]+", "-", raw)
    identifier = identifier.strip(".-")
    if not identifier:
        raise AutostartError("invalid desktop entry id")
    return identifier if identifier.endswith(".desktop") else identifier + ".desktop"


def safe_field(value: str, field: str, required: bool = False) -> str:
    text = str(value or "")
    if "\x00" in text or "\n" in text or "\r" in text:
        raise AutostartError(f"{field} contains an invalid control character")
    if required and not text.strip():
        raise AutostartError(f"{field} cannot be empty")
    return text


def ensure_directory(create: bool = False) -> Path:
    directory = autostart_dir()
    if directory.is_symlink():
        raise AutostartError(f"refusing symlinked autostart directory: {directory}")
    if directory.exists():
        if not directory.is_dir():
            raise AutostartError(f"autostart path is not a directory: {directory}")
        return directory
    if not create:
        return directory
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    if directory.is_symlink() or not directory.is_dir():
        raise AutostartError(f"failed to initialize autostart directory: {directory}")
    return directory


def user_entry_path(identifier: str) -> Path:
    directory = ensure_directory()
    filename = safe_id(identifier)
    path = directory / filename
    if path.parent != directory:
        raise AutostartError("autostart entry escaped its directory")
    return path


def application_entry_path(identifier: str) -> Path:
    directory = ensure_directory()
    filename = "clavis-" + safe_id(identifier)
    path = directory / filename
    if path.parent != directory:
        raise AutostartError("autostart entry escaped its directory")
    return path


def invalid_entry(path: Path, error: str) -> dict[str, Any]:
    return {
        "id": path.name,
        "name": path.stem,
        "exec": "",
        "icon": "",
        "hidden": False,
        "path": str(path),
        "valid": False,
        "error": error,
    }


def parse_entry(path: Path) -> dict[str, Any]:
    if path.is_symlink():
        return invalid_entry(path, "symbolic links are not supported")
    try:
        text = path.read_text(encoding="utf-8")
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.read_string(text)
        section = parser["Desktop Entry"]
    except (OSError, UnicodeError, KeyError, configparser.Error) as error:
        return invalid_entry(path, str(error))

    name = section.get("Name", path.stem)
    command = section.get("Exec", "")
    icon = section.get("Icon", "")
    hidden_text = section.get("Hidden", "false")
    try:
        hidden = section.getboolean("Hidden", fallback=False)
    except ValueError:
        return invalid_entry(path, f"invalid Hidden value: {hidden_text}")

    valid = bool(name.strip() and command.strip())
    result = {
        "id": path.name,
        "name": name,
        "exec": command,
        "icon": icon,
        "hidden": hidden,
        "path": str(path),
        "valid": valid,
        "error": "" if valid else "Desktop Entry requires Name and Exec",
    }
    return result


def list_entries() -> dict[str, Any]:
    directory = ensure_directory()
    if not directory.exists():
        return {
            "schemaVersion": SCHEMA_VERSION,
            "directory": str(directory),
            "entries": [],
        }

    entries = [
        parse_entry(path)
        for path in sorted(directory.glob("*.desktop"), key=lambda item: item.name.lower())
        if path.is_file() or path.is_symlink()
    ]
    entries.sort(key=lambda item: (item["name"].lower(), item["id"].lower()))
    return {
        "schemaVersion": SCHEMA_VERSION,
        "directory": str(directory),
        "entries": entries,
    }


def atomic_write(path: Path, payload: bytes) -> None:
    directory = ensure_directory()
    if path.parent != directory:
        raise AutostartError("refusing to write outside the user autostart directory")
    if path.is_symlink():
        raise AutostartError(f"refusing symlinked autostart entry: {path}")

    mode = 0o600
    if path.exists():
        mode = stat.S_IMODE(path.stat().st_mode)

    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=directory)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def render_application(name: str, command: str, icon: str) -> bytes:
    name = safe_field(name, "Name", required=True)
    command = safe_field(command, "Exec", required=True)
    icon = safe_field(icon, "Icon")
    lines = [
        "[Desktop Entry]",
        "Type=Application",
        f"Name={name}",
        f"Exec={command}",
    ]
    if icon:
        lines.append(f"Icon={icon}")
    lines.extend(["Hidden=false", ""])
    return "\n".join(lines).encode("utf-8")


def add_application(identifier: str, name: str, command: str, icon: str) -> Path:
    ensure_directory(create=True)
    path = application_entry_path(identifier)
    if path.exists() or path.is_symlink():
        raise AutostartError(f"application is already added: {path.name}")
    atomic_write(path, render_application(name, command, icon))
    return path


def set_hidden(identifier: str, hidden: bool) -> Path:
    path = user_entry_path(identifier)
    if path.is_symlink() or not path.is_file():
        raise AutostartError(f"not a removable user entry: {path.name}")

    text = path.read_text(encoding="utf-8")
    hidden_line = f"Hidden={'true' if hidden else 'false'}"
    hidden_pattern = re.compile(r"(?m)^[ \t]*Hidden=.*(?P<eol>\r?\n|$)")

    def replace_hidden(match: re.Match[str]) -> str:
        return hidden_line + match.group("eol")

    if hidden_pattern.search(text):
        updated = hidden_pattern.sub(replace_hidden, text, count=1)
    else:
        marker = re.search(r"(?m)^\[Desktop Entry\][ \t]*(?:\r?\n|$)", text)
        if not marker:
            raise AutostartError(f"invalid Desktop Entry: {path.name}")
        line_ending = "\r\n" if "\r\n" in text else "\n"
        updated = text[:marker.end()] + hidden_line + line_ending + text[marker.end():]

    atomic_write(path, updated.encode("utf-8"))
    return path


def delete_user(identifier: str) -> Path:
    path = user_entry_path(identifier)
    if path.is_symlink() or not path.is_file():
        raise AutostartError(f"not a removable user entry: {path.name}")
    path.unlink()
    return path


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    result.add_argument("action", choices=[
        "list", "add-application", "set-hidden", "delete"
    ])
    result.add_argument("--id")
    result.add_argument("--name")
    result.add_argument("--exec", dest="command")
    result.add_argument("--icon", default="")
    result.add_argument("--hidden", choices=["true", "false"])
    return result


def ok(path: Path | None = None, **fields: Any) -> None:
    payload: dict[str, Any] = {"schemaVersion": SCHEMA_VERSION, "status": "ok"}
    if path is not None:
        payload["path"] = str(path)
    payload.update(fields)
    print(json.dumps(payload, ensure_ascii=False))


def main() -> int:
    arguments = parser().parse_args()
    try:
        if arguments.action == "list":
            print(json.dumps(list_entries(), ensure_ascii=False))
            return 0
        if not arguments.id:
            raise AutostartError("--id is required")
        if arguments.action == "add-application":
            if arguments.name is None or arguments.command is None:
                raise AutostartError("--name and --exec are required")
            path = add_application(
                arguments.id, arguments.name, arguments.command, arguments.icon
            )
        elif arguments.action == "set-hidden":
            if arguments.hidden is None:
                raise AutostartError("--hidden is required")
            path = set_hidden(arguments.id, arguments.hidden == "true")
        else:
            path = delete_user(arguments.id)
        ok(path)
        return 0
    except (AutostartError, OSError, UnicodeError) as error:
        print(str(error), file=os.sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
