#!/usr/bin/env python3
"""Initialize and filter Clavis' user-editable Matugen configuration."""

from __future__ import annotations

import argparse
import os
import tempfile
import tomllib
from pathlib import Path


TEMPLATES = {
    "quickshell": ("quickshell-colors.json", "clavis/colors.json"),
    "btop": ("btop.theme", "btop/themes/clavis.theme"),
    "cava": ("cava-colors.ini", "cava/colors.ini"),
    "kitty": ("kitty-colors.conf", "kitty/colors.conf"),
    "fcitx5": ("fcitx5-theme.conf", "fcitx5/Matugen/theme.conf"),
    "fcitx5_panel_svg": ("fcitx5-panel.svg", "fcitx5/Matugen/panel.svg"),
    "fcitx5_highlight_svg": (
        "fcitx5-highlight.svg",
        "fcitx5/Matugen/highlight.svg",
    ),
    "niri": ("niri-colors.kdl", "niri/colors.kdl"),
    "yazi": ("yazi-theme.toml", "yazi/theme.toml"),
    "zsh_prompt": ("zsh-prompt-colors.zsh", "zsh/prompt-colors.zsh"),
}


def _quote(value: Path | str) -> str:
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def default_values(share_root: Path, generated_home: Path) -> dict[str, dict[str, str]]:
    install_prefix = Path(
        os.environ.get("CLAVIS_INSTALL_PREFIX", "").strip()
        or Path.home() / ".local/lib/clavis"
    )
    stable_templates = install_prefix / "current/share/clavis/defaults/matugen/templates"
    template_root = stable_templates if (install_prefix / "current").exists() else (
        share_root / "defaults/matugen/templates"
        if (share_root / "defaults/matugen/templates").is_dir()
        else share_root / "matugen/templates"
    )
    values: dict[str, dict[str, str]] = {}
    for name, (template, relative_output) in TEMPLATES.items():
        output = generated_home / relative_output
        if name.startswith("fcitx5"):
            fcitx_name = Path(relative_output).name
            output = generated_home.parent / "data/fcitx5/themes/Clavis" / fcitx_name
        values[name] = {
            "input_path": str(template_root / template),
            "output_path": str(output),
        }
    return values


def render(values: dict[str, dict[str, str]], selected: list[str] | None = None) -> str:
    names = selected if selected is not None else list(TEMPLATES)
    lines = [
        "# Managed initially by Clavis; output_path values are user-editable.",
        "# Clavis ignores Matugen hooks and filters sections using the settings switches.",
        "[config]",
        "version_check = false",
    ]
    for name in names:
        item = values[name]
        lines.extend(
            [
                "",
                f"[templates.{name}]",
                f"input_path = {_quote(item['input_path'])}",
                f"output_path = {_quote(item['output_path'])}",
            ]
        )
    return "\n".join(lines) + "\n"


def load_values(path: Path) -> dict[str, dict[str, str]]:
    try:
        parsed = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise ValueError(f"cannot read Matugen config {path}: {error}") from error
    templates = parsed.get("templates")
    if not isinstance(templates, dict):
        raise ValueError("Matugen config must contain a [templates] table")
    result: dict[str, dict[str, str]] = {}
    for name, item in templates.items():
        if name not in TEMPLATES or not isinstance(item, dict):
            continue
        input_path = Path(str(item.get("input_path", ""))).expanduser()
        output_path = Path(str(item.get("output_path", ""))).expanduser()
        if not input_path.is_absolute() or not output_path.is_absolute():
            raise ValueError(f"templates.{name} paths must be absolute")
        result[name] = {
            "input_path": str(input_path),
            "output_path": str(output_path),
        }
    return result


def prepare(
    share_root: Path,
    config: Path,
    generated_home: Path,
    runtime_config: Path | None,
    requested: list[str],
    dry_run: bool,
) -> None:
    defaults = default_values(share_root, generated_home)
    selected = ["quickshell"]
    for name in requested:
        if name not in TEMPLATES:
            raise ValueError(f"unknown Matugen template: {name}")
        if name not in selected:
            selected.append(name)
    if config.is_file():
        values = load_values(config)
    else:
        values = defaults
        if not dry_run:
            _atomic_write(config, render(values))

    for name in selected:
        if name not in values:
            raise ValueError(f"Matugen config is missing [templates.{name}]")
        input_path = Path(values[name]["input_path"])
        if not input_path.is_file():
            raise ValueError(f"Matugen template does not exist: {input_path}")
        if not dry_run:
            Path(values[name]["output_path"]).parent.mkdir(parents=True, exist_ok=True)
    if runtime_config is not None:
        _atomic_write(runtime_config, render(values, selected))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--share-root", required=True, type=Path)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--generated-home", required=True, type=Path)
    parser.add_argument("--runtime-config", type=Path)
    parser.add_argument("--templates", default="")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--initialize-only", action="store_true")
    arguments = parser.parse_args()
    requested = [item for item in arguments.templates.split(",") if item]
    try:
        if arguments.initialize_only:
            if not arguments.config.exists() and not arguments.dry_run:
                _atomic_write(
                    arguments.config,
                    render(
                        default_values(
                            arguments.share_root, arguments.generated_home
                        )
                    ),
                )
        else:
            prepare(
                arguments.share_root,
                arguments.config,
                arguments.generated_home,
                arguments.runtime_config,
                requested,
                arguments.dry_run,
            )
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(arguments.config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
