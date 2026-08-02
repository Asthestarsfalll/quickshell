#!/usr/bin/env python3
"""Manage the small KDL fragments explicitly owned by Clavis.

The user's config.kdl is never regenerated.  This helper only inspects its
include graph, adds a requested Clavis include, and atomically replaces files
inside the dedicated clavis directory after validating a complete candidate.
"""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
from typing import Any, Callable


class NiriConfigError(RuntimeError):
    pass


DOMAIN_FILES = {
    "binds": "binds.kdl",
    "layout": "layout.kdl",
    "outputs": "outputs.kdl",
}
INCLUDE_RE = re.compile(
    r'^\s*include(?:\s+optional=(true|false))?\s+"((?:\\.|[^"])*)"'
)
OUTPUT_RE = re.compile(r'^\s*output\s+"((?:\\.|[^"])*)"\s*\{')
BIND_RE = re.compile(r'^\s*([^\s/][^\s{]*)\s+(?:[^{}]*\s+)?\{')


def escape_kdl_string(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def unescape_kdl_string(value: str) -> str:
    return bytes(value, "utf-8").decode("unicode_escape")


def atomic_write(
    path: Path,
    payload: bytes,
    replace: Callable[[str, str], None] = os.replace,
) -> None:
    if path.parent.is_symlink():
        raise NiriConfigError(f"refusing symlinked config directory: {path.parent}")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
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


def timestamped_backup(config_dir: Path) -> Path:
    from datetime import datetime

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    target = config_dir.with_name(config_dir.name + ".backup-" + stamp)
    if target.exists() or target.is_symlink():
        raise NiriConfigError(f"backup already exists: {target}")
    shutil.copytree(config_dir, target, symlinks=True, copy_function=shutil.copy2)
    return target


def run_validation(config: Path, niri: str) -> tuple[bool, str]:
    result = subprocess.run(
        [niri, "validate", "-c", str(config)],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0, (result.stderr or result.stdout).strip()


def niri_version(niri: str) -> tuple[str, bool]:
    result = subprocess.run(
        [niri, "--version"], check=False, capture_output=True, text=True
    )
    text = (result.stdout or result.stderr).strip()
    match = re.search(r"\b(\d+)\.(\d+)\b", text)
    optional = bool(match) and (int(match.group(1)), int(match.group(2))) >= (26, 4)
    return text, optional


def resolve_include(source: Path, value: str) -> Path:
    candidate = Path(unescape_kdl_string(value))
    return candidate if candidate.is_absolute() else source.parent / candidate


def walk_includes(main: Path) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    visited: set[Path] = set()

    def visit(path: Path, depth: int) -> None:
        normalized = path.absolute()
        if normalized in visited or not path.is_file():
            return
        visited.add(normalized)
        for number, line in enumerate(
            path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            match = INCLUDE_RE.match(line)
            if not match:
                continue
            target = resolve_include(path, match.group(2)).absolute()
            item = {
                "source": str(path),
                "line": number,
                "value": unescape_kdl_string(match.group(2)),
                "path": str(target),
                "optional": match.group(1) == "true",
                "exists": target.is_file(),
                "depth": depth,
            }
            result.append(item)
            visit(target, depth + 1)

    visit(main, 0)
    return result


def included_files(main: Path) -> list[Path]:
    return [main, *(Path(item["path"]) for item in walk_includes(main) if item["exists"])]


def find_output_conflicts(main: Path, clavis_dir: Path) -> list[dict[str, Any]]:
    found: dict[str, list[str]] = {}
    for path in included_files(main):
        if path.parent == clavis_dir:
            continue
        for number, line in enumerate(
            path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            match = OUTPUT_RE.match(line)
            if match:
                found.setdefault(unescape_kdl_string(match.group(1)), []).append(
                    f"{path}:{number}"
                )
    return [
        {"output": name, "sources": sources}
        for name, sources in sorted(found.items())
        if sources
    ]


def normalize_bind(value: str) -> str:
    parts = [part.strip().lower() for part in value.split("+") if part.strip()]
    if len(parts) < 2:
        return ""
    return "+".join(sorted(parts[:-1]) + [parts[-1]])


def scan_bindings(path: Path) -> list[dict[str, Any]]:
    bindings: list[dict[str, Any]] = []
    in_binds = False
    depth = 0
    for number, line in enumerate(
        path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
    ):
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        if not in_binds and re.match(r"^binds\s*\{", stripped):
            in_binds = True
            depth = line.count("{") - line.count("}")
            continue
        if not in_binds:
            continue
        if depth == 1:
            match = BIND_RE.match(line)
            if match:
                key = match.group(1)
                normalized = normalize_bind(key)
                if normalized:
                    bindings.append(
                        {"key": key, "normalized": normalized, "source": str(path), "line": number}
                    )
        depth += line.count("{") - line.count("}")
        if depth <= 0:
            in_binds = False
    return bindings


def find_bind_conflicts(main: Path) -> list[dict[str, Any]]:
    found: dict[str, list[dict[str, Any]]] = {}
    for path in included_files(main):
        for binding in scan_bindings(path):
            found.setdefault(binding["normalized"], []).append(binding)
    return [
        {"key": key, "bindings": values}
        for key, values in sorted(found.items())
        if len(values) > 1
    ]


def all_bindings(main: Path, clavis_dir: Path) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for path in included_files(main):
        for binding in scan_bindings(path):
            binding["owner"] = "clavis" if path.parent == clavis_dir else "user"
            result.append(binding)
    return result


def domain_include(main: Path, fragment: Path) -> dict[str, Any] | None:
    target = fragment.absolute()
    for index, item in enumerate(walk_includes(main)):
        if Path(item["path"]) == target:
            return {**item, "index": index}
    return None


def status(main: Path, clavis_dir: Path, niri: str) -> dict[str, Any]:
    version, optional_supported = niri_version(niri)
    validation_ok, validation_error = (
        run_validation(main, niri)
        if main.is_file()
        else (False, f"Niri config is missing: {main}")
    )
    if validation_ok:
        validation_error = ""
    includes = walk_includes(main) if main.is_file() else []
    domains: dict[str, Any] = {}
    for domain, filename in DOMAIN_FILES.items():
        fragment = clavis_dir / filename
        include = domain_include(main, fragment) if main.is_file() else None
        later = [] if include is None else [
            item for index, item in enumerate(includes)
            if index > include["index"] and Path(item["path"]).parent != clavis_dir
        ]
        domains[domain] = {
            "path": str(fragment),
            "exists": fragment.is_file(),
            "include": include,
            "laterUserIncludes": later,
        }
    for domain, filename in {"colors": "colors.kdl", "effects": "effects.kdl", "cursor": "cursor.kdl"}.items():
        fragment = clavis_dir / filename
        include = domain_include(main, fragment) if main.is_file() else None
        later = [] if include is None else [
            item for index, item in enumerate(includes)
            if index > include["index"] and Path(item["path"]).parent != clavis_dir
        ]
        domains[domain] = {
            "path": str(fragment),
            "exists": fragment.is_file(),
            "include": include,
            "laterUserIncludes": later,
        }
    return {
        "schemaVersion": 1,
        "mainConfig": str(main),
        "clavisDirectory": str(clavis_dir),
        "niriVersion": version,
        "optionalIncludeSupported": optional_supported,
        "validation": {"ok": validation_ok, "error": validation_error},
        "includes": includes,
        "domains": domains,
        "keybindings": all_bindings(main, clavis_dir) if main.is_file() else [],
        "keybindConflicts": find_bind_conflicts(main) if main.is_file() else [],
        "outputDefinitions": find_output_conflicts(main, clavis_dir) if main.is_file() else [],
    }


def render_outputs(payload: dict[str, Any]) -> str:
    lines = ["// Managed by Clavis. Manual edits will be replaced.\n"]
    for name in sorted(payload):
        config = payload[name]
        if not isinstance(config, dict):
            raise NiriConfigError(f"invalid output settings for {name}")
        lines.append(f'output "{escape_kdl_string(name)}" {{\n')
        if config.get("disabled") is True:
            lines.append("    off\n")
        if "mode" in config:
            lines.append(f'    mode "{escape_kdl_string(str(config["mode"]))}"\n')
        if "scale" in config:
            scale = float(config["scale"])
            if not math.isfinite(scale) or scale < 0.5 or scale > 4:
                raise NiriConfigError(f"invalid scale for {name}: {scale}")
            lines.append(f"    scale {scale:g}\n")
        if "transform" in config:
            transform = str(config["transform"])
            allowed = {"normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"}
            if transform not in allowed:
                raise NiriConfigError(f"invalid transform for {name}: {transform}")
            lines.append(f'    transform "{transform}"\n')
        position = config.get("position")
        if isinstance(position, dict) and "x" in position and "y" in position:
            lines.append(f'    position x={int(position["x"])} y={int(position["y"])}\n')
        if config.get("vrr") is True:
            lines.append("    variable-refresh-rate\n")
        if config.get("focusAtStartup") is True:
            lines.append("    focus-at-startup\n")
        lines.append("}\n")
    return "".join(lines)


def render_layout(payload: dict[str, Any]) -> str:
    allowed = {
        "gaps", "focusRing", "border", "cornerRadius", "shadow",
        "defaultColumnWidth", "presetColumnWidths", "centerFocusedColumn",
        "alwaysCenterSingleColumn", "struts",
    }
    unknown = set(payload) - allowed
    if unknown:
        raise NiriConfigError("unknown layout fields: " + ", ".join(sorted(unknown)))
    lines = ["// Managed by Clavis. Manual edits will be replaced.\n", "layout {\n"]
    if "gaps" in payload:
        lines.append(f'    gaps {max(0, int(payload["gaps"]))}\n')
    for key, node in (("focusRing", "focus-ring"), ("border", "border"), ("shadow", "shadow")):
        value = payload.get(key)
        if isinstance(value, dict):
            lines.append(f"    {node} {{\n")
            if value.get("enabled") is False:
                lines.append("        off\n")
            if key != "shadow" and "width" in value:
                lines.append(f'        width {max(0, float(value["width"])):g}\n')
            lines.append("    }\n")
    default_width = payload.get("defaultColumnWidth")
    if default_width is not None:
        lines.append(f"    default-column-width {{ proportion {float(default_width):g}; }}\n")
    presets = payload.get("presetColumnWidths")
    if isinstance(presets, list) and presets:
        lines.append("    preset-column-widths {\n")
        for value in presets:
            lines.append(f"        proportion {float(value):g}\n")
        lines.append("    }\n")
    if "centerFocusedColumn" in payload:
        lines.append(f'    center-focused-column "{escape_kdl_string(str(payload["centerFocusedColumn"]))}"\n')
    if payload.get("alwaysCenterSingleColumn") is True:
        lines.append("    always-center-single-column\n")
    struts = payload.get("struts")
    if isinstance(struts, dict):
        lines.append("    struts {\n")
        for name in ("left", "right", "top", "bottom"):
            if name in struts:
                lines.append(f"        {name} {float(struts[name]):g}\n")
        lines.append("    }\n")
    lines.append("}\n")
    if "cornerRadius" in payload:
        lines.extend(
            [
                "\nwindow-rule {\n",
                f'    geometry-corner-radius {max(0, float(payload["cornerRadius"])):g}\n',
                "    clip-to-geometry true\n",
                "}\n",
            ]
        )
    return "".join(lines)


def render_binds(payload: dict[str, Any]) -> str:
    lines = ["// Managed by Clavis. Manual edits will be replaced.\n", "binds {\n"]
    for key in sorted(payload, key=normalize_bind):
        action = payload[key]
        if (not normalize_bind(key)
                or not re.fullmatch(r"[A-Za-z0-9_-]+(?:\+[A-Za-z0-9_-]+)+", key)
                or not isinstance(action, str) or not action.strip()):
            raise NiriConfigError(f"invalid binding: {key}")
        if "\n" in action or "\r" in action:
            raise NiriConfigError(f"multiline binding action is not allowed: {key}")
        lines.append(f"    {key} {{ {action.strip()} }}\n")
    lines.append("}\n")
    return "".join(lines)


def render_domain(domain: str, payload: dict[str, Any]) -> str:
    if domain == "outputs":
        return render_outputs(payload)
    if domain == "layout":
        return render_layout(payload)
    if domain == "binds":
        return render_binds(payload)
    raise NiriConfigError(f"unsupported managed domain: {domain}")


def include_line(fragment: Path, optional_supported: bool) -> str:
    prefix = "include optional=true" if optional_supported else "include"
    return f'{prefix} "clavis/{escape_kdl_string(fragment.name)}"'


def candidate_main_text(main: Path, fragment: Path, optional_supported: bool) -> str:
    text = main.read_text(encoding="utf-8")
    if domain_include(main, fragment):
        return text
    marker = "// Clavis managed fragment: " + fragment.stem
    suffix = "" if text.endswith("\n") else "\n"
    return text + suffix + "\n" + marker + "\n" + include_line(fragment, optional_supported) + "\n"


def validate_candidate(main: Path, fragment: Path, fragment_text: str, niri: str) -> str:
    version, optional_supported = niri_version(niri)
    del version
    fragment.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, fragment_name = tempfile.mkstemp(prefix=f".{fragment.name}.candidate.", dir=fragment.parent)
    main_fd, main_name = tempfile.mkstemp(prefix=".config.candidate.", suffix=".kdl", dir=main.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(fragment_text)
            stream.flush()
            os.fsync(stream.fileno())
        candidate_text = candidate_main_text(main, fragment, optional_supported)
        relative_candidate = os.path.relpath(fragment_name, main.parent)
        candidate_text = candidate_text.replace(
            include_line(fragment, optional_supported),
            f'include "{escape_kdl_string(relative_candidate)}"',
        )
        with os.fdopen(main_fd, "w", encoding="utf-8") as stream:
            stream.write(candidate_text)
            stream.flush()
            os.fsync(stream.fileno())
        valid, error = run_validation(Path(main_name), niri)
        if not valid:
            raise NiriConfigError(error or "niri validation failed")
        return candidate_main_text(main, fragment, optional_supported)
    finally:
        for name in (fragment_name, main_name):
            try:
                os.unlink(name)
            except FileNotFoundError:
                pass


def apply_domain(
    main: Path,
    clavis_dir: Path,
    domain: str,
    payload: dict[str, Any],
    niri: str,
    replace: Callable[[str, str], None] = os.replace,
) -> None:
    if domain not in DOMAIN_FILES:
        raise NiriConfigError(f"unsupported managed domain: {domain}")
    if not main.is_file() or main.is_symlink():
        raise NiriConfigError(f"user Niri config is not a regular file: {main}")
    fragment = clavis_dir / DOMAIN_FILES[domain]
    fragment_text = render_domain(domain, payload)
    main_text = validate_candidate(main, fragment, fragment_text, niri)
    if fragment.is_file():
        atomic_write(fragment.with_suffix(fragment.suffix + ".last-good"), fragment.read_bytes())
    if main.is_file():
        atomic_write(main.with_suffix(main.suffix + ".last-good"), main.read_bytes())
    atomic_write(fragment, fragment_text.encode(), replace)
    if not domain_include(main, fragment):
        atomic_write(main, main_text.encode(), replace)


def restore_domain(main: Path, clavis_dir: Path, domain: str, niri: str) -> None:
    if domain not in DOMAIN_FILES:
        raise NiriConfigError(f"unsupported managed domain: {domain}")
    fragment = clavis_dir / DOMAIN_FILES[domain]
    last_good = fragment.with_suffix(fragment.suffix + ".last-good")
    if not last_good.is_file():
        raise NiriConfigError(f"no last-known-good fragment for {domain}")
    current = fragment.read_bytes() if fragment.is_file() else None
    atomic_write(fragment, last_good.read_bytes())
    valid, error = run_validation(main, niri)
    if not valid:
        if current is not None:
            atomic_write(fragment, current)
        raise NiriConfigError(error or "restored configuration is invalid")


def extract_top_level_blocks(text: str, node: str) -> list[str]:
    blocks: list[str] = []
    lines = text.splitlines(keepends=True)
    start_pattern = re.compile(rf"^\s*{re.escape(node)}(?:\s|\")")
    index = 0
    while index < len(lines):
        if not start_pattern.match(lines[index]) or lines[index].lstrip().startswith("//"):
            index += 1
            continue
        start = index
        depth = 0
        seen_open = False
        while index < len(lines):
            line = lines[index]
            depth += line.count("{") - line.count("}")
            seen_open = seen_open or "{" in line
            index += 1
            if seen_open and depth <= 0:
                break
        blocks.append("".join(lines[start:index]).rstrip() + "\n")
    return blocks


def parse_output_settings(text: str) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for block in extract_top_level_blocks(text, "output"):
        header = OUTPUT_RE.match(block.splitlines()[0])
        if not header:
            continue
        name = unescape_kdl_string(header.group(1))
        config: dict[str, Any] = {}
        mode = re.search(r'^\s*mode\s+"([^"]+)"', block, re.MULTILINE)
        scale = re.search(r"^\s*scale\s+([0-9.]+)", block, re.MULTILINE)
        position = re.search(r"^\s*position\s+x=(-?\d+)\s+y=(-?\d+)", block, re.MULTILINE)
        if mode:
            config["mode"] = mode.group(1)
        if scale:
            config["scale"] = float(scale.group(1))
        if position:
            config["position"] = {"x": int(position.group(1)), "y": int(position.group(2))}
        if re.search(r"^\s*off\s*$", block, re.MULTILINE):
            config["disabled"] = True
        if re.search(r"^\s*focus-at-startup\s*$", block, re.MULTILINE):
            config["focusAtStartup"] = True
        if re.search(r"^\s*variable-refresh-rate", block, re.MULTILINE):
            config["vrr"] = True
        result[name] = config
    return result


def replace_include(text: str, old_value: str, new_value: str, optional: bool = True) -> str:
    replacement = (
        ("include optional=true" if optional else "include")
        + f' "{escape_kdl_string(new_value)}"'
    )
    pattern = re.compile(
        r'^\s*include(?:\s+optional=(?:true|false))?\s+"'
        + re.escape(old_value)
        + r'"[^\n]*$',
        re.MULTILINE,
    )
    if pattern.search(text):
        return pattern.sub(replacement, text, count=1)
    suffix = "" if text.endswith("\n") else "\n"
    return text + suffix + replacement + "\n"


def ensure_include_after(text: str, value: str, after_value: str | None, optional: bool) -> str:
    if re.search(
        r'^\s*include(?:\s+optional=(?:true|false))?\s+"' + re.escape(value) + r'"',
        text,
        re.MULTILINE,
    ):
        return text
    line = ("include optional=true" if optional else "include") + f' "{value}"'
    if after_value:
        pattern = re.compile(
            r'(^\s*include(?:\s+optional=(?:true|false))?\s+"'
            + re.escape(after_value)
            + r'"[^\n]*$)',
            re.MULTILINE,
        )
        if pattern.search(text):
            return pattern.sub(r"\1\n" + line, text, count=1)
    suffix = "" if text.endswith("\n") else "\n"
    return text + suffix + "\n" + line + "\n"


def ensure_environment_key(text: str, stable_key: Path) -> str:
    if re.search(r'^\s*CLAVIS_KEY\s+"', text, re.MULTILINE):
        return text
    match = re.search(r"^environment\s*\{", text, re.MULTILINE)
    line = f'    CLAVIS_KEY "{escape_kdl_string(str(stable_key))}"\n'
    if not match:
        return "environment {\n" + line + "}\n\n" + text
    position = match.end()
    depth = 1
    while position < len(text) and depth > 0:
        if text[position] == "{":
            depth += 1
        elif text[position] == "}":
            depth -= 1
            if depth == 0:
                return text[:position] + line + text[position:]
        position += 1
    raise NiriConfigError("unterminated environment block")


def update_settings_database(path: Path, outputs: dict[str, Any]) -> bytes:
    parsed: dict[str, Any] = {}
    if path.is_file():
        parsed = json.loads(path.read_text(encoding="utf-8") or "{}")
        if not isinstance(parsed, dict):
            raise NiriConfigError(f"Clavis settings are not an object: {path}")
    niri = parsed.get("niri")
    if not isinstance(niri, dict):
        niri = {}
    niri["managedDomains"] = {
        "colors": True,
        "effects": True,
        "cursor": False,
        "binds": True,
        "layout": True,
        "outputs": True,
    }
    niri["outputs"] = outputs
    niri.setdefault("layout", {})
    niri.setdefault("keybindOverrides", {})
    parsed["niri"] = niri
    return (json.dumps(parsed, ensure_ascii=False, indent=2) + "\n").encode()


def migrate_user_config(
    main: Path,
    clavis_dir: Path,
    settings: Path,
    stable_key: Path,
    niri: str,
    existing_backup: Path | None,
) -> Path:
    config_dir = main.parent
    if not main.is_file() or main.is_symlink() or config_dir.is_symlink():
        raise NiriConfigError(f"unsafe user Niri config: {main}")
    backup = existing_backup or timestamped_backup(config_dir)
    if not backup.is_dir():
        raise NiriConfigError(f"complete Niri backup is missing: {backup}")

    with tempfile.TemporaryDirectory(prefix=".clavis-migration.", dir=config_dir.parent) as temporary:
        staged_root = Path(temporary) / "niri"
        shutil.copytree(config_dir, staged_root, symlinks=True, copy_function=shutil.copy2)
        staged_main = staged_root / main.name
        staged_clavis = staged_root / "clavis"
        if staged_clavis.is_symlink():
            raise NiriConfigError(f"refusing existing symlinked Clavis directory: {staged_clavis}")
        staged_clavis.mkdir(mode=0o700, exist_ok=True)

        text = staged_main.read_text(encoding="utf-8")
        _, optional = niri_version(niri)

        old_outputs = staged_root / "output.kdl"
        output_text = old_outputs.read_text(encoding="utf-8") if old_outputs.is_file() else ""
        output_blocks = extract_top_level_blocks(output_text, "output")
        layer_blocks = extract_top_level_blocks(output_text, "layer-rule")
        outputs_payload = "// Managed by Clavis. Manual edits will be replaced.\n" + "\n".join(output_blocks)
        (staged_clavis / "outputs.kdl").write_text(outputs_payload, encoding="utf-8")
        if layer_blocks:
            (staged_clavis / "layer-rules.kdl").write_text(
                "// Managed by Clavis. Manual edits will be replaced.\n" + "\n".join(layer_blocks),
                encoding="utf-8",
            )

        old_effects = staged_root / "clavis-effects.kdl"
        effects_text = old_effects.read_text(encoding="utf-8") if old_effects.is_file() else "// Managed by Clavis.\n"
        (staged_clavis / "effects.kdl").write_text(effects_text, encoding="utf-8")
        old_colors = staged_root / "colors.kdl"
        colors_text = old_colors.read_text(encoding="utf-8") if old_colors.is_file() else "// Managed by Clavis.\n"
        (staged_clavis / "colors.kdl").write_text(colors_text, encoding="utf-8")
        (staged_clavis / "binds.kdl").write_text(
            "// Managed by Clavis. Manual edits will be replaced.\nbinds {\n}\n",
            encoding="utf-8",
        )
        (staged_clavis / "layout.kdl").write_text(
            "// Managed by Clavis. Manual edits will be replaced.\nlayout {\n}\n",
            encoding="utf-8",
        )

        text = replace_include(text, "output.kdl", "clavis/outputs.kdl", optional)
        text = replace_include(text, "clavis-effects.kdl", "clavis/effects.kdl", optional)
        text = ensure_include_after(text, "clavis/colors.kdl", "theme.kdl", optional)
        text = ensure_include_after(text, "clavis/binds.kdl", "binds.kdl", optional)
        text = ensure_include_after(text, "clavis/layout.kdl", "clavis/binds.kdl", optional)
        if layer_blocks:
            text = ensure_include_after(text, "clavis/layer-rules.kdl", "windowrule.kdl", optional)
        text = ensure_environment_key(text, stable_key)
        staged_main.write_text(text, encoding="utf-8")
        (staged_root / "startup.kdl").write_text(
            "// Polkit authentication agent\n"
            'spawn-at-startup "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"\n',
            encoding="utf-8",
        )

        valid, error = run_validation(staged_main, niri)
        if not valid:
            raise NiriConfigError(error or "migrated Niri configuration is invalid")

        for staged in sorted(staged_clavis.iterdir()):
            atomic_write(clavis_dir / staged.name, staged.read_bytes())
        atomic_write(config_dir / "startup.kdl", (staged_root / "startup.kdl").read_bytes())
        atomic_write(main, staged_main.read_bytes())
        atomic_write(settings, update_settings_database(settings, parse_output_settings(output_text)))

    valid, error = run_validation(main, niri)
    if not valid:
        raise NiriConfigError(error or "installed Niri configuration is invalid")
    return backup


def parse_payload(value: str) -> dict[str, Any]:
    parsed = json.loads(value)
    if not isinstance(parsed, dict):
        raise NiriConfigError("payload must be a JSON object")
    return parsed


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    result.add_argument("action", choices=["status", "apply", "restore", "migrate"])
    result.add_argument("--config", type=Path, required=True)
    result.add_argument("--clavis-dir", type=Path, required=True)
    result.add_argument("--niri", default="niri")
    result.add_argument("--domain", choices=sorted(DOMAIN_FILES))
    result.add_argument("--payload-json")
    result.add_argument("--settings", type=Path)
    result.add_argument("--stable-key", type=Path)
    result.add_argument("--existing-backup", type=Path)
    return result


def main() -> int:
    arguments = parser().parse_args()
    try:
        if arguments.action == "status":
            print(json.dumps(status(arguments.config, arguments.clavis_dir, arguments.niri)))
            return 0
        if arguments.action == "migrate":
            if arguments.settings is None or arguments.stable_key is None:
                raise NiriConfigError("--settings and --stable-key are required")
            backup = migrate_user_config(
                arguments.config,
                arguments.clavis_dir,
                arguments.settings,
                arguments.stable_key,
                arguments.niri,
                arguments.existing_backup,
            )
            print(json.dumps({"status": "migrated", "backup": str(backup)}))
            return 0
        if not arguments.domain:
            raise NiriConfigError("--domain is required")
        if arguments.action == "apply":
            if arguments.payload_json is None:
                raise NiriConfigError("--payload-json is required")
            apply_domain(
                arguments.config,
                arguments.clavis_dir,
                arguments.domain,
                parse_payload(arguments.payload_json),
                arguments.niri,
            )
        else:
            restore_domain(arguments.config, arguments.clavis_dir, arguments.domain, arguments.niri)
    except (NiriConfigError, OSError, ValueError, json.JSONDecodeError) as error:
        print(str(error), file=os.sys.stderr)
        return 1
    print(json.dumps({"status": "ok", "action": arguments.action, "domain": arguments.domain}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
