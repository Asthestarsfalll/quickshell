#!/usr/bin/env python3
"""Release-manager tests for the Niri-only Clavis profile contract."""

from __future__ import annotations

import importlib.util
import io
import json
import os
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from unittest import mock


SOURCE_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE_ROOT / "packaging"))
spec = importlib.util.spec_from_file_location(
    "clavis_manager", SOURCE_ROOT / "packaging/clavis-manager.py"
)
assert spec and spec.loader
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)

from clavis_paths import ClavisPaths, PathConfigurationError  # noqa: E402


class EnvironmentFixture:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.previous = os.environ.copy()
        self.home = root / "home"
        self.bin = root / "fake-bin"

    def __enter__(self) -> ClavisPaths:
        self.home.mkdir()
        self.bin.mkdir()
        os.environ.update(
            {
                "HOME": str(self.home),
                "XDG_CONFIG_HOME": str(self.root / "config"),
                "XDG_DATA_HOME": str(self.root / "data"),
                "XDG_STATE_HOME": str(self.root / "state"),
                "XDG_CACHE_HOME": str(self.root / "cache"),
                "XDG_RUNTIME_DIR": str(self.root / "runtime"),
                "CLAVIS_BIN_HOME": str(self.root / "commands"),
                "CLAVIS_INSTALL_PREFIX": str(self.root / "install"),
                "PATH": str(self.bin) + os.pathsep + self.previous.get("PATH", ""),
            }
        )
        for name in (
            "CLAVIS_CONFIG_HOME",
            "CLAVIS_DATA_HOME",
            "CLAVIS_STATE_HOME",
            "CLAVIS_CACHE_HOME",
            "CLAVIS_RUNTIME_HOME",
            "CLAVIS_PROFILE",
            "CLAVIS_PROFILE_HOME",
            "CLAVIS_PROFILE_CONFIG_HOME",
            "CLAVIS_GENERATED_HOME",
            "CLAVIS_QML_IMPORT_HOME",
        ):
            os.environ.pop(name, None)
        return ClavisPaths.from_environment()

    def __exit__(self, *_: object) -> None:
        os.environ.clear()
        os.environ.update(self.previous)


