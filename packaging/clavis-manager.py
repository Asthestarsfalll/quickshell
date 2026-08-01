#!/usr/bin/env python3
"""Release, profile and migration operations behind the stable `key` CLI."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import shlex
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, NoReturn

from clavis_paths import ClavisPaths, PathConfigurationError


MANIFEST_SCHEMA = 1
RELEASE_PATTERN = re.compile(r"^(\d{4})\.(\d{2})\.(\d{2})(?:\.(\d+))?$")
REQUIRED_PROTOCOLS = {"core": 1, "clipboard": 2, "sysmon": 1}
REQUIRED_DATA_SCHEMAS = {"config": 1, "manifest": 1, "profile": 1}
MANAGED_SERVICES = ("clavis-shell.service", "clavis-cliphist.service")


class ClavisError(RuntimeError):
    pass


def fail(message: str, code: int = 1) -> NoReturn:
    print(f"key: {message}", file=sys.stderr)
    raise SystemExit(code)


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def release_key(value: str) -> tuple[int, int, int, int]:
    match = RELEASE_PATTERN.fullmatch(value)
    if match is None:
        raise ClavisError(
            f"invalid release {value!r}; expected YYYY.MM.DD or YYYY.MM.DD.N"
        )
    year, month, day = (int(match.group(index)) for index in range(1, 4))
    dt.date(year, month, day)
    revision = int(match.group(4) or "0")
    return year, month, day, revision


def atomic_write(path: Path, data: bytes, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=str(path.parent)
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def atomic_json(path: Path, value: Any) -> None:
    atomic_write(
        path,
        (json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n").encode(),
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def file_record(path: Path) -> dict[str, Any]:
    return {
        "path": str(path),
        "sha256": sha256(path),
        "mode": stat.S_IMODE(path.stat().st_mode),
    }


def _snapshot_path(path: Path) -> tuple[str, bytes | str | None, int]:
    if path.is_symlink():
        return "symlink", os.readlink(path), 0
    if not path.exists():
        return "absent", None, 0
    if not path.is_file():
        raise ClavisError(f"managed path is not a regular file: {path}")
    return "file", path.read_bytes(), stat.S_IMODE(path.stat().st_mode)


def _restore_snapshot(
    path: Path, snapshot: tuple[str, bytes | str | None, int]
) -> None:
    kind, value, mode = snapshot
    if path.exists() or path.is_symlink():
        if path.is_dir() and not path.is_symlink():
            raise ClavisError(f"cannot restore managed file over directory: {path}")
        path.unlink()
    if kind == "absent":
        return
    if kind == "file":
        assert isinstance(value, bytes)
        atomic_write(path, value, mode)
        return
    assert kind == "symlink" and isinstance(value, str)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.restore-{os.getpid()}")
    if temporary.exists() or temporary.is_symlink():
        temporary.unlink()
    temporary.symlink_to(value)
    os.replace(temporary, path)


def _record_for_path(records: list[dict[str, Any]], path: Path) -> dict[str, Any] | None:
    return next(
        (record for record in records if record.get("path") == str(path)), None
    )


def _require_replaceable(
    path: Path, desired: bytes, owned_record: dict[str, Any] | None
) -> None:
    if not path.exists() and not path.is_symlink():
        return
    if path.is_symlink() or not path.is_file():
        raise ClavisError(f"install conflict at {path}: not a regular managed file")
    if path.read_bytes() == desired:
        return
    if owned_record is not None and sha256(path) == owned_record.get("sha256"):
        return
    raise ClavisError(
        f"install conflict at {path}: existing file is not owned by this manifest"
    )


def release_file_records(root: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for path in sorted(root.rglob("*")):
        if path.is_file() and not path.is_symlink():
            record = file_record(path)
            record["path"] = str(path.relative_to(root))
            records.append(record)
    return records


def release_directory_records(root: Path) -> list[dict[str, Any]]:
    return [
        {
            "path": str(path.relative_to(root)),
            "mode": stat.S_IMODE(path.stat().st_mode),
        }
        for path in sorted(root.rglob("*"))
        if path.is_dir() and not path.is_symlink()
    ]


def _release_owned_directories(entry: dict[str, Any]) -> set[str]:
    recorded = entry.get("directories")
    if isinstance(recorded, list):
        return {
            str(Path(record["path"]))
            for record in recorded
            if isinstance(record, dict) and isinstance(record.get("path"), str)
        }
    # Schema-v1 manifests created before directory records can still safely
    # remove only directories proven to be parents of recorded files.
    directories: set[str] = set()
    for record in entry.get("files", []):
        if not isinstance(record, dict) or not isinstance(record.get("path"), str):
            continue
        parent = Path(record["path"]).parent
        while parent != Path("."):
            directories.add(str(parent))
            parent = parent.parent
    return directories


def _release_tree_matches_partial(final: Path, partial: Path) -> bool:
    expected_files = {
        record["path"]: (record["sha256"], int(record["mode"]) & ~0o222)
        for record in release_file_records(partial)
    }
    actual_files = {
        record["path"]: (record["sha256"], int(record["mode"]))
        for record in release_file_records(final)
    }
    expected_directories = {
        record["path"]: int(record["mode"]) & ~0o222
        for record in release_directory_records(partial)
    }
    actual_directories = {
        record["path"]: int(record["mode"])
        for record in release_directory_records(final)
    }
    return (
        expected_files == actual_files
        and expected_directories == actual_directories
    )


def default_manifest(paths: ClavisPaths) -> dict[str, Any]:
    return {
        "schemaVersion": MANIFEST_SCHEMA,
        "installPrefix": str(paths.install_prefix),
        "activeRelease": "",
        "previousRelease": "",
        "releases": {},
        "launcher": None,
        "userUnits": [],
        "profiles": [],
        "exports": {},
        "systemIntegrations": {},
        "updatedAt": utc_now(),
    }


def load_manifest(paths: ClavisPaths) -> dict[str, Any]:
    if not paths.manifest.exists():
        return default_manifest(paths)
    try:
        value = json.loads(paths.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ClavisError(f"cannot read install manifest: {error}") from error
    if value.get("schemaVersion") != MANIFEST_SCHEMA:
        raise ClavisError("unsupported install manifest schema")
    if value.get("installPrefix") != str(paths.install_prefix):
        raise ClavisError("install manifest belongs to a different install prefix")
    return value


def read_release_metadata(root: Path) -> dict[str, Any]:
    metadata_path = root / "release.json"
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ClavisError(f"invalid release metadata at {metadata_path}: {error}") from error
    release = str(metadata.get("release", ""))
    release_key(release)
    protocols = metadata.get("protocols")
    if not isinstance(protocols, dict):
        raise ClavisError("release metadata has no protocol map")
    for name, required in REQUIRED_PROTOCOLS.items():
        if protocols.get(name) != required:
            raise ClavisError(
                f"release protocol {name!r} is {protocols.get(name)!r}, expected {required}"
            )
    schemas = metadata.get("dataSchemas")
    if not isinstance(schemas, dict):
        raise ClavisError("release metadata has no data schema map")
    for name, required in REQUIRED_DATA_SCHEMAS.items():
        if schemas.get(name) != required:
            raise ClavisError(
                f"release data schema {name!r} is {schemas.get(name)!r}, expected {required}"
            )
    return metadata


def validate_release(root: Path, expected_release: str | None = None) -> dict[str, Any]:
    if not root.is_dir() or root.is_symlink():
        raise ClavisError(f"release root is not a real directory: {root}")
    metadata = read_release_metadata(root)
    if expected_release is not None and metadata["release"] != expected_release:
        raise ClavisError(
            f"release metadata says {metadata['release']}, expected {expected_release}"
        )
    required = (
        root / "bin/key",
        root / "share/clavis/qml/shell.qml",
        root / "lib/qml/Clavis",
        root / "lib/qml/M3Shapes",
        root / "lib/qml/Clavis/Runtime/qmldir",
        root / "share/clavis/libexec/clavis-rapl-helper",
    )
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise ClavisError("incomplete release; missing: " + ", ".join(missing))
    if not os.access(root / "bin/key", os.X_OK):
        raise ClavisError("release key binary is not executable")
    return metadata


def resolve_active_release(paths: ClavisPaths) -> Path:
    current = paths.current_release
    if not current.is_symlink():
        raise ClavisError(f"no active release symlink at {current}")
    target = current.resolve(strict=True)
    releases = paths.releases_home.resolve(strict=True)
    if target.parent != releases:
        raise ClavisError(f"current release escapes the releases directory: {target}")
    validate_release(target)
    return target


def release_environment(paths: ClavisPaths, release_root: Path) -> dict[str, str]:
    result = os.environ.copy()
    result.update(paths.as_environment(release_root))
    metadata = read_release_metadata(release_root)
    result["CLAVIS_SHELL_RELEASE"] = metadata["release"]
    result["CLAVIS_SHELL_COMMIT"] = str(metadata.get("commit", "unknown"))
    return result


def executable(name: str) -> str:
    found = shutil.which(name)
    if found is None:
        raise ClavisError(f"required executable is missing: {name}")
    return found


def run_shell(paths: ClavisPaths, arguments: list[str]) -> int:
    release = resolve_active_release(paths)
    qml_root = release / "share/clavis/qml"
    command = [executable("qs"), "--path", str(qml_root), *arguments]
    os.execvpe(command[0], command, release_environment(paths, release))
    return 127


def run_ipc(paths: ClavisPaths, arguments: list[str]) -> int:
    if not arguments:
        raise ClavisError("key ipc requires a Quickshell IPC operation, such as `call`")
    release = resolve_active_release(paths)
    qml_root = release / "share/clavis/qml"
    command = [executable("qs"), "--path", str(qml_root), "ipc", *arguments]
    os.execvpe(command[0], command, release_environment(paths, release))
    return 127


def _existing_layers(candidates: list[Path]) -> list[Path]:
    return [path for path in candidates if path.is_file()]


def _write_generated(path: Path, text: str) -> None:
    atomic_write(path, text.encode())


def prepare_niri_profile(paths: ClavisPaths, release: Path) -> Path:
    base = release / "share/clavis/defaults/profiles/default/niri/base.kdl"
    generated_colors = paths.generated_home / "niri/colors.kdl"
    override = paths.config_home / "overrides/niri.kdl"
    session_config = paths.generated_home / "niri/session.kdl"
    lines = [
        "// Generated by Clavis; do not edit.\n",
        f'spawn-at-startup "{str(paths.stable_key).replace(chr(34), chr(92) + chr(34))}" "shell" "--no-duplicate"\n',
    ]
    for layer in _existing_layers(
        [
            base,
            generated_colors,
            paths.generated_home / "niri/cursor.kdl",
            paths.generated_home / "niri/clavis-effects.kdl",
            override,
        ]
    ):
        escaped = str(layer).replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'include "{escaped}"\n')
    _write_generated(session_config, "".join(lines))
    return session_config


def run_session(paths: ClavisPaths, arguments: list[str]) -> int:
    if os.environ.get("NIRI_SOCKET") or "niri" in (
        os.environ.get("XDG_CURRENT_DESKTOP", "")
        + ":"
        + os.environ.get("XDG_SESSION_DESKTOP", "")
    ).lower():
        raise ClavisError(
            "already inside a niri session; use `key shell` instead of nesting a session"
        )
    release = resolve_active_release(paths)
    config = prepare_niri_profile(paths, release)
    command = [executable("niri"), "--session", "--config", str(config), *arguments]
    environment = os.environ.copy()
    environment.update(
        {
            "CLAVIS_PROFILE": paths.profile_name,
            "CLAVIS_CONFIG_HOME": str(paths.config_home),
            "CLAVIS_DATA_HOME": str(paths.data_home),
            "CLAVIS_STATE_HOME": str(paths.state_home),
            "CLAVIS_CACHE_HOME": str(paths.cache_home),
            "CLAVIS_RUNTIME_HOME": str(paths.runtime_home),
            "NIRI_CONFIG": str(config),
        }
    )
    os.execvpe(command[0], command, environment)
    return 127


def _concatenate(paths_to_read: list[Path]) -> str:
    chunks = []
    for path in paths_to_read:
        if path.is_file():
            chunks.append(path.read_text(encoding="utf-8").rstrip() + "\n")
    return "\n".join(chunks)


def run_profile_application(
    paths: ClavisPaths, application: str, arguments: list[str]
) -> int:
    release = resolve_active_release(paths)
    defaults = release / "share/clavis/defaults/profiles/default"
    generated = paths.generated_home
    overrides = paths.config_home / "overrides"
    environment = release_environment(paths, release)

    if application == "kitty":
        command = [executable("kitty"), "--config", "NONE"]
        for layer in _existing_layers(
            [
                defaults / "kitty/kitty.conf",
                generated / "kitty/colors.conf",
                overrides / "kitty.conf",
            ]
        ):
            command += ["--config", str(layer)]
        command += arguments
    elif application == "btop":
        config = generated / "runtime/btop.conf"
        theme_dir = generated / "btop/themes"
        text = _concatenate(
            [defaults / "btop/btop.conf", overrides / "btop.conf"]
        )
        _write_generated(config, text)
        command = [
            executable("btop"),
            "--config",
            str(config),
            "--themes-dir",
            str(theme_dir),
            *arguments,
        ]
    elif application == "cava":
        config = generated / "runtime/cava.conf"
        text = _concatenate(
            [
                defaults / "cava/config",
                generated / "cava/colors.ini",
                overrides / "cava.conf",
            ]
        )
        _write_generated(config, text)
        command = [executable("cava"), "-p", str(config), *arguments]
    elif application == "yazi":
        config_dir = generated / "runtime/yazi"
        config_dir.mkdir(parents=True, exist_ok=True)
        for name, layers in {
            "yazi.toml": [defaults / "yazi/yazi.toml", overrides / "yazi/yazi.toml"],
            "theme.toml": [generated / "yazi/theme.toml", overrides / "yazi/theme.toml"],
            "keymap.toml": [overrides / "yazi/keymap.toml"],
        }.items():
            content = _concatenate(layers)
            if content:
                _write_generated(config_dir / name, content)
        environment["YAZI_CONFIG_HOME"] = str(config_dir)
        command = [executable("yazi"), *arguments]
    else:
        raise ClavisError(
            f"unsupported profile application {application!r}; expected kitty, btop, cava or yazi"
        )

    os.execvpe(command[0], command, environment)
    return 127


def _systemd_quote(path: Path) -> str:
    return '"' + str(path).replace("\\", "\\\\").replace('"', '\\"') + '"'


def user_unit_payloads(paths: ClavisPaths, release: Path) -> list[tuple[Path, bytes]]:
    source = release / "share/clavis/systemd/user"
    payloads = []
    for template in sorted(source.glob("*.service")):
        content = template.read_text(encoding="utf-8").replace(
            "@CLAVIS_KEY@", _systemd_quote(paths.stable_key)
        )
        destination = paths.user_systemd_home / template.name
        payloads.append((destination, content.encode()))
    return payloads


def install_user_units(payloads: list[tuple[Path, bytes]]) -> list[dict[str, Any]]:
    records = []
    for destination, content in payloads:
        atomic_write(destination, content)
        records.append(file_record(destination))
    return records


def reload_user_units() -> None:
    if os.environ.get("CLAVIS_SKIP_SYSTEMD") != "1" and shutil.which("systemctl"):
        subprocess.run(
            ["systemctl", "--user", "daemon-reload"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def _make_release_read_only(root: Path) -> None:
    for path in sorted(root.rglob("*"), reverse=True):
        if path.is_symlink():
            continue
        mode = stat.S_IMODE(path.stat().st_mode)
        path.chmod(mode & ~0o222)
    root.chmod(stat.S_IMODE(root.stat().st_mode) & ~0o222)


def _safe_partial(paths: ClavisPaths, partial: Path, release: str) -> None:
    expected = paths.releases_home / f"{release}.partial"
    if partial != expected:
        raise ClavisError(f"partial release must be exactly {expected}")


def finalize_install(
    paths: ClavisPaths, partial: Path, release: str, launcher_source: Path
) -> int:
    release_key(release)
    paths.releases_home.mkdir(parents=True, exist_ok=True)
    _safe_partial(paths, partial, release)
    metadata = validate_release(partial, release)
    smoke = subprocess.run(
        [str(partial / "bin/key"), "version", "--json"],
        check=False,
        capture_output=True,
        text=True,
        env={**os.environ, "CLAVIS_RELEASE_ROOT": str(partial)},
    )
    if smoke.returncode != 0:
        raise ClavisError(f"release smoke test failed: {smoke.stderr.strip()}")
    try:
        handshake = json.loads(smoke.stdout)
    except json.JSONDecodeError as error:
        raise ClavisError(f"release smoke test returned invalid JSON: {error}") from error
    if handshake.get("release") != release or handshake.get("commit") != metadata.get(
        "commit"
    ):
        raise ClavisError("release smoke test does not match release metadata")

    manifest = load_manifest(paths)
    launcher_bytes = launcher_source.read_bytes()
    unit_payloads = user_unit_payloads(paths, partial)
    launcher_record = manifest.get("launcher")
    _require_replaceable(
        paths.stable_key,
        launcher_bytes,
        launcher_record if isinstance(launcher_record, dict) else None,
    )
    old_unit_records = manifest.get("userUnits", [])
    if not isinstance(old_unit_records, list):
        old_unit_records = []
    for destination, content in unit_payloads:
        _require_replaceable(
            destination, content, _record_for_path(old_unit_records, destination)
        )
    if paths.current_release.exists() and not paths.current_release.is_symlink():
        raise ClavisError(
            f"install conflict at {paths.current_release}: expected a symlink"
        )

    final = paths.releases_home / release
    created_final = False
    if final.exists():
        installed_metadata = validate_release(final, release)
        if installed_metadata.get("commit") != metadata.get("commit"):
            raise ClavisError(
                f"immutable release {release} already exists with a different commit"
            )
        if installed_metadata.get("sourceFingerprint") != metadata.get(
            "sourceFingerprint"
        ):
            raise ClavisError(
                f"immutable release {release} already exists with different source contents"
            )
        if not _release_tree_matches_partial(final, partial):
            raise ClavisError(
                f"immutable release {release} differs from the freshly built release"
            )
        shutil.rmtree(partial)
    else:
        os.replace(partial, final)
        _make_release_read_only(final)
        created_final = True

    previous = str(manifest.get("activeRelease", ""))
    previous_root = paths.releases_home / previous if previous else None
    profile_dirs = [
        paths.config_home / "overrides",
        paths.data_home / "wallpapers",
        paths.profile_home / "generated",
        paths.state_home / "backups",
        paths.state_home / "migrations",
        paths.state_home / "update-history",
        paths.cache_home / "colors",
        paths.cache_home / "thumbnails",
        paths.cache_home / "temporary",
        paths.runtime_home / "session",
        paths.runtime_home / "locks",
        paths.runtime_home / "sockets",
    ]
    for directory in profile_dirs:
        directory.mkdir(parents=True, exist_ok=True)

    manifest["previousRelease"] = previous if previous != release else manifest.get(
        "previousRelease", ""
    )
    manifest["activeRelease"] = release
    manifest.setdefault("releases", {})[release] = {
        "path": str(final),
        "commit": metadata.get("commit", "unknown"),
        "sourceDirty": bool(metadata.get("sourceDirty", False)),
        "sourceFingerprint": metadata.get("sourceFingerprint", "unknown"),
        "installedAt": utc_now(),
        "protocols": metadata["protocols"],
        "dataSchemas": metadata["dataSchemas"],
        "files": release_file_records(final),
        "directories": release_directory_records(final),
    }
    profiles = manifest.setdefault("profiles", [])
    profile_record = {"name": paths.profile_name, "path": str(paths.profile_home)}
    if profile_record not in profiles:
        profiles.append(profile_record)
    manifest["updatedAt"] = utc_now()

    managed_paths = [
        paths.stable_key,
        *(destination for destination, _content in unit_payloads),
        paths.active_release_file,
        paths.manifest,
        paths.current_release,
    ]
    snapshots = {path: _snapshot_path(path) for path in managed_paths}
    try:
        atomic_write(paths.stable_key, launcher_bytes, 0o755)
        unit_records = install_user_units(unit_payloads)
        manifest["launcher"] = file_record(paths.stable_key)
        manifest["userUnits"] = unit_records
        atomic_write(paths.active_release_file, f"{release}\n".encode())
        atomic_json(paths.manifest, manifest)

        paths.install_prefix.mkdir(parents=True, exist_ok=True)
        temporary_link = paths.install_prefix / ".current.next"
        if temporary_link.exists() or temporary_link.is_symlink():
            temporary_link.unlink()
        temporary_link.symlink_to(Path("releases") / release)
        os.replace(temporary_link, paths.current_release)
    except Exception:
        for path in reversed(managed_paths):
            _restore_snapshot(path, snapshots[path])
        if created_final and final.is_dir() and not final.is_symlink():
            _make_tree_owner_writable(final)
            shutil.rmtree(final)
        reload_user_units()
        raise
    reload_user_units()
    restart_long_running(paths, previous_root)
    print(f"Installed Clavis {release} at {final}")
    print(f"Stable command: {paths.stable_key}")
    return 0


def _verify_record(root: Path, record: dict[str, Any]) -> bool:
    path = root / record["path"]
    return (
        path.is_file()
        and not path.is_symlink()
        and sha256(path) == record.get("sha256")
        and stat.S_IMODE(path.stat().st_mode) == record.get("mode")
    )


def _verify_directory(root: Path, record: dict[str, Any]) -> bool:
    path = root / record["path"]
    return (
        path.is_dir()
        and not path.is_symlink()
        and stat.S_IMODE(path.stat().st_mode) == record.get("mode")
    )


def verify_manifest_release(
    paths: ClavisPaths, release: str, manifest: dict[str, Any]
) -> Path:
    entry = manifest.get("releases", {}).get(release)
    if not isinstance(entry, dict):
        raise ClavisError(f"release {release} is not recorded in the install manifest")
    root = paths.releases_home / release
    metadata = validate_release(root, release)
    if metadata.get("commit") != entry.get("commit"):
        raise ClavisError(f"release {release} commit does not match the manifest")
    failures = [
        record["path"]
        for record in entry.get("files", [])
        if not _verify_record(root, record)
    ]
    failures.extend(
        record["path"]
        for record in entry.get("directories", [])
        if not _verify_directory(root, record)
    )
    if failures:
        raise ClavisError(
            f"release {release} failed integrity checks: " + ", ".join(failures[:5])
        )
    return root


def _service_is_active(name: str) -> bool:
    if os.environ.get("CLAVIS_SKIP_SYSTEMD") == "1" or not shutil.which("systemctl"):
        return False
    result = subprocess.run(
        ["systemctl", "--user", "is-active", "--quiet", name], check=False
    )
    return result.returncode == 0


def restart_long_running(paths: ClavisPaths, old_root: Path | None) -> None:
    active_services = {name: _service_is_active(name) for name in MANAGED_SERVICES}
    qs = shutil.which("qs")
    manual_shell_running = False
    if qs and old_root is not None:
        old_qml = old_root / "share/clavis/qml"
        listed = subprocess.run(
            [qs, "list", "--json", "--path", str(old_qml)],
            check=False,
            capture_output=True,
            text=True,
        )
        try:
            manual_shell_running = bool(json.loads(listed.stdout or "[]"))
        except json.JSONDecodeError:
            manual_shell_running = False
        if manual_shell_running:
            subprocess.run([qs, "kill", "--path", str(old_qml)], check=False)

    for name, active in active_services.items():
        if active:
            subprocess.run(["systemctl", "--user", "restart", name], check=False)
    if manual_shell_running and not active_services["clavis-shell.service"]:
        subprocess.Popen(
            [str(paths.stable_key), "shell", "--no-duplicate"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )


def rollback(paths: ClavisPaths, requested: str | None, dry_run: bool) -> int:
    manifest = load_manifest(paths)
    current_name = str(manifest.get("activeRelease", ""))
    if not current_name:
        raise ClavisError("no active release is recorded")
    target_name = requested or str(manifest.get("previousRelease", ""))
    if not target_name:
        candidates = [
            name for name in manifest.get("releases", {}) if name != current_name
        ]
        candidates.sort(key=release_key, reverse=True)
        if not candidates:
            raise ClavisError("no previous release is available")
        target_name = candidates[0]
    release_key(target_name)
    target = verify_manifest_release(paths, target_name, manifest)
    old_root = verify_manifest_release(paths, current_name, manifest)
    target_schemas = read_release_metadata(target).get("dataSchemas", {})
    current_schemas = read_release_metadata(old_root).get("dataSchemas", {})
    if target_schemas != current_schemas:
        raise ClavisError(
            "rollback refused because the target release uses incompatible mutable data schemas"
        )
    if dry_run:
        print(f"Would switch {current_name} -> {target_name}")
        return 0

    temporary_link = paths.install_prefix / ".current.next"
    if temporary_link.exists() or temporary_link.is_symlink():
        temporary_link.unlink()
    temporary_link.symlink_to(Path("releases") / target_name)
    os.replace(temporary_link, paths.current_release)
    manifest["activeRelease"] = target_name
    manifest["previousRelease"] = current_name
    manifest["updatedAt"] = utc_now()
    atomic_write(paths.active_release_file, f"{target_name}\n".encode())
    atomic_json(paths.manifest, manifest)
    restart_long_running(paths, old_root)
    print(f"Rolled back Clavis {current_name} -> {target_name}")
    return 0


def release_command(
    paths: ClavisPaths,
    action: str,
    requested: str | None,
    dry_run: bool,
    json_output: bool,
) -> int:
    manifest = load_manifest(paths)
    releases = manifest.get("releases", {})
    if action == "list":
        ordered = sorted(releases, key=release_key, reverse=True)
        result = {
            "activeRelease": manifest.get("activeRelease", ""),
            "previousRelease": manifest.get("previousRelease", ""),
            "releases": [
                {
                    "release": name,
                    "commit": releases[name].get("commit", "unknown"),
                    "active": name == manifest.get("activeRelease"),
                }
                for name in ordered
            ],
        }
        if json_output:
            print(json.dumps(result, separators=(",", ":")))
        else:
            for entry in result["releases"]:
                marker = "*" if entry["active"] else " "
                print(f"{marker} {entry['release']}  {entry['commit']}")
        return 0

    if requested is None:
        raise ClavisError("release remove requires a release name")
    release_key(requested)
    if requested == manifest.get("activeRelease"):
        raise ClavisError("refusing to remove the active release; roll back first")
    root = verify_manifest_release(paths, requested, manifest)
    entry = releases[requested]
    recorded_paths = {
        str(Path(record["path"])) for record in entry.get("files", [])
    }
    owned_directories = _release_owned_directories(entry)
    unknown = [
        path
        for path in root.rglob("*")
        if str(path.relative_to(root))
        not in (recorded_paths | owned_directories)
    ]
    if unknown:
        raise ClavisError(
            "release contains unrecorded entries and was preserved: "
            + ", ".join(str(path) for path in unknown[:5])
        )
    if dry_run:
        print(f"Would remove verified immutable release {requested} at {root}")
        return 0

    _make_tree_owner_writable(root)
    for record in reversed(entry.get("files", [])):
        path = root / record["path"]
        if path.is_file() and not path.is_symlink():
            path.unlink()
    for relative in sorted(
        owned_directories,
        key=lambda value: len(Path(value).parts),
        reverse=True,
    ):
        (root / relative).rmdir()
    root.rmdir()
    del releases[requested]
    if manifest.get("previousRelease") == requested:
        candidates = sorted(
            (name for name in releases if name != manifest.get("activeRelease")),
            key=release_key,
            reverse=True,
        )
        manifest["previousRelease"] = candidates[0] if candidates else ""
    manifest["updatedAt"] = utc_now()
    atomic_json(paths.manifest, manifest)
    print(f"Removed Clavis release {requested}")
    return 0


def _remove_recorded_file(record: dict[str, Any], dry_run: bool) -> tuple[bool, str]:
    path = Path(record["path"])
    if not path.exists() and not path.is_symlink():
        return True, "missing"
    if not path.is_file() or path.is_symlink():
        return False, "not a regular file"
    if sha256(path) != record.get("sha256"):
        return False, "modified"
    if not dry_run:
        path.unlink()
    return True, "removed"


def _remove_empty_parents(path: Path, stop: Path) -> None:
    current = path
    while current != stop and stop in current.parents:
        try:
            current.rmdir()
        except OSError:
            break
        current = current.parent


def _make_tree_owner_writable(root: Path) -> None:
    if not root.is_dir() or root.is_symlink():
        return
    for path in [
        root,
        *(
            item
            for item in root.rglob("*")
            if item.is_dir() and not item.is_symlink()
        ),
    ]:
        mode = stat.S_IMODE(path.stat().st_mode)
        path.chmod(mode | stat.S_IWUSR | stat.S_IXUSR)


def _make_owned_directories_writable(
    root: Path, relative_directories: set[str]
) -> None:
    if not root.is_dir() or root.is_symlink():
        return
    root.chmod(stat.S_IMODE(root.stat().st_mode) | stat.S_IWUSR | stat.S_IXUSR)
    for relative in relative_directories:
        path = root / relative
        if path.is_dir() and not path.is_symlink():
            path.chmod(
                stat.S_IMODE(path.stat().st_mode) | stat.S_IWUSR | stat.S_IXUSR
            )


def _validate_purge_root(paths: ClavisPaths, target: Path, label: str) -> None:
    if not target.is_absolute():
        raise ClavisError(f"refusing to purge non-absolute {label} path: {target}")
    normalized = Path(os.path.normpath(target))
    dangerous = {
        Path("/"),
        paths.home,
        paths.install_prefix,
        paths.bin_home,
    }
    if normalized in dangerous or len(normalized.parts) < 3:
        raise ClavisError(f"refusing to purge unsafe {label} path: {target}")
    if target.is_symlink():
        raise ClavisError(f"refusing to purge symlinked {label} path: {target}")


def uninstall(
    paths: ClavisPaths,
    dry_run: bool,
    purge_cache: bool,
    purge_config: bool,
    purge_data: bool,
) -> int:
    manifest = load_manifest(paths)
    for enabled, target, label in (
        (purge_cache, paths.cache_home, "cache"),
        (purge_config, paths.config_home, "config"),
        (purge_data, paths.data_home, "data"),
    ):
        if enabled:
            _validate_purge_root(paths, target, label)
    if "cpuPower" in manifest.get("systemIntegrations", {}):
        raise ClavisError(
            "CPU power integration is still installed; run `key setup cpu-power "
            "--disable` first so its separate authorization is explicit"
        )
    preserved: list[dict[str, Any]] = []

    def preserve_file(
        path: Path,
        reason: str,
        *,
        owned: bool,
        expected_sha256: str | None = None,
        restoration: dict[str, Any] | None = None,
    ) -> None:
        record: dict[str, Any] = {
            "kind": "file",
            "path": str(path),
            "reason": reason,
            "owned": owned,
        }
        if expected_sha256:
            record["expectedSha256"] = expected_sha256
        if restoration:
            record.update(restoration)
        preserved.append(record)

    def preserve_setting(
        schema: str,
        key: str,
        reason: str,
        *,
        original: str,
        applied: str,
    ) -> None:
        preserved.append(
            {
                "kind": "gsettings",
                "schema": schema,
                "key": key,
                "reason": reason,
                "original": original,
                "applied": applied,
            }
        )

    for record in manifest.get("preservedItems", []):
        if not isinstance(record, dict):
            continue
        if record.get("kind") == "gsettings":
            schema = str(record.get("schema", ""))
            key = str(record.get("key", ""))
            original = str(record.get("original", ""))
            applied = str(record.get("applied", ""))
            if shutil.which("gsettings") is None:
                preserve_setting(
                    schema,
                    key,
                    "gsettings unavailable",
                    original=original,
                    applied=applied,
                )
            elif _gsettings_get(schema, key) != applied:
                preserve_setting(
                    schema,
                    key,
                    "modified",
                    original=original,
                    applied=applied,
                )
            elif not dry_run:
                result = subprocess.run(
                    ["gsettings", "set", schema, key, original], check=False
                )
                if result.returncode != 0:
                    preserve_setting(
                        schema,
                        key,
                        "restore failed",
                        original=original,
                        applied=applied,
                    )
            continue
        if record.get("kind") != "file":
            continue
        path_value = record.get("path")
        if not isinstance(path_value, str) or not path_value:
            continue
        path = Path(path_value)
        if not path.exists() and not path.is_symlink():
            continue
        expected = record.get("expectedSha256")
        restoration = {
            name: record[name]
            for name in ("action", "backupPath", "originalSha256")
            if name in record
        }
        if record.get("action") == "restore-backup":
            backup_value = record.get("backupPath")
            backup = Path(backup_value) if isinstance(backup_value, str) else None
            if (not path.is_file() or path.is_symlink()
                    or not isinstance(expected, str) or sha256(path) != expected):
                preserve_file(
                    path,
                    "modified",
                    owned=True,
                    expected_sha256=expected if isinstance(expected, str) else None,
                    restoration=restoration,
                )
            elif (backup is None or not backup.is_file()
                    or sha256(backup) != record.get("originalSha256")):
                preserve_file(
                    path,
                    "backup invalid",
                    owned=True,
                    expected_sha256=expected,
                    restoration=restoration,
                )
            elif not dry_run:
                atomic_write(
                    path,
                    backup.read_bytes(),
                    stat.S_IMODE(backup.stat().st_mode),
                )
            continue
        if record.get("owned") is True and isinstance(expected, str):
            removed, reason = _remove_recorded_file(
                {"path": str(path), "sha256": expected}, dry_run
            )
            if removed:
                if not dry_run:
                    _remove_empty_parents(path.parent, paths.install_prefix)
                continue
            preserve_file(
                path,
                reason,
                owned=True,
                expected_sha256=expected,
                restoration=restoration,
            )
        else:
            preserved.append(record)
    if dry_run:
        print(f"Would remove Clavis program files recorded in {paths.manifest}")
    else:
        for service in MANAGED_SERVICES:
            if (os.environ.get("CLAVIS_SKIP_SYSTEMD") != "1"
                    and shutil.which("systemctl")):
                subprocess.run(
                    ["systemctl", "--user", "disable", "--now", service], check=False
                )

    for record in manifest.get("userUnits", []):
        removed, reason = _remove_recorded_file(record, dry_run)
        if not removed:
            preserve_file(
                Path(record["path"]),
                reason,
                owned=True,
                expected_sha256=record.get("sha256"),
            )
    launcher = manifest.get("launcher")
    if isinstance(launcher, dict):
        removed, reason = _remove_recorded_file(launcher, dry_run)
        if not removed:
            preserve_file(
                Path(launcher["path"]),
                reason,
                owned=True,
                expected_sha256=launcher.get("sha256"),
            )

    for release, entry in manifest.get("releases", {}).items():
        root = paths.releases_home / release
        recorded_paths = {
            str(Path(record["path"]))
            for record in entry.get("files", [])
            if isinstance(record, dict) and isinstance(record.get("path"), str)
        }
        owned_directories = _release_owned_directories(entry)
        for path in root.rglob("*"):
            relative = str(path.relative_to(root))
            if relative in recorded_paths or relative in owned_directories:
                continue
            preserve_file(
                path,
                "unrecorded-directory"
                if path.is_dir() and not path.is_symlink()
                else "unrecorded",
                owned=False,
            )
        if not dry_run:
            _make_owned_directories_writable(root, owned_directories)
        for record in reversed(entry.get("files", [])):
            absolute_record = dict(record)
            absolute_record["path"] = str(root / record["path"])
            removed, reason = _remove_recorded_file(absolute_record, dry_run)
            if not removed:
                preserve_file(
                    Path(absolute_record["path"]),
                    reason,
                    owned=True,
                    expected_sha256=record.get("sha256"),
                )
        if not dry_run:
            for relative in sorted(
                owned_directories,
                key=lambda value: len(Path(value).parts),
                reverse=True,
            ):
                try:
                    (root / relative).rmdir()
                except OSError:
                    pass
            try:
                root.rmdir()
            except OSError:
                pass

    for application, export in manifest.get("exports", {}).items():
        if not isinstance(export, dict):
            continue
        if application == "desktop":
            if shutil.which("gsettings") is None:
                for record in export.get("settings", []):
                    preserve_setting(
                        str(record.get("schema", "")),
                        str(record.get("key", "")),
                        "gsettings unavailable",
                        original=str(record.get("original", "")),
                        applied=str(record.get("applied", "")),
                    )
                continue
            for record in export.get("settings", []):
                schema = record.get("schema", "")
                key = record.get("key", "")
                current = _gsettings_get(schema, key)
                if current != record.get("applied"):
                    preserve_setting(
                        schema,
                        key,
                        "modified",
                        original=str(record.get("original", "")),
                        applied=str(record.get("applied", "")),
                    )
                    continue
                if not dry_run:
                    result = subprocess.run(
                        ["gsettings", "set", schema, key, str(record.get("original", ""))],
                        check=False,
                    )
                    if result.returncode != 0:
                        preserve_setting(
                            schema,
                            key,
                            "restore failed",
                            original=str(record.get("original", "")),
                            applied=str(record.get("applied", "")),
                        )
            continue
        for record in export.get("files", []):
            if not isinstance(record, dict) or record.get("owned") is not True:
                continue
            target = Path(record["path"])
            if not target.exists():
                continue
            if (not target.is_file() or target.is_symlink()
                    or sha256(target) != record.get("sha256")):
                preserve_file(
                    target,
                    "modified",
                    owned=True,
                    expected_sha256=record.get("sha256"),
                    restoration={
                        "action": (
                            "restore-backup"
                            if record.get("originalExisted")
                            else "delete"
                        ),
                        "backupPath": record.get("backupPath", ""),
                        "originalSha256": record.get("originalSha256", ""),
                    },
                )
                continue
            if record.get("originalExisted"):
                backup_value = record.get("backupPath")
                backup = Path(backup_value) if backup_value else None
                if (backup is None or not backup.is_file()
                        or sha256(backup) != record.get("originalSha256")):
                    preserve_file(
                        target,
                        "backup invalid",
                        owned=True,
                        expected_sha256=record.get("sha256"),
                        restoration={
                            "action": "restore-backup",
                            "backupPath": record.get("backupPath", ""),
                            "originalSha256": record.get("originalSha256", ""),
                        },
                    )
                    continue
                if not dry_run:
                    atomic_write(
                        target,
                        backup.read_bytes(),
                        stat.S_IMODE(backup.stat().st_mode),
                    )
            elif not dry_run:
                target.unlink()

    if not dry_run:
        if paths.current_release.is_symlink():
            paths.current_release.unlink()
        if paths.active_release_file.exists():
            paths.active_release_file.unlink()
        if purge_cache and paths.cache_home.exists():
            shutil.rmtree(paths.cache_home)
        if purge_config and paths.config_home.exists():
            shutil.rmtree(paths.config_home)
        if purge_data and paths.data_home.exists():
            shutil.rmtree(paths.data_home)
        preserved = [
            record
            for record in preserved
            if record.get("kind") != "file"
            or Path(str(record.get("path", ""))).exists()
            or Path(str(record.get("path", ""))).is_symlink()
        ]
        if preserved:
            manifest["activeRelease"] = ""
            manifest["previousRelease"] = ""
            manifest["releases"] = {}
            manifest["launcher"] = None
            manifest["userUnits"] = []
            manifest["exports"] = {}
            manifest["preservedItems"] = preserved
            manifest["updatedAt"] = utc_now()
            atomic_json(paths.manifest, manifest)
        elif paths.manifest.exists():
            paths.manifest.unlink()

    if preserved:
        print("Preserved files that were modified or not regular files:")
        for item in preserved:
            if item.get("kind") == "file":
                print(f"  {item.get('path')} ({item.get('reason', 'preserved')})")
            else:
                print(
                    f"  gsettings://{item.get('schema', '')}/{item.get('key', '')} "
                    f"({item.get('reason', 'preserved')})"
                )
    print("Dry run complete." if dry_run else "Clavis program uninstall complete.")
    return 0


def legacy_report(paths: ClavisPaths) -> dict[str, Any]:
    xdg_config = Path(os.environ.get("XDG_CONFIG_HOME", paths.home / ".config"))
    xdg_data = Path(os.environ.get("XDG_DATA_HOME", paths.home / ".local/share"))
    old_cache = paths.home / ".cache/quickshell"
    candidates = [
        ("source_checkout", paths.home / ".config/quickshell"),
        ("system_key", Path("/usr/local/bin/key")),
        ("system_qml_clavis_lib64", Path("/usr/lib64/qt6/qml/Clavis")),
        ("system_qml_shapes_lib64", Path("/usr/lib64/qt6/qml/M3Shapes")),
        ("system_qml_clavis_lib", Path("/usr/lib/qt6/qml/Clavis")),
        ("system_qml_shapes_lib", Path("/usr/lib/qt6/qml/M3Shapes")),
        ("user_unit", xdg_config / "systemd/user/clavis-cliphist.service"),
        ("legacy_settings", old_cache / "personalization.json"),
        ("legacy_state", old_cache),
        ("legacy_matugen", paths.home / ".cache/quickshell-dev-colorscheme"),
        ("legacy_niri_colors", xdg_config / "niri/colors.kdl"),
        ("legacy_kitty_colors", xdg_config / "kitty/themes/Matugen.conf"),
        ("legacy_btop_theme", xdg_config / "btop/themes/matugen.theme"),
        ("legacy_cava_theme", xdg_config / "cava/themes/matugen"),
        ("legacy_yazi_theme", xdg_config / "yazi/theme.toml"),
        ("legacy_fcitx5_theme", xdg_data / "fcitx5/themes/Matugen"),
    ]
    entries = []
    for kind, path in candidates:
        entries.append(
            {
                "kind": kind,
                "path": str(path),
                "exists": path.exists() or path.is_symlink(),
                "ownership": "unknown" if path.exists() else "absent",
            }
        )
    return {
        "schemaVersion": 1,
        "command": "doctor legacy",
        "ok": True,
        "entries": entries,
        "note": "No legacy path is deleted automatically.",
    }


def _systemd_service_properties(name: str) -> dict[str, str]:
    if (os.environ.get("CLAVIS_SKIP_SYSTEMD") == "1"
            or shutil.which("systemctl") is None):
        return {}
    result = subprocess.run(
        [
            "systemctl",
            "--user",
            "show",
            name,
            "--property=LoadState,ActiveState,MainPID,FragmentPath",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return {}
    properties: dict[str, str] = {}
    for line in result.stdout.splitlines():
        key, separator, value = line.partition("=")
        if separator:
            properties[key] = value
    return properties


def _process_clavis_release(pid_text: str) -> str:
    try:
        pid = int(pid_text)
    except ValueError:
        return ""
    if pid <= 0:
        return ""
    try:
        entries = Path(f"/proc/{pid}/environ").read_bytes().split(b"\0")
    except OSError:
        return ""
    prefix = b"CLAVIS_RELEASE_ROOT="
    for entry in entries:
        if entry.startswith(prefix):
            return entry[len(prefix) :].decode(errors="replace")
    return ""


def services_report(paths: ClavisPaths) -> dict[str, Any]:
    active_release = ""
    if paths.current_release.is_symlink():
        try:
            active_release = str(paths.current_release.resolve(strict=True))
        except OSError:
            active_release = ""
    services = []
    ok = True
    for name in MANAGED_SERVICES:
        properties = _systemd_service_properties(name)
        configured_path = paths.user_systemd_home / name
        fragment = Path(properties.get("FragmentPath") or configured_path)
        try:
            content = fragment.read_text(encoding="utf-8")
        except OSError:
            content = ""
        stable_entry = str(paths.stable_key) in content
        legacy_entry = "/usr/local/bin/key" in content
        runtime_release = _process_clavis_release(properties.get("MainPID", "0"))
        stale_runtime = bool(
            runtime_release
            and active_release
            and Path(runtime_release).resolve() != Path(active_release).resolve()
        )
        unit_ok = bool(content) and stable_entry and not legacy_entry and not stale_runtime
        ok = ok and unit_ok
        services.append(
            {
                "name": name,
                "loadState": properties.get("LoadState", "unknown"),
                "activeState": properties.get("ActiveState", "unknown"),
                "mainPid": int(properties.get("MainPID", "0") or 0),
                "fragmentPath": str(fragment),
                "stableEntry": stable_entry,
                "legacyEntry": legacy_entry,
                "runtimeRelease": runtime_release,
                "staleRuntime": stale_runtime,
                "ok": unit_ok,
            }
        )
    return {
        "schemaVersion": 1,
        "command": "doctor services",
        "ok": ok,
        "activeReleasePath": active_release,
        "services": services,
        "note": (
            "The clipboard watcher resolves key through the stable launcher for every "
            "event; a running shell also exposes CLAVIS_RELEASE_ROOT for stale-process checks."
        ),
    }


def migrate_legacy(paths: ClavisPaths, dry_run: bool) -> int:
    legacy = paths.home / ".cache/quickshell"
    mappings = {
        legacy / "personalization.json": paths.config_home / "config.json",
        legacy / "ui-preferences.json": paths.config_home / "ui-preferences.json",
        legacy / "quick-toggles.json": paths.config_home / "quick-toggles.json",
        legacy / "tray.json": paths.config_home / "tray.json",
        legacy / "idle-policy.json": paths.config_home / "idle-policy.json",
    }
    actions = []
    for source, destination in mappings.items():
        if not source.is_file():
            continue
        if destination.exists():
            actions.append(
                {"source": str(source), "destination": str(destination), "result": "conflict"}
            )
            continue
        actions.append(
            {"source": str(source), "destination": str(destination), "result": "would-copy" if dry_run else "copied"}
        )
        if not dry_run:
            atomic_write(destination, source.read_bytes(), stat.S_IMODE(source.stat().st_mode))
    report = {
        "schemaVersion": 1,
        "createdAt": utc_now(),
        "dryRun": dry_run,
        "actions": actions,
        "legacy": legacy_report(paths),
    }
    if not dry_run:
        report_path = paths.state_home / "migrations" / f"legacy-{dt.datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
        atomic_json(report_path, report)
        print(f"Migration report: {report_path}")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


def update_command(paths: ClavisPaths, artifact: str | None) -> int:
    if artifact is None:
        raise ClavisError(
            "online updates are not enabled: no signed artifact provider is configured; install a local source release with ./setup.sh install"
        )
    raise ClavisError(
        "artifact installation is reserved until release signatures and archive traversal checks are available; the current release was not changed"
    )


def _external_xdg_base(variable: str, fallback: Path) -> Path:
    value = os.environ.get(variable, "").strip()
    if not value:
        return fallback
    path = Path(value)
    if not path.is_absolute():
        raise ClavisError(f"{variable} must be an absolute path: {value}")
    return path


DESKTOP_SETTINGS = {
    "iconTheme": ("org.gnome.desktop.interface", "icon-theme"),
    "cursorTheme": ("org.gnome.desktop.interface", "cursor-theme"),
    "cursorSize": ("org.gnome.desktop.interface", "cursor-size"),
    "colorScheme": ("org.gnome.desktop.interface", "color-scheme"),
}


def _gsettings_get(schema: str, key: str) -> str:
    result = subprocess.run(
        ["gsettings", "get", schema, key],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ClavisError(
            f"cannot read gsettings {schema} {key}: {result.stderr.strip()}"
        )
    return result.stdout.strip()


def desktop_export_status(paths: ClavisPaths) -> dict[str, Any]:
    manifest = load_manifest(paths)
    installed = shutil.which("gsettings") is not None
    record = manifest.get("exports", {}).get("desktop")
    files = [
        {
            "source": "Clavis personalization settings",
            "target": f"gsettings://{schema}/{key}",
            "sourceReady": True,
            "targetExists": installed,
        }
        for schema, key in DESKTOP_SETTINGS.values()
    ]
    return {
        "application": "desktop",
        "installed": installed,
        "executable": "gsettings",
        "files": files,
        "managed": isinstance(record, dict),
        "note": (
            "Desktop settings are explicit opt-in. Original GVariant values are "
            "recorded and are restored only while exported values remain unchanged."
        ),
    }


def enable_desktop_export(
    paths: ClavisPaths,
    values: dict[str, str | int | None],
    replace: bool,
    dry_run: bool,
    json_output: bool,
) -> int:
    if shutil.which("gsettings") is None:
        raise ClavisError("target program is not installed: gsettings")
    if not values.get("iconTheme") or not values.get("cursorTheme"):
        raise ClavisError("desktop export requires resolved icon and cursor themes")
    cursor_size = int(values.get("cursorSize") or 0)
    if cursor_size < 12 or cursor_size > 128:
        raise ClavisError("desktop cursor size must be between 12 and 128")
    if values.get("colorScheme") not in {"default", "prefer-dark"}:
        raise ClavisError("desktop color scheme must be default or prefer-dark")
    desired = {
        "iconTheme": str(values["iconTheme"]),
        "cursorTheme": str(values["cursorTheme"]),
        "cursorSize": cursor_size,
        "colorScheme": str(values["colorScheme"]),
    }
    for name in ("iconTheme", "cursorTheme", "colorScheme"):
        if "\0" in str(desired[name]):
            raise ClavisError(f"desktop setting {name} contains an invalid NUL")

    manifest = load_manifest(paths)
    previous = manifest.get("exports", {}).get("desktop")
    previous_settings = {
        item.get("name"): item
        for item in previous.get("settings", [])
        if isinstance(previous, dict) and isinstance(item, dict)
    } if isinstance(previous, dict) else {}
    planned = []
    for name, (schema, key) in DESKTOP_SETTINGS.items():
        current = _gsettings_get(schema, key)
        old = previous_settings.get(name)
        if old and current != old.get("applied") and not replace:
            raise ClavisError(
                f"export conflict at gsettings://{schema}/{key}; the user value "
                "changed after export, rerun with --replace to accept a new backup"
            )
        planned.append(
            {
                "name": name,
                "target": f"gsettings://{schema}/{key}",
                "current": current,
                "value": desired[name],
            }
        )
    if dry_run:
        result = {"ok": True, "dryRun": True, "application": "desktop", "settings": planned}
        print(json.dumps(result, separators=(",", ":")) if json_output else json.dumps(result, indent=2))
        return 0

    records = []
    try:
        for item in planned:
            schema, key = DESKTOP_SETTINGS[item["name"]]
            value = str(item["value"])
            result = subprocess.run(
                ["gsettings", "set", schema, key, value],
                check=False,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                raise ClavisError(
                    f"cannot set gsettings {schema} {key}: {result.stderr.strip()}"
                )
            records.append(
                {
                    "name": item["name"],
                    "schema": schema,
                    "key": key,
                    "original": item["current"],
                    "applied": _gsettings_get(schema, key),
                }
            )
        manifest.setdefault("exports", {})["desktop"] = {
            "application": "desktop",
            "enabledAt": utc_now(),
            "settings": records,
            "note": desktop_export_status(paths)["note"],
        }
        manifest["updatedAt"] = utc_now()
        atomic_json(paths.manifest, manifest)
    except (ClavisError, OSError, ValueError):
        for record in reversed(records):
            subprocess.run(
                [
                    "gsettings",
                    "set",
                    record["schema"],
                    record["key"],
                    str(record["original"]),
                ],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        raise
    result = {"ok": True, "application": "desktop", "settings": records}
    print(json.dumps(result, separators=(",", ":")) if json_output else "Exported desktop settings.")
    return 0


def disable_desktop_export(
    paths: ClavisPaths, dry_run: bool, json_output: bool
) -> int:
    manifest = load_manifest(paths)
    export = manifest.get("exports", {}).get("desktop")
    if not isinstance(export, dict):
        raise ClavisError("no managed export is recorded for desktop")
    actions = []
    all_clean = True
    changed: list[dict[str, str]] = []
    try:
        for record in export.get("settings", []):
            schema = record["schema"]
            key = record["key"]
            current = _gsettings_get(schema, key)
            if current != record.get("applied"):
                actions.append({"target": f"gsettings://{schema}/{key}", "action": "preserve-modified"})
                all_clean = False
                continue
            actions.append({"target": f"gsettings://{schema}/{key}", "action": "restore-original"})
            if not dry_run:
                result = subprocess.run(
                    ["gsettings", "set", schema, key, str(record["original"])],
                    check=False,
                    capture_output=True,
                    text=True,
                )
                if result.returncode != 0:
                    raise ClavisError(
                        f"cannot restore gsettings {schema} {key}: {result.stderr.strip()}"
                    )
                changed.append(
                    {"schema": schema, "key": key, "value": current}
                )
        if not dry_run:
            if all_clean:
                del manifest["exports"]["desktop"]
            else:
                export["disabledWithModifiedSettings"] = True
            manifest["updatedAt"] = utc_now()
            atomic_json(paths.manifest, manifest)
    except (ClavisError, OSError, ValueError):
        for item in reversed(changed):
            subprocess.run(
                ["gsettings", "set", item["schema"], item["key"], item["value"]],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        raise
    result = {"ok": all_clean, "dryRun": dry_run, "application": "desktop", "actions": actions}
    print(json.dumps(result, separators=(",", ":")) if json_output else json.dumps(result, indent=2))
    return 0 if all_clean else 1


def export_adapter(
    paths: ClavisPaths, application: str
) -> tuple[str, list[tuple[Path, Path]], str]:
    config = _external_xdg_base("XDG_CONFIG_HOME", paths.home / ".config")
    data = _external_xdg_base("XDG_DATA_HOME", paths.home / ".local/share")
    generated = paths.generated_home
    adapters: dict[str, tuple[str, list[tuple[Path, Path]], str]] = {
        "kitty": (
            "kitty",
            [(generated / "kitty/colors.conf", config / "kitty/themes/Clavis.conf")],
            "Add `include themes/Clavis.conf` to kitty.conf if it is not already included.",
        ),
        "btop": (
            "btop",
            [(generated / "btop/themes/clavis.theme", config / "btop/themes/clavis.theme")],
            "Select `clavis` as btop's color_theme.",
        ),
        "cava": (
            "cava",
            [(generated / "cava/colors.ini", config / "cava/themes/clavis")],
            "Reference the exported theme from the user's Cava configuration.",
        ),
        "niri": (
            "niri",
            [(generated / "niri/colors.kdl", config / "niri/clavis-colors.kdl")],
            "Include `clavis-colors.kdl` from the user's niri config.",
        ),
        "yazi": (
            "yazi",
            [(generated / "yazi/theme.toml", config / "yazi/theme.toml")],
            "Yazi reads theme.toml directly; an existing file requires --replace.",
        ),
        "zsh_prompt": (
            "zsh",
            [(generated / "zsh/prompt-colors.zsh", config / "zsh/clavis-colors.zsh")],
            "Source clavis-colors.zsh explicitly from the user's Zsh configuration.",
        ),
        "fcitx5": (
            "fcitx5",
            [
                (
                    generated / "fcitx5/Matugen/theme.conf",
                    data / "fcitx5/themes/Clavis/theme.conf",
                ),
                (
                    generated / "fcitx5/Matugen/panel.svg",
                    data / "fcitx5/themes/Clavis/panel.svg",
                ),
                (
                    generated / "fcitx5/Matugen/highlight.svg",
                    data / "fcitx5/themes/Clavis/highlight.svg",
                ),
            ],
            "Fcitx5 is a shared session service; selecting this theme is not profile-isolated.",
        ),
    }
    if application not in adapters:
        raise ClavisError(
            f"unsupported export adapter {application!r}; expected "
            + ", ".join(sorted(adapters))
        )
    return adapters[application]


def export_status(paths: ClavisPaths, application: str) -> dict[str, Any]:
    if application == "desktop":
        return desktop_export_status(paths)
    executable_name, files, note = export_adapter(paths, application)
    manifest = load_manifest(paths)
    record = manifest.get("exports", {}).get(application)
    return {
        "application": application,
        "installed": shutil.which(executable_name) is not None,
        "executable": executable_name,
        "files": [
            {
                "source": str(source),
                "target": str(target),
                "sourceReady": source.is_file(),
                "targetExists": target.exists(),
            }
            for source, target in files
        ],
        "managed": isinstance(record, dict),
        "note": note,
    }


def _backup_target(paths: ClavisPaths, application: str, target: Path) -> Path:
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    safe_name = hashlib.sha256(str(target).encode()).hexdigest()[:12] + "-" + target.name
    backup_parent = paths.state_home / "backups/exports" / application
    backup_parent.mkdir(parents=True, exist_ok=True)
    unique = Path(tempfile.mkdtemp(prefix=f"{stamp}-", dir=backup_parent))
    backup = unique / safe_name
    atomic_write(backup, target.read_bytes(), stat.S_IMODE(target.stat().st_mode))
    return backup


def _reload_export(application: str) -> None:
    commands: dict[str, list[str]] = {
        "btop": ["pkill", "-USR2", "-x", "btop"],
        "cava": ["pkill", "-USR1", "-x", "cava"],
        "niri": ["niri", "msg", "action", "load-config-file"],
        "fcitx5": [
            "busctl",
            "--user",
            "call",
            "org.fcitx.Fcitx5",
            "/controller",
            "org.fcitx.Fcitx.Controller1",
            "ReloadAddonConfig",
            "s",
            "classicui",
        ],
    }
    command = commands.get(application)
    if command and shutil.which(command[0]):
        subprocess.run(
            command,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def enable_export(
    paths: ClavisPaths,
    application: str,
    replace: bool,
    dry_run: bool,
    json_output: bool,
    desktop_values: dict[str, str | int | None] | None = None,
) -> int:
    if application == "desktop":
        return enable_desktop_export(
            paths, desktop_values or {}, replace, dry_run, json_output
        )
    status = export_status(paths, application)
    if not status["installed"]:
        raise ClavisError(f"target program is not installed: {status['executable']}")
    manifest = load_manifest(paths)
    old_export = manifest.get("exports", {}).get(application, {})
    old_by_path = {
        record.get("path"): record
        for record in old_export.get("files", [])
        if isinstance(record, dict)
    }
    planned = []
    executable_name, files, note = export_adapter(paths, application)
    for source, target in files:
        if not source.is_file():
            raise ClavisError(
                f"profile source is missing: {source}; enable its profile template and regenerate the theme first"
            )
        previous = old_by_path.get(str(target))
        owned_unchanged = (
            isinstance(previous, dict)
            and target.is_file()
            and sha256(target) == previous.get("sha256")
        )
        target_exists = target.exists() or target.is_symlink()
        if target_exists and (target.is_symlink() or not target.is_file()):
            raise ClavisError(f"export target is not a regular file: {target}")
        if target_exists and not owned_unchanged and not replace:
            raise ClavisError(
                f"export conflict at {target}; inspect it and rerun with --replace to create a backup and replace it"
            )
        planned.append(
            {
                "source": str(source),
                "target": str(target),
                "replacesExisting": target_exists and not owned_unchanged,
            }
        )
    if dry_run:
        result = {
            "ok": True,
            "dryRun": True,
            "application": application,
            "files": planned,
            "note": note,
        }
        print(json.dumps(result, separators=(",", ":")) if json_output else json.dumps(result, indent=2))
        return 0

    records = []
    snapshots = {target: _snapshot_path(target) for _source, target in files}
    created_backups: list[Path] = []
    try:
        for source, target in files:
            previous = old_by_path.get(str(target))
            owned_unchanged = (
                isinstance(previous, dict)
                and target.is_file()
                and sha256(target) == previous.get("sha256")
            )
            original_existed = target.exists() and not owned_unchanged
            backup = None
            original_sha = None
            if original_existed:
                backup = _backup_target(paths, application, target)
                created_backups.append(backup)
                original_sha = sha256(target)
            elif isinstance(previous, dict):
                backup_value = previous.get("backupPath")
                backup = Path(backup_value) if backup_value else None
                original_existed = bool(previous.get("originalExisted"))
                original_sha = previous.get("originalSha256")
            atomic_write(target, source.read_bytes())
            records.append(
                {
                    "path": str(target),
                    "sha256": sha256(target),
                    "source": str(source),
                    "sourceSha256": sha256(source),
                    "owned": True,
                    "originalExisted": original_existed,
                    "originalSha256": original_sha,
                    "backupPath": str(backup) if backup else None,
                }
            )
        manifest.setdefault("exports", {})[application] = {
            "application": application,
            "enabledAt": utc_now(),
            "files": records,
            "note": note,
        }
        manifest["updatedAt"] = utc_now()
        atomic_json(paths.manifest, manifest)
    except Exception:
        for _source, target in reversed(files):
            _restore_snapshot(target, snapshots[target])
        for backup in created_backups:
            if backup.is_file():
                backup.unlink()
            _remove_empty_parents(
                backup.parent, paths.state_home / "backups/exports"
            )
        raise
    _reload_export(application)
    result = {"ok": True, "application": application, "files": records, "note": note}
    print(json.dumps(result, separators=(",", ":")) if json_output else f"Exported {application}. {note}")
    return 0


def disable_export(
    paths: ClavisPaths, application: str, dry_run: bool, json_output: bool
) -> int:
    if application == "desktop":
        return disable_desktop_export(paths, dry_run, json_output)
    manifest = load_manifest(paths)
    export = manifest.get("exports", {}).get(application)
    if not isinstance(export, dict):
        raise ClavisError(f"no managed export is recorded for {application}")
    actions = []
    all_clean = True
    snapshots: dict[Path, tuple[str, bytes | str | None, int]] = {}
    try:
        for record in export.get("files", []):
            target = Path(record["path"])
            if not target.exists():
                actions.append({"path": str(target), "action": "already-missing"})
                continue
            if not target.is_file() or target.is_symlink() or sha256(target) != record.get(
                "sha256"
            ):
                actions.append({"path": str(target), "action": "preserve-modified"})
                all_clean = False
                continue
            if record.get("originalExisted"):
                backup_value = record.get("backupPath")
                backup = Path(backup_value) if backup_value else None
                if (
                    backup is None
                    or not backup.is_file()
                    or sha256(backup) != record.get("originalSha256")
                ):
                    actions.append({"path": str(target), "action": "preserve-backup-invalid"})
                    all_clean = False
                    continue
                actions.append({"path": str(target), "action": "restore-backup"})
                if not dry_run:
                    snapshots[target] = _snapshot_path(target)
                    atomic_write(target, backup.read_bytes(), stat.S_IMODE(backup.stat().st_mode))
            else:
                actions.append({"path": str(target), "action": "remove"})
                if not dry_run:
                    snapshots[target] = _snapshot_path(target)
                    target.unlink()
        if not dry_run:
            if all_clean:
                del manifest["exports"][application]
            else:
                export["disabledWithModifiedFiles"] = True
            manifest["updatedAt"] = utc_now()
            atomic_json(paths.manifest, manifest)
    except Exception:
        for target, snapshot in reversed(list(snapshots.items())):
            _restore_snapshot(target, snapshot)
        raise
    if not dry_run:
        _reload_export(application)
    result = {
        "ok": all_clean,
        "dryRun": dry_run,
        "application": application,
        "actions": actions,
    }
    print(json.dumps(result, separators=(",", ":")) if json_output else json.dumps(result, indent=2))
    return 0 if all_clean else 1


def export_command(
    paths: ClavisPaths,
    application: str,
    replace: bool,
    disable: bool,
    status_only: bool,
    dry_run: bool,
    json_output: bool,
    desktop_values: dict[str, str | int | None],
) -> int:
    if status_only:
        status = export_status(paths, application)
        print(
            json.dumps(status, separators=(",", ":"))
            if json_output
            else json.dumps(status, indent=2)
        )
        return 0
    if disable:
        return disable_export(paths, application, dry_run, json_output)
    return enable_export(
        paths,
        application,
        replace,
        dry_run,
        json_output,
        desktop_values,
    )


def setup_cpu_power(paths: ClavisPaths, disable: bool, dry_run: bool) -> int:
    helper_destination = Path("/usr/local/libexec/clavis-rapl-helper")
    service_destination = Path("/etc/systemd/system/clavis-rapl-helper.service")
    socket_destination = Path("/etc/systemd/system/clavis-rapl-helper.socket")
    if disable:
        commands = [
            ["sudo", "systemctl", "disable", "--now", "clavis-rapl-helper.socket"],
            ["sudo", "rm", "-f", str(service_destination), str(socket_destination), str(helper_destination)],
            ["sudo", "systemctl", "daemon-reload"],
        ]
        print("The following restricted system integration will be removed:")
    else:
        release = resolve_active_release(paths)
        manifest = load_manifest(paths)
        release_name = str(read_release_metadata(release).get("release", ""))
        if manifest.get("activeRelease") != release_name:
            raise ClavisError(
                "active release and install manifest disagree; refusing privileged setup"
            )
        verified_release = verify_manifest_release(
            paths, release_name, manifest
        )
        if verified_release != release:
            raise ClavisError(
                "active release path does not match the verified manifest"
            )
        helper_source = release / "share/clavis/libexec/clavis-rapl-helper"
        unit_source = release / "share/clavis/systemd/system"
        if not helper_source.is_file():
            raise ClavisError(f"RAPL helper is missing from the active release: {helper_source}")
        commands = [
            ["sudo", "install", "-D", "-m", "0755", str(helper_source), str(helper_destination)],
            ["sudo", "install", "-D", "-m", "0644", str(unit_source / "clavis-rapl-helper.service"), str(service_destination)],
            ["sudo", "install", "-D", "-m", "0644", str(unit_source / "clavis-rapl-helper.socket"), str(socket_destination)],
            ["sudo", "systemctl", "daemon-reload"],
            ["sudo", "systemctl", "enable", "--now", "clavis-rapl-helper.socket"],
        ]
        print(
            "Clavis will install a root-owned, sandboxed socket service. The service "
            "accepts no paths or commands and can only read fixed Intel RAPL sysfs counters."
        )
    for command in commands:
        print("  " + shlex.join(command))
    if dry_run:
        print("Dry run complete; sudo was not invoked.")
        return 0

    if shutil.which("sudo") is None:
        raise ClavisError("sudo is required only for this explicitly requested integration")
    authorization = subprocess.run(["sudo", "-v"], check=False)
    if authorization.returncode != 0:
        raise ClavisError("authorization was denied; CPU power integration was not changed")
    for command in commands:
        result = subprocess.run(command, check=False)
        if result.returncode != 0:
            raise ClavisError(
                f"CPU power setup failed while running: {shlex.join(command)}"
            )

    manifest = load_manifest(paths)
    if disable:
        manifest.setdefault("systemIntegrations", {}).pop("cpuPower", None)
    else:
        manifest.setdefault("systemIntegrations", {})["cpuPower"] = {
            "helperPath": str(helper_destination),
            "servicePath": str(service_destination),
            "socketPath": str(socket_destination),
            "protocol": 1,
            "installedAt": utc_now(),
        }
    manifest["updatedAt"] = utc_now()
    atomic_json(paths.manifest, manifest)
    print("CPU power integration disabled." if disable else "CPU power integration enabled.")
    return 0


def parser_for(command: str) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog=f"key {command}")
    if command == "rollback":
        parser.add_argument("release", nargs="?")
        parser.add_argument("--dry-run", action="store_true")
    elif command == "release":
        parser.add_argument("action", choices=["list", "remove"])
        parser.add_argument("release", nargs="?")
        parser.add_argument("--dry-run", action="store_true")
        parser.add_argument("--json", action="store_true")
    elif command == "uninstall":
        parser.add_argument("--dry-run", action="store_true")
        parser.add_argument("--purge-cache", action="store_true")
        parser.add_argument("--purge-config", action="store_true")
        parser.add_argument("--purge-data", action="store_true")
    elif command == "doctor":
        parser.add_argument("topic", choices=["legacy", "services"])
        parser.add_argument("--json", action="store_true")
    elif command == "migrate":
        parser.add_argument("topic", choices=["legacy"])
        parser.add_argument("--dry-run", action="store_true")
    elif command == "update":
        parser.add_argument("--artifact")
    elif command == "export":
        parser.add_argument("application")
        parser.add_argument("--replace", action="store_true")
        parser.add_argument("--disable", action="store_true")
        parser.add_argument("--status", action="store_true")
        parser.add_argument("--dry-run", action="store_true")
        parser.add_argument("--json", action="store_true")
        parser.add_argument("--icon-theme")
        parser.add_argument("--cursor-theme")
        parser.add_argument("--cursor-size", type=int)
        parser.add_argument("--color-scheme")
    elif command == "setup":
        parser.add_argument("topic", choices=["cpu-power"])
        parser.add_argument("--disable", action="store_true")
        parser.add_argument("--dry-run", action="store_true")
    elif command == "run":
        parser.add_argument("application")
        parser.add_argument("arguments", nargs=argparse.REMAINDER)
    elif command in {"shell", "session", "ipc"}:
        parser.add_argument("arguments", nargs=argparse.REMAINDER)
    elif command == "install-finalize":
        parser.add_argument("--partial", required=True, type=Path)
        parser.add_argument("--release", required=True)
        parser.add_argument("--launcher", required=True, type=Path)
    else:
        raise ClavisError(f"unsupported management command: {command}")
    return parser


def main(argv: list[str]) -> int:
    if not argv:
        fail("management command is required", 2)
    command, arguments = argv[0], argv[1:]
    try:
        paths = ClavisPaths.from_environment()
        parsed = parser_for(command).parse_args(arguments)
        if command == "shell":
            return run_shell(paths, parsed.arguments)
        if command == "session":
            return run_session(paths, parsed.arguments)
        if command == "ipc":
            return run_ipc(paths, parsed.arguments)
        if command == "run":
            return run_profile_application(paths, parsed.application, parsed.arguments)
        if command == "rollback":
            return rollback(paths, parsed.release, parsed.dry_run)
        if command == "release":
            return release_command(
                paths,
                parsed.action,
                parsed.release,
                parsed.dry_run,
                parsed.json,
            )
        if command == "uninstall":
            return uninstall(
                paths,
                parsed.dry_run,
                parsed.purge_cache,
                parsed.purge_config,
                parsed.purge_data,
            )
        if command == "doctor":
            report = (
                legacy_report(paths)
                if parsed.topic == "legacy"
                else services_report(paths)
            )
            if parsed.json:
                print(json.dumps(report, separators=(",", ":")))
            elif parsed.topic == "services":
                print("Clavis user service report:")
                for entry in report["services"]:
                    marker = "OK" if entry["ok"] else "FAIL"
                    state = entry["activeState"]
                    release = entry["runtimeRelease"] or "stable launcher per invocation"
                    print(f"  [{marker:4}] {entry['name']}: {state}; {release}")
                print(report["note"])
            else:
                print("Legacy Clavis installation report:")
                for entry in report["entries"]:
                    marker = "FOUND" if entry["exists"] else "clear"
                    print(f"  [{marker:5}] {entry['kind']}: {entry['path']}")
                print("No legacy path was changed.")
            return 0
        if command == "migrate":
            return migrate_legacy(paths, parsed.dry_run)
        if command == "update":
            return update_command(paths, parsed.artifact)
        if command == "export":
            return export_command(
                paths,
                parsed.application,
                parsed.replace,
                parsed.disable,
                parsed.status,
                parsed.dry_run,
                parsed.json,
                {
                    "iconTheme": parsed.icon_theme,
                    "cursorTheme": parsed.cursor_theme,
                    "cursorSize": parsed.cursor_size,
                    "colorScheme": parsed.color_scheme,
                },
            )
        if command == "setup":
            return setup_cpu_power(paths, parsed.disable, parsed.dry_run)
        if command == "install-finalize":
            return finalize_install(
                paths, parsed.partial, parsed.release, parsed.launcher
            )
    except (ClavisError, PathConfigurationError, OSError, ValueError) as error:
        fail(str(error))
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