def executable(path: Path, text: str = "#!/bin/sh\nexit 0\n") -> None:
    path.write_text(text, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


class ClavisManagerTest(unittest.TestCase):
    def make_partial_release(
        self, paths: ClavisPaths, release: str
    ) -> tuple[Path, Path]:
        partial = paths.releases_home / f"{release}.partial"
        for directory in (
            partial / "bin",
            partial / "lib/qml/Clavis/Runtime",
            partial / "lib/qml/M3Shapes",
            partial / "share/clavis/qml",
            partial / "share/clavis/libexec",
            partial / "share/clavis/defaults/profiles/default/niri",
        ):
            directory.mkdir(parents=True, exist_ok=True)
        metadata = {
            "release": release,
            "commit": "test-commit",
            "buildTime": "2026-07-31T00:00:00Z",
            "channel": "stable",
            "sourceDirty": True,
            "sourceFingerprint": "test-fingerprint",
            "protocols": {"core": 1, "clipboard": 2, "sysmon": 1, "raplHelper": 1},
            "dataSchemas": {"config": 1, "manifest": 1, "profile": 1},
            "dependencyManifest": 1,
        }
        (partial / "release.json").write_text(json.dumps(metadata))
        executable(
            partial / "bin/key",
            "#!/bin/sh\nprintf '%s\\n' '"
            + json.dumps(
                {
                    "product": "clavis-key",
                    "release": release,
                    "commit": "test-commit",
                    "protocols": metadata["protocols"],
                    "features": [],
                }
            )
            + "'\n",
        )
        (partial / "lib/qml/Clavis/Runtime/qmldir").write_text(
            "module Clavis.Runtime\n"
        )
        (partial / "lib/qml/M3Shapes/qmldir").write_text("module M3Shapes\n")
        (partial / "share/clavis/qml/shell.qml").write_text(
            "import QtQuick\nItem {}\n"
        )
        executable(partial / "share/clavis/libexec/clavis-rapl-helper")
        niri = partial / "share/clavis/defaults/profiles/default/niri"
        (niri / "config.kdl").write_text(
            'include "startup.kdl"\ninclude "binds.kdl"\n'
        )
        (niri / "startup.kdl").write_text(
            'spawn-at-startup "fcitx5"\n'
            'spawn-at-startup "nm-applet"\n'
            'spawn-at-startup "blueman-applet"\n'
            'spawn-sh-at-startup "$CLAVIS_KEY shell --no-duplicate"\n'
            'spawn-sh-at-startup "$CLAVIS_KEY clipboard watch"\n'
        )
        (niri / "binds.kdl").write_text(
            'Mod+Space { spawn-sh "$CLAVIS_KEY ipc call launcher toggle"; }\n'
        )
        launcher = Path(partial.parent.parent.parent) / "key-launcher"
        executable(launcher)
        return partial, launcher

    def test_release_order_and_validation(self) -> None:
        self.assertLess(
            manager.release_key("2026.07.31"), manager.release_key("2026.07.31.1")
        )
        with self.assertRaises(ValueError):
            manager.release_key("2026.02.30")
        with self.assertRaises(manager.ClavisError):
            manager.release_key("latest")

    def test_xdg_paths_keep_the_real_home(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-path-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                environment = paths.as_environment(Path(name) / "release")
                self.assertEqual(paths.home, Path(name) / "home")
                self.assertEqual(environment["CLAVIS_BIN_HOME"], str(paths.bin_home))
                self.assertEqual(paths.logs_home, Path(name) / "state/clavis/logs")
                self.assertNotIn("CLAVIS_REAL_HOME", environment)
                self.assertFalse(hasattr(paths, "legacy_home"))
                os.environ["XDG_CONFIG_HOME"] = "relative"
                with self.assertRaises(PathConfigurationError):
                    ClavisPaths.from_environment()

    @unittest.skipUnless(shutil.which("just"), "just is an optional dependency")
    def test_just_shell_workflows_are_documented_and_use_key(self) -> None:
        formatted = subprocess.run(
            ["just", "--fmt", "--check"],
            cwd=SOURCE_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(formatted.returncode, 0, formatted.stderr)
        english = subprocess.run(
            ["just", "--list"],
            cwd=SOURCE_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(english.returncode, 0, english.stderr)
        self.assertIn("shell-foreground", english.stdout)
        self.assertNotIn("切换到", english.stdout)
        default_help = subprocess.run(
            ["just"],
            cwd=SOURCE_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(default_help.returncode, 0, default_help.stderr)
        self.assertIn("Available recipes", default_help.stdout)
        chinese = subprocess.run(
            ["just", "help-zh"],
            cwd=SOURCE_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(chinese.returncode, 0, chinese.stderr)
        self.assertIn("后台启动后返回终端", chinese.stdout)
        expected = {
            "shell": "key shell --replace",
            "sf": "key shell --replace --foreground",
            "dev": "key shell --dev --replace",
            "df": "key shell --dev --replace --foreground",
            "dev-native": "key shell --dev --native --replace",
            "dn": "key shell --dev --native --replace",
            "dev-native-foreground": (
                "key shell --dev --native --replace --foreground"
            ),
            "dnf": "key shell --dev --native --replace --foreground",
        }
        for recipe, command in expected.items():
            dry_run = subprocess.run(
                ["just", "--dry-run", recipe],
                cwd=SOURCE_ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(dry_run.returncode, 0, dry_run.stderr)
            self.assertEqual((dry_run.stdout + dry_run.stderr).strip(), command)

    def test_session_layers_packaged_niri_config_without_replacing_home(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-session-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                executable(fixture.bin / "niri-session")
                release = "2026.08.01"
                partial, launcher = self.make_partial_release(paths, release)
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, release, launcher)

                override = paths.profile_config_home / "niri/override.kdl"
                override.parent.mkdir(parents=True)
                override.write_text("hotkey-overlay { skip-at-startup; }\n")
                generated = paths.generated_home / "niri"
                generated.mkdir(parents=True)
                (generated / "colors.kdl").write_text("// colors\n")
                release_root = paths.releases_home / release
                session_config = manager.prepare_niri_profile(paths, release_root)
                session_text = session_config.read_text(encoding="utf-8")
                self.assertIn(
                    str(release_root / "share/clavis/defaults/profiles/default/niri/config.kdl"),
                    session_text,
                )
                self.assertIn(str(generated / "colors.kdl"), session_text)
                self.assertIn(
                    f'include optional=true "{generated / "outputs.kdl"}"',
                    session_text,
                )
                self.assertIn(str(override), session_text)
                self.assertNotIn("legacy-home", session_text)

                clean_environment = os.environ.copy()
                clean_environment.pop("NIRI_SOCKET", None)
                clean_environment.pop("XDG_CURRENT_DESKTOP", None)
                clean_environment.pop("XDG_SESSION_DESKTOP", None)
                with mock.patch.dict(os.environ, clean_environment, clear=True):
                    with mock.patch.object(manager.os, "execvpe") as exec_mock:
                        manager.run_session(paths, [])
                program, command, environment = exec_mock.call_args.args
                self.assertEqual(program, str(fixture.bin / "niri-session"))
                self.assertEqual(command, [str(fixture.bin / "niri-session")])
                self.assertEqual(environment["HOME"], str(paths.home))
                self.assertEqual(environment["NIRI_CONFIG"], str(session_config))
                self.assertEqual(
                    environment["PATH"].split(os.pathsep)[0], str(paths.bin_home)
                )

    def test_ipc_targets_the_active_release(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-ipc-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                executable(fixture.bin / "qs")
                partial, launcher = self.make_partial_release(paths, "2026.08.01")
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, "2026.08.01", launcher)
                with mock.patch.object(manager.os, "execvpe") as exec_mock:
                    manager.run_ipc(paths, ["call", "launcher", "toggle"])
                program, command, environment = exec_mock.call_args.args
                self.assertEqual(program, str(fixture.bin / "qs"))
                self.assertEqual(command[-4:], ["ipc", "call", "launcher", "toggle"])
                self.assertEqual(environment["HOME"], str(paths.home))

    def test_source_tree_discovery_walks_up_and_rejects_other_directories(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-source-test.") as name:
            root = Path(name) / "checkout"
            nested = root / "Modules/Spotlight"
            nested.mkdir(parents=True)
            (root / ".git").mkdir()
            (root / "core").mkdir()
            (root / "packaging").mkdir()
            (root / "shell.qml").write_text("// source\n")
            self.assertEqual(manager.locate_source_tree(nested), root)
            with self.assertRaisesRegex(
                manager.ClavisError, "Cannot locate the Clavis source tree"
            ):
                manager.locate_source_tree(Path(name))

    def test_development_shell_uses_source_qml_and_release_native_components(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-dev-shell-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                executable(fixture.bin / "qs")
                partial, launcher = self.make_partial_release(paths, "2026.08.01")
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, "2026.08.01", launcher)
                source = Path(name) / "source"
                for directory in (source / ".git", source / "core", source / "packaging"):
                    directory.mkdir(parents=True)
                (source / "shell.qml").write_text("// development\n")
                current_before = paths.current_release.resolve()
                with (
                    mock.patch.object(manager, "_list_instances", return_value=[]),
                    mock.patch.object(manager, "_git_identity", return_value=("dev-commit", True)),
                    mock.patch.object(
                        manager, "_launch_background_shell", return_value=0
                    ) as launch,
                ):
                    self.assertEqual(
                        manager.run_shell(paths, ["--dev", "--source", str(source)]),
                        0,
                    )
                (
                    launch_paths,
                    command,
                    _qs,
                    qml_root,
                    environment,
                    metadata,
                    _commit,
                    _dirty,
                    _log_path,
                    log_handle,
                    _replaced,
                ) = launch.call_args.args
                release = paths.releases_home / "2026.08.01"
                self.assertEqual(launch_paths, paths)
                self.assertEqual(qml_root, source)
                self.assertNotIn("CLAVIS_RELEASE_ROOT", environment)
                self.assertEqual(environment["CLAVIS_SOURCE_ROOT"], str(source))
                self.assertEqual(environment["CLAVIS_RUNTIME_MODE"], "development")
                self.assertEqual(environment["CLAVIS_KEY"], str(release / "bin/key"))
                self.assertEqual(
                    environment["CLAVIS_QML_IMPORT_HOME"], str(release / "lib/qml")
                )
                self.assertEqual(metadata["mode"], "development")
                self.assertEqual(command[:3], [str(fixture.bin / "qs"), "--path", str(source)])
                self.assertEqual(paths.current_release.resolve(), current_before)
                log_handle.close()

    def test_release_shell_ignores_source_tree_and_uses_one_release(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-release-shell-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                executable(fixture.bin / "qs")
                partial, launcher = self.make_partial_release(paths, "2026.08.01")
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, "2026.08.01", launcher)
                (SOURCE_ROOT / "shell.qml").stat()  # Source exists but is not selected.
                with (
                    mock.patch.object(manager, "_list_instances", return_value=[]),
                    mock.patch.object(
                        manager, "_launch_background_shell", return_value=0
                    ) as launch,
                ):
                    self.assertEqual(manager.run_shell(paths, []), 0)
                (
                    _paths,
                    _command,
                    _qs,
                    qml_root,
                    environment,
                    metadata,
                    _commit,
                    _dirty,
                    _log_path,
                    log_handle,
                    _replaced,
                ) = launch.call_args.args
                release = paths.releases_home / "2026.08.01"
                self.assertEqual(qml_root, release / "share/clavis/qml")
                self.assertEqual(environment["CLAVIS_RELEASE_ROOT"], str(release))
                self.assertEqual(environment["CLAVIS_KEY"], str(release / "bin/key"))
                self.assertEqual(
                    environment["CLAVIS_QML_IMPORT_HOME"], str(release / "lib/qml")
                )
                self.assertEqual(metadata["mode"], "release")
                log_handle.close()

    def test_shell_replace_targets_only_the_recorded_instance(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-shell-replace-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                executable(fixture.bin / "qs")
                partial, launcher = self.make_partial_release(paths, "2026.08.01")
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, "2026.08.01", launcher)
                release = paths.releases_home / "2026.08.01"
                active = {
                    "mode": "development",
                    "pid": 7331,
                    "qmlRoot": str(SOURCE_ROOT),
                }
                with (
                    mock.patch.object(manager, "read_active_shell", return_value=active),
                    mock.patch.object(manager, "_kill_instance") as kill,
                    mock.patch.object(manager, "_remove_active_shell"),
                    mock.patch.object(
                        manager, "_launch_background_shell", return_value=0
                    ) as launch,
                ):
                    self.assertEqual(manager.run_shell(paths, ["--replace"]), 0)
                kill.assert_called_once_with(str(fixture.bin / "qs"), 7331)
                self.assertEqual(paths.current_release.resolve(), release)
                launch.call_args.args[9].close()

    def test_native_development_environment_uses_incremental_build_tree(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-native-shell-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                partial, _launcher = self.make_partial_release(paths, "2026.08.01")
                release = paths.releases_home / "2026.08.01"
                release.parent.mkdir(parents=True, exist_ok=True)
                partial.rename(release)
                source = Path(name) / "source"
                build = source / ".build/dev"
                (source / "packaging").mkdir(parents=True)
                executable(source / "setup.sh")
                (build / "bin").mkdir(parents=True)
                executable(build / "bin/key")
                (build / "Clavis/Runtime").mkdir(parents=True)
                (build / "Clavis/Runtime/qmldir").write_text("module Clavis.Runtime\n")
                (build / "M3Shapes").mkdir(parents=True)
                (build / "M3Shapes/qmldir").write_text("module M3Shapes\n")
                completed = subprocess.CompletedProcess([], 0)
                with (
                    mock.patch.object(manager.subprocess, "run", return_value=completed) as run,
                    mock.patch.object(
                        manager,
                        "_key_handshake",
                        return_value={"product": "clavis-key", "release": "development", "commit": "abc"},
                    ),
                ):
                    environment, backend, imports, _handshake = manager._development_environment(
                        paths, release, source, True
                    )
                self.assertEqual(
                    run.call_args_list[0].args[0],
                    [str(source / "setup.sh"), "dev-build", "--build-dir", str(build)],
                )
                self.assertEqual(backend, build / "bin/key")
                self.assertEqual(imports, build)
                self.assertEqual(environment["CLAVIS_RUNTIME_MODE"], "development-native")
                self.assertEqual(
                    environment["CLAVIS_MANAGER"], str(source / "packaging/clavis-manager.py")
                )

    def test_ipc_routes_to_valid_runtime_instance_and_cleans_stale_state(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-runtime-ipc-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                executable(fixture.bin / "qs")
                partial, launcher = self.make_partial_release(paths, "2026.08.01")
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, "2026.08.01", launcher)
                metadata = {
                    "schemaVersion": manager.ACTIVE_SHELL_SCHEMA,
                    "mode": "development",
                    "pid": 4242,
                    "processStartTicks": 99,
                    "qmlRoot": str(SOURCE_ROOT),
                    "token": "test",
                }
                manager.atomic_json(manager.active_shell_path(paths), metadata, 0o600)
                with (
                    mock.patch.object(manager, "_process_start_ticks", return_value=99),
                    mock.patch.object(manager, "_process_is_quickshell", return_value=True),
                    mock.patch.object(manager.os, "execvpe") as exec_mock,
                ):
                    manager.run_ipc(paths, ["call", "spotlight", "toggle"])
                self.assertEqual(
                    exec_mock.call_args.args[1][-6:],
                    ["ipc", "--pid", "4242", "call", "spotlight", "toggle"],
                )

                manager.atomic_json(manager.active_shell_path(paths), metadata, 0o600)
                with mock.patch.object(manager, "_process_start_ticks", return_value=None):
                    self.assertIsNone(manager.read_active_shell(paths))
                self.assertFalse(manager.active_shell_path(paths).exists())

    def test_foreground_shell_returns_child_status_and_removes_metadata(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-shell-metadata-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                observed: dict[str, object] = {}

                class FakeProcess:
                    pid = 4242

                    def poll(self) -> None:
                        return None

                    def send_signal(self, _signum: int) -> None:
                        pass

                    def wait(self, timeout: int | None = None) -> int:
                        del timeout
                        path = manager.active_shell_path(paths)
                        observed["mode"] = stat.S_IMODE(path.stat().st_mode)
                        observed["metadata"] = json.loads(path.read_text())
                        return 7

                with (
                    mock.patch.object(manager.subprocess, "Popen", return_value=FakeProcess()),
                    mock.patch.object(manager, "_process_start_ticks", return_value=77),
                    mock.patch.object(
                        manager,
                        "_wait_for_shell_registration",
                        return_value=(True, ""),
                    ),
                    mock.patch.object(
                        manager,
                        "read_active_shell",
                        side_effect=lambda _paths: json.loads(
                            manager.active_shell_path(paths).read_text()
                        ),
                    ),
                    mock.patch.object(manager.signal, "signal", return_value=signal.SIG_DFL),
                ):
                    result = manager._launch_foreground_shell(
                        paths,
                        ["/usr/bin/qs", "--path", str(SOURCE_ROOT)],
                        "/usr/bin/qs",
                        SOURCE_ROOT,
                        os.environ.copy(),
                        {"mode": "development", "release": "development"},
                        "test-commit",
                        True,
                        False,
                    )
                self.assertEqual(result, 7)
                self.assertEqual(observed["mode"], 0o600)
                self.assertEqual(observed["metadata"]["processStartTicks"], 77)
                self.assertFalse(manager.active_shell_path(paths).exists())

    def test_foreground_shell_forwards_interrupt_and_maps_signal_status(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-shell-signal-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                handlers: dict[int, object] = {}
                received: list[int] = []

                class FakeProcess:
                    pid = 4243

                    def poll(self) -> None:
                        return None

                    def send_signal(self, signum: int) -> None:
                        received.append(signum)

                    def wait(self, timeout: int | None = None) -> int:
                        del timeout
                        handler = handlers[signal.SIGINT]
                        assert callable(handler)
                        handler(signal.SIGINT, None)
                        return -signal.SIGINT

                def record_handler(signum: int, handler: object) -> object:
                    handlers[signum] = handler
                    return signal.SIG_DFL

                with (
                    mock.patch.object(manager.subprocess, "Popen", return_value=FakeProcess()),
                    mock.patch.object(manager, "_process_start_ticks", return_value=78),
                    mock.patch.object(
                        manager,
                        "_wait_for_shell_registration",
                        return_value=(True, ""),
                    ),
                    mock.patch.object(
                        manager,
                        "read_active_shell",
                        side_effect=lambda _paths: json.loads(
                            manager.active_shell_path(paths).read_text()
                        ),
                    ),
                    mock.patch.object(manager.signal, "signal", side_effect=record_handler),
                    mock.patch("sys.stdout", io.StringIO()),
                ):
                    result = manager._launch_foreground_shell(
                        paths,
                        ["/usr/bin/qs", "--path", str(SOURCE_ROOT)],
                        "/usr/bin/qs",
                        SOURCE_ROOT,
                        os.environ.copy(),
                        {"mode": "development", "release": "development"},
                        "test-commit",
                        False,
                        False,
                    )
                self.assertEqual(result, 130)
                self.assertEqual(received, [signal.SIGINT])
                self.assertFalse(manager.active_shell_path(paths).exists())

    def test_background_shell_detaches_logs_and_returns_after_registration(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-background-shell-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                class FakeProcess:
                    pid = 5150

                    def poll(self) -> None:
                        return None

                process = FakeProcess()
                log_path, log_handle = manager._open_shell_log(paths, "development")
                output = io.StringIO()
                with (
                    mock.patch.object(manager.subprocess, "Popen", return_value=process) as popen,
                    mock.patch.object(
                        manager, "_wait_for_shell_registration", return_value=(True, "")
                    ),
                    mock.patch.object(manager, "_process_start_ticks", return_value=123),
                    mock.patch.object(manager, "_start_shell_log_monitor") as monitor,
                    mock.patch.object(
                        manager,
                        "read_active_shell",
                        side_effect=lambda _paths: json.loads(
                            manager.active_shell_path(paths).read_text()
                        ),
                    ),
                    mock.patch("sys.stdout", output),
                ):
                    result = manager._launch_background_shell(
                        paths,
                        ["/usr/bin/qs", "--path", str(SOURCE_ROOT)],
                        "/usr/bin/qs",
                        SOURCE_ROOT,
                        os.environ.copy(),
                        {
                            "mode": "development",
                            "release": "2026.08.02",
                            "sourceRoot": str(SOURCE_ROOT),
                            "backendKey": "/release/bin/key",
                            "nativeImportRoot": "/release/lib/qml",
                        },
                        "test-commit",
                        True,
                        log_path,
                        log_handle,
                        False,
                    )
                self.assertEqual(result, 0)
                self.assertIn("Started Clavis development Shell (PID 5150)", output.getvalue())
                kwargs = popen.call_args.kwargs
                self.assertIs(kwargs["stdin"], subprocess.DEVNULL)
                self.assertIs(kwargs["stderr"], subprocess.STDOUT)
                self.assertTrue(kwargs["start_new_session"])
                self.assertTrue(kwargs["close_fds"])
                monitor.assert_called_once()
                metadata = json.loads(manager.active_shell_path(paths).read_text())
                self.assertEqual(metadata["pid"], 5150)
                self.assertEqual(metadata["mode"], "development")
                self.assertEqual(metadata["logPath"], str(log_path))
                self.assertEqual(stat.S_IMODE(log_path.stat().st_mode), 0o600)
                self.assertEqual(stat.S_IMODE(paths.logs_home.stat().st_mode), 0o700)
                log = log_path.read_text()
                self.assertIn("Runtime mode: development", log)
                self.assertIn("PID: 5150", log)
                self.assertIn("Startup verified.", log)

    def test_background_start_failure_prints_log_tail_and_never_reports_started(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-background-failure-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                class FailedProcess:
                    pid = 6160

                    def poll(self) -> int:
                        return 3

                    def wait(self) -> int:
                        return 3

                log_path, log_handle = manager._open_shell_log(paths, "release")
                error = io.StringIO()
                output = io.StringIO()
                with (
                    mock.patch.object(manager.subprocess, "Popen", return_value=FailedProcess()),
                    mock.patch("sys.stderr", error),
                    mock.patch("sys.stdout", output),
                ):
                    result = manager._launch_background_shell(
                        paths,
                        ["/usr/bin/qs", "--path", str(SOURCE_ROOT)],
                        "/usr/bin/qs",
                        SOURCE_ROOT,
                        os.environ.copy(),
                        {"mode": "release", "release": "2026.08.02"},
                        "test-commit",
                        False,
                        log_path,
                        log_handle,
                        True,
                    )
                self.assertEqual(result, 1)
                self.assertEqual(output.getvalue(), "")
                self.assertIn("exited during startup with status 3", error.getvalue())
                self.assertIn("Last", error.getvalue())
                self.assertIn(f"Full log: {log_path}", error.getvalue())
                self.assertIn("key shell --replace", error.getvalue())
                self.assertFalse(manager.active_shell_path(paths).exists())

    def test_shell_logs_rotate_and_can_be_selected_by_mode(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-shell-log-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                path = manager._shell_log_path(paths, "development-native")
                paths.logs_home.mkdir(parents=True)
                path.write_text("old native log\n")
                opened_path, handle = manager._open_shell_log(
                    paths, "development-native"
                )
                manager._rotate_live_shell_log(path)
                handle.write("new native log\n")
                handle.close()
                self.assertEqual(opened_path, path)
                self.assertEqual(Path(f"{path}.1").read_text(), "old native log\n")
                output = io.StringIO()
                with mock.patch("sys.stdout", output):
                    self.assertEqual(
                        manager.run_shell_logs(paths, ["--mode", "dev-native"]),
                        0,
                    )
                self.assertEqual(output.getvalue(), "new native log\n")

                path.write_text("active log contents\n")
                manager._rotate_live_shell_log(path)
                self.assertEqual(path.read_text(), "")
                self.assertEqual(Path(f"{path}.1").read_text(), "active log contents\n")

    def test_shell_logs_reject_stale_paths_and_follow_safely(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-shell-log-routing-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                paths.logs_home.mkdir(parents=True)
                release_log = manager._shell_log_path(paths, "release")
                release_log.write_text("release log\n")
                outside = Path(name) / "outside.log"
                outside.write_text("must not be read\n")
                with (
                    mock.patch.object(
                        manager,
                        "read_active_shell",
                        return_value={"logPath": str(outside)},
                    ),
                    mock.patch.object(manager, "executable", return_value="/usr/bin/tail"),
                    mock.patch.object(
                        manager.subprocess,
                        "run",
                        return_value=subprocess.CompletedProcess([], 0),
                    ) as run,
                ):
                    self.assertEqual(manager.run_shell_logs(paths, ["--follow"]), 0)
                self.assertEqual(
                    run.call_args.args[0],
                    ["/usr/bin/tail", "-n", "80", "-F", str(release_log)],
                )
                with self.assertRaisesRegex(manager.ClavisError, "duplicate"):
                    manager.run_shell_logs(paths, ["--follow", "--follow"])
                with self.assertRaisesRegex(manager.ClavisError, "duplicate"):
                    manager.run_shell_logs(
                        paths, ["--mode", "release", "--mode=dev"]
                    )

    def test_shell_arguments_are_strict_and_foreground_is_uniform(self) -> None:
        parsed, passthrough = manager._shell_arguments(
            ["--dev", "--native", "--foreground", "--replace", "--", "--verbose"]
        )
        self.assertTrue(parsed.dev)
        self.assertTrue(parsed.native)
        self.assertTrue(parsed.foreground)
        self.assertTrue(parsed.replace)
        self.assertEqual(passthrough, ["--verbose"])
        with self.assertRaisesRegex(manager.ClavisError, "--native requires --dev"):
            manager._shell_arguments(["--native"])
        with self.assertRaisesRegex(manager.ClavisError, "duplicate Shell option"):
            manager._shell_arguments(["--dev", "--dev"])
        with self.assertRaisesRegex(manager.ClavisError, "managed by `key shell`"):
            manager._shell_arguments(["--", "--path", "/tmp/other"])
        with self.assertRaises(SystemExit) as stopped:
            manager._shell_arguments(["--verbose"])
        self.assertEqual(stopped.exception.code, 2)
        self.assertEqual(manager._exit_status(-signal.SIGINT), 130)

    def test_native_build_failure_happens_before_replace(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-native-failure-order-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                executable(fixture.bin / "qs")
                partial, launcher = self.make_partial_release(paths, "2026.08.02")
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, "2026.08.02", launcher)
                with (
                    mock.patch.object(manager, "locate_source_tree", return_value=SOURCE_ROOT),
                    mock.patch.object(
                        manager,
                        "_development_environment",
                        side_effect=manager.ClavisError("native build failed"),
                    ),
                    mock.patch.object(manager, "_kill_instance") as kill,
                    mock.patch("sys.stderr", io.StringIO()) as error,
                ):
                    self.assertEqual(
                        manager.run_shell(
                            paths, ["--dev", "--native", "--replace"]
                        ),
                        1,
                    )
                kill.assert_not_called()
                self.assertIn("native build failed", error.getvalue())
                self.assertIn(
                    "native build failed",
                    manager._shell_log_path(
                        paths, "development-native"
                    ).read_text(),
                )

    def test_log_creation_failure_happens_before_replace(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-log-failure-order-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                executable(fixture.bin / "qs")
                partial, launcher = self.make_partial_release(paths, "2026.08.02")
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, "2026.08.02", launcher)
                error = io.StringIO()
                with (
                    mock.patch.object(
                        manager,
                        "_open_shell_log",
                        side_effect=PermissionError("permission denied"),
                    ),
                    mock.patch.object(manager, "_kill_instance") as kill,
                    mock.patch("sys.stderr", error),
                ):
                    self.assertEqual(manager.run_shell(paths, ["--replace"]), 1)
                kill.assert_not_called()
                self.assertIn("cannot create the launch log", error.getvalue())
                self.assertIn("shell-release.log", error.getvalue())

    def test_release_restart_uses_exact_pid_and_background_handshake(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-release-restart-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                old_root = paths.releases_home / "2026.08.01"
                active = {
                    "pid": 8123,
                    "qmlRoot": str(old_root / "share/clavis/qml"),
                    "token": "old-token",
                }
                completed = subprocess.CompletedProcess([], 0, "started\n", "")
                with (
                    mock.patch.object(manager.shutil, "which", return_value="/usr/bin/qs"),
                    mock.patch.object(manager, "read_active_shell", return_value=active),
                    mock.patch.object(manager, "_kill_instance") as kill,
                    mock.patch.object(manager, "_remove_active_shell") as remove,
                    mock.patch.object(
                        manager.subprocess, "run", return_value=completed
                    ) as run,
                ):
                    manager.restart_long_running(paths, old_root)
                kill.assert_called_once_with("/usr/bin/qs", 8123)
                remove.assert_called_once_with(paths, "old-token")
                self.assertEqual(
                    run.call_args.args[0],
                    [str(paths.stable_key), "shell", "--no-duplicate"],
                )
                self.assertIs(run.call_args.kwargs["stdin"], subprocess.DEVNULL)

    def test_removed_commands_are_not_routed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-command-test.") as name:
            with EnvironmentFixture(Path(name)):
                for command in ("run", "prompt", "export"):
                    with self.assertRaises(SystemExit) as stopped:
                        manager.main([command])
                    self.assertEqual(stopped.exception.code, 1)
                with self.assertRaises(SystemExit) as stopped:
                    manager.main(["session", "supervise"])
                self.assertEqual(stopped.exception.code, 1)

    def test_obsolete_user_units_are_removed_on_install(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-unit-migration-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                paths.user_systemd_home.mkdir(parents=True)
                for unit in manager.OBSOLETE_USER_SERVICES:
                    (paths.user_systemd_home / unit).write_text("obsolete\n")
                partial, launcher = self.make_partial_release(paths, "2026.08.01")
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, "2026.08.01", launcher)
                for unit in manager.OBSOLETE_USER_SERVICES:
                    self.assertFalse((paths.user_systemd_home / unit).exists())
                self.assertEqual(manager.load_manifest(paths)["userUnits"], [])

    def test_repeated_install_rejects_a_mutated_release(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-repeat-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                release = "2026.08.01"
                partial, launcher = self.make_partial_release(paths, release)
                manager.finalize_install(paths, partial, release, launcher)
                installed = paths.releases_home / release / "bin/key"
                installed.chmod(0o755)
                installed.write_text("#!/bin/sh\nexit 42\n")
                repeated, repeated_launcher = self.make_partial_release(paths, release)
                with self.assertRaisesRegex(manager.ClavisError, "differs"):
                    manager.finalize_install(
                        paths, repeated, release, repeated_launcher
                    )

    def test_rollback_release_remove_and_uninstall_dry_run(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-lifecycle-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                old_release = "2026.08.01"
                new_release = "2026.08.01.1"
                for release in (old_release, new_release):
                    partial, launcher = self.make_partial_release(paths, release)
                    with mock.patch.object(manager, "restart_long_running"):
                        manager.finalize_install(paths, partial, release, launcher)
                with mock.patch.object(manager, "restart_long_running"):
                    self.assertEqual(manager.rollback(paths, old_release, False), 0)
                self.assertEqual(
                    manager.load_manifest(paths)["activeRelease"], old_release
                )
                self.assertEqual(
                    manager.release_command(paths, "remove", new_release, False, False),
                    0,
                )
                self.assertFalse((paths.releases_home / new_release).exists())
                self.assertEqual(
                    manager.uninstall(paths, True, False, False, False), 0
                )
                self.assertTrue(paths.stable_key.exists())
                self.assertTrue((paths.releases_home / old_release).exists())

    def test_purge_rejects_broad_or_symlinked_roots(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-purge-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                with self.assertRaises(manager.ClavisError):
                    manager.uninstall(
                        replace(paths, cache_home=Path("/")), True, True, False, False
                    )
                target = Path(name) / "cache-target"
                target.mkdir()
                link = Path(name) / "cache-link"
                link.symlink_to(target, target_is_directory=True)
                with self.assertRaises(manager.ClavisError):
                    manager.uninstall(
                        replace(paths, cache_home=link), True, True, False, False
                    )


if __name__ == "__main__":
    unittest.main()
