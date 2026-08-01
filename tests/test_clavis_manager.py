#!/usr/bin/env python3
"""Isolation and ownership tests for the Clavis release manager."""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
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
        self.config = root / "config"
        self.data = root / "data"
        self.state = root / "state"
        self.cache = root / "cache"
        self.runtime = root / "runtime"
        self.bin = root / "fake-bin"

    def __enter__(self) -> ClavisPaths:
        self.home.mkdir()
        self.bin.mkdir()
        os.environ.update(
            {
                "HOME": str(self.home),
                "XDG_CONFIG_HOME": str(self.config),
                "XDG_DATA_HOME": str(self.data),
                "XDG_STATE_HOME": str(self.state),
                "XDG_CACHE_HOME": str(self.cache),
                "XDG_RUNTIME_DIR": str(self.runtime),
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
            partial / "share/clavis/systemd/user",
        ):
            directory.mkdir(parents=True, exist_ok=True)
        metadata = {
            "release": release,
            "commit": "test-commit",
            "buildTime": "2026-07-31T00:00:00Z",
            "channel": "stable",
            "sourceDirty": True,
            "sourceFingerprint": "test-fingerprint",
            "protocols": {
                "core": 1,
                "clipboard": 2,
                "sysmon": 1,
                "raplHelper": 1,
            },
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
        (partial / "share/clavis/qml/shell.qml").write_text(
            "import QtQuick\nItem {}\n"
        )
        executable(partial / "share/clavis/libexec/clavis-rapl-helper")
        (partial / "share/clavis/systemd/user/clavis-shell.service").write_text(
            "[Service]\nExecStart=@CLAVIS_KEY@ shell\n"
        )
        launcher = Path(partial.parent.parent.parent) / "key-launcher"
        executable(launcher, "#!/bin/sh\nexit 0\n")
        return partial, launcher

    def test_date_release_order_and_validation(self) -> None:
        self.assertLess(
            manager.release_key("2026.07.31"),
            manager.release_key("2026.07.31.1"),
        )
        self.assertLess(
            manager.release_key("2026.07.31.2"),
            manager.release_key("2026.08.01"),
        )
        with self.assertRaises(ValueError):
            manager.release_key("2026.02.30")
        with self.assertRaises(manager.ClavisError):
            manager.release_key("latest")

    def test_xdg_paths_are_isolated_and_require_absolute_overrides(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-path-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                self.assertEqual(paths.config_home, Path(name) / "config/clavis")
                self.assertEqual(paths.data_home, Path(name) / "data/clavis")
                self.assertEqual(paths.state_home, Path(name) / "state/clavis")
                self.assertEqual(paths.cache_home, Path(name) / "cache/clavis")
                self.assertEqual(paths.runtime_home, Path(name) / "runtime/clavis")
                environment = paths.as_environment(Path(name) / "release")
                self.assertEqual(environment["CLAVIS_REAL_HOME"], str(paths.home))
                self.assertEqual(environment["CLAVIS_BIN_HOME"], str(paths.bin_home))
                self.assertEqual(
                    paths.profile_config_home,
                    Path(name) / "config/clavis/profiles/default",
                )
                self.assertNotIn(str(SOURCE_ROOT), paths.as_environment(Path(name) / "release").values())
                os.environ["CLAVIS_PROFILE_HOME"] = str(Path(name) / "profile")
                os.environ["CLAVIS_PROFILE_CONFIG_HOME"] = str(
                    Path(name) / "profile-config"
                )
                os.environ["CLAVIS_GENERATED_HOME"] = str(Path(name) / "generated")
                os.environ["CLAVIS_QML_IMPORT_HOME"] = str(Path(name) / "qml")
                overridden = ClavisPaths.from_environment()
                self.assertEqual(overridden.profile_home, Path(name) / "profile")
                self.assertEqual(
                    overridden.profile_config_home, Path(name) / "profile-config"
                )
                self.assertEqual(overridden.generated_home, Path(name) / "generated")
                self.assertEqual(overridden.qml_import_home, Path(name) / "qml")
                os.environ["CLAVIS_REAL_HOME"] = str(paths.home)
                os.environ["HOME"] = str(paths.legacy_home)
                self.assertEqual(ClavisPaths.from_environment().home, paths.home)
                os.environ.pop("CLAVIS_REAL_HOME")
                os.environ["HOME"] = str(paths.home)
                os.environ["XDG_CONFIG_HOME"] = "relative"
                with self.assertRaises(PathConfigurationError):
                    ClavisPaths.from_environment()
                os.environ["XDG_CONFIG_HOME"] = str(Path(name) / "config")
                os.environ["CLAVIS_PROFILE"] = "../escape"
                with self.assertRaises(PathConfigurationError):
                    ClavisPaths.from_environment()

    def test_bundled_python_scripts_load_the_canonical_path_contract(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-script-path-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                command = [
                    sys.executable,
                    "-c",
                    "from clavis_paths import ClavisPaths; "
                    "print(ClavisPaths.from_environment().cache_home)",
                ]
                source_environment = os.environ.copy()
                source_environment["PYTHONPATH"] = str(SOURCE_ROOT / "scripts/lib")
                source_result = subprocess.run(
                    command,
                    check=True,
                    capture_output=True,
                    text=True,
                    env=source_environment,
                )
                self.assertEqual(source_result.stdout.strip(), str(paths.cache_home))

                release_share = Path(name) / "release/share/clavis"
                installed_lib = release_share / "scripts/lib"
                installed_exec = release_share / "libexec"
                installed_lib.mkdir(parents=True)
                installed_exec.mkdir(parents=True)
                shutil.copy2(
                    SOURCE_ROOT / "scripts/lib/clavis_paths.py",
                    installed_lib / "clavis_paths.py",
                )
                shutil.copy2(
                    SOURCE_ROOT / "packaging/clavis_paths.py",
                    installed_exec / "clavis_paths.py",
                )
                installed_environment = os.environ.copy()
                installed_environment["PYTHONPATH"] = str(installed_lib)
                installed_result = subprocess.run(
                    command,
                    check=True,
                    capture_output=True,
                    text=True,
                    env=installed_environment,
                )
                self.assertEqual(
                    installed_result.stdout.strip(), str(paths.cache_home)
                )

    def test_finalize_failure_restores_mutable_state_and_removes_new_release(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-transaction-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                partial, launcher = self.make_partial_release(
                    paths, "2026.07.31.9"
                )
                with mock.patch.object(
                    manager, "atomic_json", side_effect=OSError("injected failure")
                ):
                    with self.assertRaises(OSError):
                        manager.finalize_install(
                            paths, partial, "2026.07.31.9", launcher
                        )
                self.assertFalse(paths.current_release.exists())
                self.assertFalse(paths.stable_key.exists())
                self.assertFalse(paths.active_release_file.exists())
                self.assertFalse(paths.manifest.exists())
                self.assertFalse(
                    (paths.releases_home / "2026.07.31.9").exists()
                )
                self.assertFalse(
                    (paths.user_systemd_home / "clavis-shell.service").exists()
                )

    def test_ipc_targets_the_active_release_qml_root(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-ipc-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                executable(fixture.bin / "qs")
                release = "2026.08.01"
                partial, launcher = self.make_partial_release(paths, release)
                with mock.patch.object(manager, "restart_long_running") as restart:
                    manager.finalize_install(paths, partial, release, launcher)
                restart.assert_called_once_with(paths, None)

                with mock.patch.object(manager.os, "execvpe") as exec_mock:
                    self.assertEqual(
                        manager.run_ipc(
                            paths,
                            ["call", "keystone", "dashboard"],
                        ),
                        127,
                    )
                program, command, environment = exec_mock.call_args.args
                release_root = paths.releases_home / release
                profile_override = paths.profile_config_home / "niri/override.kdl"
                profile_override.parent.mkdir(parents=True)
                profile_override.write_text("hotkey-overlay { skip-at-startup; }\n")
                session_config = manager.prepare_niri_profile(
                    paths, release_root
                )
                session_text = session_config.read_text(encoding="utf-8")
                self.assertIn(
                    f'spawn-at-startup "{paths.stable_key}" "shell" "--no-duplicate"',
                    session_text,
                )
                self.assertIn(f'include "{profile_override}"', session_text)
                self.assertEqual(program, str(fixture.bin / "qs"))
                self.assertEqual(
                    command,
                    [
                        str(fixture.bin / "qs"),
                        "--path",
                        str(release_root / "share/clavis/qml"),
                        "ipc",
                        "call",
                        "keystone",
                        "dashboard",
                    ],
                )
                self.assertEqual(
                    environment["CLAVIS_RELEASE_ROOT"], str(release_root)
                )
                self.assertEqual(environment["HOME"], str(paths.legacy_home))
                self.assertEqual(
                    environment["PATH"].split(os.pathsep)[0], str(paths.bin_home)
                )

                with mock.patch.object(manager.os, "execvpe") as list_mock:
                    manager.run_ipc(paths, ["list"])
                self.assertEqual(
                    list_mock.call_args.args[1],
                    [
                        str(fixture.bin / "qs"),
                        "--path",
                        str(release_root / "share/clavis/qml"),
                        "ipc",
                        "show",
                    ],
                )

    def test_profile_applications_seed_isolated_fcitx_and_zsh_config(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-profile-app-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                executable(fixture.bin / "kitty")
                executable(fixture.bin / "fcitx5")
                executable(fixture.bin / "zsh")
                release = "2026.08.01"
                partial, launcher = self.make_partial_release(paths, release)
                defaults = partial / "share/clavis/defaults/profiles/default"
                (defaults / "kitty").mkdir(parents=True)
                (defaults / "kitty/kitty.conf").write_text("font_size 15\n")
                (defaults / "zsh").mkdir()
                (defaults / "zsh/.zshrc").write_text("setopt promptsubst\n")
                (defaults / "fcitx5/conf").mkdir(parents=True)
                (defaults / "fcitx5/config").write_text("Hotkey={}\n")
                (defaults / "fcitx5/conf/classicui.conf").write_text(
                    "Theme=Clavis\n"
                )
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, release, launcher)
                release_root = paths.releases_home / release

                with mock.patch.object(manager.os, "execvpe") as kitty_exec:
                    manager.run_profile_application(paths, "kitty", [])
                kitty_environment = kitty_exec.call_args.args[2]
                self.assertEqual(kitty_environment["HOME"], str(paths.legacy_home))
                self.assertEqual(
                    kitty_environment["XDG_CONFIG_HOME"],
                    str(paths.legacy_home / ".config"),
                )
                self.assertEqual(kitty_environment["SHELL"], str(fixture.bin / "zsh"))
                self.assertEqual(
                    kitty_environment["PATH"].split(os.pathsep)[0],
                    str(paths.bin_home),
                )
                self.assertEqual(
                    kitty_environment["ZDOTDIR"],
                    str(paths.profile_config_home / "zsh"),
                )
                self.assertTrue(
                    (paths.profile_config_home / "zsh/.zshrc").is_file()
                )

                with mock.patch.object(manager.os, "execvpe") as fcitx_exec:
                    manager.run_profile_application(paths, "fcitx5", [])
                program, command, fcitx_environment = fcitx_exec.call_args.args
                self.assertEqual(program, str(fixture.bin / "fcitx5"))
                self.assertEqual(command, [str(fixture.bin / "fcitx5")])
                self.assertEqual(
                    fcitx_environment["XDG_CONFIG_HOME"],
                    str(paths.profile_config_home),
                )
                self.assertTrue(
                    (paths.profile_config_home / "fcitx5/config").is_file()
                )
                self.assertNotIn(
                    str(paths.home / ".local/share"),
                    fcitx_environment["XDG_DATA_DIRS"].split(":"),
                )
                self.assertEqual(
                    manager.load_manifest(paths)["profiles"][0]["configPath"],
                    str(paths.profile_config_home),
                )

    def test_local_profile_is_preserved_and_runtime_copy_is_patched(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-local-profile-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                executable(fixture.bin / "niri-session")
                release = "2026.08.01.7"
                partial, launcher = self.make_partial_release(paths, release)
                raw = partial / "share/clavis/local-profile/home"
                niri = raw / ".config/niri"
                niri.mkdir(parents=True)
                (niri / "config.kdl").write_text(
                    'include "binds.kdl"\ninclude "startup.kdl"\n'
                )
                (niri / "binds.kdl").write_text(
                    'Mod+M { spawn "quickshell" "ipc" "call" "keystone" "dashboard"; }\n'
                )
                (niri / "startup.kdl").write_text(
                    'spawn-at-startup "fcitx5"\n'
                    'spawn-at-startup "quickshell"\n'
                    'spawn-sh-at-startup "clipse --listen"\n'
                    'spawn-at-startup "nm-applet"\n'
                )
                (raw / ".zsh/plugins/demo").mkdir(parents=True)
                (raw / ".zsh/plugins/demo/plugin.zsh").write_text("true\n")
                (raw / ".zsh/plugins/demo/plugin-link.zsh").symlink_to("plugin.zsh")
                (raw / ".zshrc").write_text(
                    "source ~/.zsh/plugins/demo/plugin.zsh\n"
                    "PROMPT='$(~/.local/bin/prompt $PROMPT_EXIT_CODE \"$PROMPT_CMD_DURATION\" $COLUMNS)'\n"
                )
                raw_hash = manager.sha256(niri / "binds.kdl")

                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, release, launcher)

                release_root = paths.releases_home / release
                manager.verify_manifest_release(
                    paths, release, manager.load_manifest(paths)
                )
                release_entry = manager.load_manifest(paths)["releases"][release]
                self.assertIn(
                    {
                        "path": "share/clavis/local-profile/home/.zsh/plugins/demo/plugin-link.zsh",
                        "kind": "symlink",
                        "target": "plugin.zsh",
                    },
                    release_entry["files"],
                )
                installed_raw = (
                    release_root
                    / "share/clavis/local-profile/home/.config/niri/binds.kdl"
                )
                self.assertEqual(manager.sha256(installed_raw), raw_hash)
                self.assertEqual(
                    manager.prepare_niri_profile(paths, release_root),
                    paths.legacy_home / ".config/niri/config.kdl",
                )
                startup = (paths.legacy_home / ".config/niri/startup.kdl").read_text()
                self.assertIn("$CLAVIS_KEY session supervise", startup)
                self.assertIn('"nm-applet"', startup)
                self.assertNotIn('"quickshell"', startup)
                manager.prepare_niri_profile(paths, release_root)
                repeated_startup = (
                    paths.legacy_home / ".config/niri/startup.kdl"
                ).read_text()
                self.assertEqual(startup, repeated_startup)
                self.assertEqual(
                    repeated_startup.count("Clavis owns the three session children"),
                    1,
                )
                binds = (paths.legacy_home / ".config/niri/binds.kdl").read_text()
                self.assertIn("$CLAVIS_KEY ipc call keystone dashboard", binds)
                zshrc = (paths.legacy_home / ".zshrc").read_text()
                self.assertIn("${CLAVIS_LEGACY_HOME}/.zsh/plugins", zshrc)
                self.assertIn('key}\" prompt', zshrc)

                environment = os.environ.copy()
                environment.pop("NIRI_SOCKET", None)
                environment.pop("XDG_CURRENT_DESKTOP", None)
                environment.pop("XDG_SESSION_DESKTOP", None)
                with mock.patch.dict(os.environ, environment, clear=True):
                    with mock.patch.object(manager.os, "execvpe") as exec_mock:
                        manager.run_session(paths, [])
                program, command, session_environment = exec_mock.call_args.args
                self.assertEqual(program, str(fixture.bin / "niri-session"))
                self.assertEqual(command, [str(fixture.bin / "niri-session")])
                self.assertEqual(
                    session_environment["NIRI_CONFIG"],
                    str(paths.legacy_home / ".config/niri/config.kdl"),
                )
                self.assertEqual(
                    session_environment["PATH"].split(os.pathsep)[0],
                    str(paths.bin_home),
                )

    def test_passthrough_commands_accept_leading_options(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-passthrough-test.") as name:
            with EnvironmentFixture(Path(name)) as paths:
                with mock.patch.object(manager, "run_shell", return_value=23) as run:
                    self.assertEqual(
                        manager.main(["shell", "--no-duplicate", "--verbose"]),
                        23,
                    )
                run.assert_called_once_with(paths, ["--no-duplicate", "--verbose"])

    def test_session_supervisor_stops_when_its_niri_socket_disappears(self) -> None:
        class Child:
            returncode = None
            next_pid = 10000

            def __init__(self):
                self.pid = Child.next_pid
                Child.next_pid += 1

            def poll(self):
                return self.returncode

            def wait(self, _timeout):
                self.returncode = -15
                return self.returncode

        with tempfile.TemporaryDirectory(prefix="clavis-supervisor-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                release = "2026.08.01.8"
                partial, launcher = self.make_partial_release(paths, release)
                with mock.patch.object(manager, "restart_long_running"):
                    manager.finalize_install(paths, partial, release, launcher)
                socket = paths.runtime_home / "niri.test.sock"
                socket.parent.mkdir(parents=True, exist_ok=True)
                socket.touch()
                os.environ["NIRI_SOCKET"] = str(socket)

                def end_session(_seconds):
                    socket.unlink()

                with (
                    mock.patch.object(
                        manager.subprocess, "Popen", side_effect=lambda *_a, **_kw: Child()
                    ) as popen,
                    mock.patch.object(manager.time, "sleep", side_effect=end_session),
                    mock.patch.object(manager.os, "killpg") as killpg,
                ):
                    self.assertEqual(manager.run_session_supervisor(paths), 0)

                self.assertEqual(popen.call_count, 3)
                self.assertTrue(
                    all(
                        call.kwargs["start_new_session"]
                        for call in popen.call_args_list
                    )
                )
                self.assertEqual(killpg.call_count, 3)
                log = paths.state_home / "logs/session-supervisor.log"
                self.assertIn("supervisor stopped", log.read_text())
                self.assertTrue(
                    any(
                        paths.runtime_home.joinpath("locks").glob(
                            "session-supervisor-*.lock"
                        )
                    )
                )

    def test_repeated_install_rejects_a_mutated_immutable_release(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-repeat-integrity-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                release = "2026.07.31.11"
                partial, launcher = self.make_partial_release(paths, release)
                manager.finalize_install(paths, partial, release, launcher)
                clean_repeat, clean_launcher = self.make_partial_release(
                    paths, release
                )
                self.assertEqual(
                    manager.finalize_install(
                        paths, clean_repeat, release, clean_launcher
                    ),
                    0,
                )
                installed = paths.releases_home / release / "bin/key"
                installed.chmod(0o755)
                installed.write_text("#!/bin/sh\nexit 42\n", encoding="utf-8")

                repeated, repeated_launcher = self.make_partial_release(paths, release)
                with self.assertRaisesRegex(
                    manager.ClavisError, "differs from the freshly built release"
                ):
                    manager.finalize_install(
                        paths, repeated, release, repeated_launcher
                    )
                self.assertEqual(
                    manager.load_manifest(paths)["activeRelease"], release
                )
                self.assertEqual(installed.read_text(), "#!/bin/sh\nexit 42\n")

    def test_release_remove_refuses_an_unrecorded_empty_directory(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-release-remove-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                old_release = "2026.07.31.13"
                current_release = "2026.07.31.14"
                partial, launcher = self.make_partial_release(paths, old_release)
                manager.finalize_install(paths, partial, old_release, launcher)
                partial, launcher = self.make_partial_release(paths, current_release)
                manager.finalize_install(paths, partial, current_release, launcher)

                old_root = paths.releases_home / old_release
                old_root.chmod(0o755)
                unrecorded = old_root / "user-empty"
                unrecorded.mkdir()
                with self.assertRaisesRegex(
                    manager.ClavisError, "unrecorded entries"
                ):
                    manager.release_command(
                        paths, "remove", old_release, False, False
                    )
                self.assertTrue(unrecorded.is_dir())
                self.assertIn(
                    old_release, manager.load_manifest(paths)["releases"]
                )

    def test_purge_rejects_broad_or_symlinked_override_roots(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-purge-safety-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                unsafe = replace(paths, cache_home=Path("/"))
                with self.assertRaises(manager.ClavisError):
                    manager.uninstall(unsafe, True, True, False, False)

                target = Path(name) / "cache-target"
                target.mkdir()
                link = Path(name) / "cache-link"
                link.symlink_to(target, target_is_directory=True)
                symlinked = replace(paths, cache_home=link)
                with self.assertRaises(manager.ClavisError):
                    manager.uninstall(symlinked, True, True, False, False)

    def test_uninstall_records_modified_and_unowned_release_residue(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-uninstall-residue-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                release = "2026.07.31.10"
                partial, launcher = self.make_partial_release(paths, release)
                manager.finalize_install(paths, partial, release, launcher)

                release_root = paths.releases_home / release
                modified = release_root / "share/clavis/qml/shell.qml"
                original = modified.read_bytes()
                modified.chmod(0o644)
                modified.write_text("user-modified\n", encoding="utf-8")
                modified.parent.chmod(0o755)
                unowned = modified.parent / "user-note.txt"
                unowned.write_text("keep me\n", encoding="utf-8")
                unowned_directory = modified.parent / "user-empty"
                unowned_directory.mkdir(mode=0o500)
                external_directory = fixture.root / "external"
                external_directory.mkdir(mode=0o500)
                unowned_link = modified.parent / "user-link"
                unowned_link.symlink_to(external_directory, target_is_directory=True)

                self.assertEqual(
                    manager.uninstall(paths, False, False, False, False), 0
                )
                self.assertTrue(modified.is_file())
                self.assertTrue(unowned.is_file())
                self.assertTrue(unowned_directory.is_dir())
                self.assertEqual(
                    stat.S_IMODE(unowned_directory.stat().st_mode), 0o500
                )
                self.assertTrue(unowned_link.is_symlink())
                self.assertEqual(
                    stat.S_IMODE(external_directory.stat().st_mode), 0o500
                )
                self.assertFalse(paths.stable_key.exists())
                residual = manager.load_manifest(paths)
                self.assertEqual(residual["releases"], {})
                items = residual["preservedItems"]
                by_path = {item.get("path"): item for item in items}
                self.assertTrue(by_path[str(modified)]["owned"])
                self.assertEqual(
                    by_path[str(modified)]["expectedSha256"],
                    manager.hashlib.sha256(original).hexdigest(),
                )
                self.assertFalse(by_path[str(unowned)]["owned"])
                self.assertFalse(by_path[str(unowned_directory)]["owned"])
                self.assertFalse(by_path[str(unowned_link)]["owned"])

                modified.write_bytes(original)
                unowned.unlink()
                unowned_directory.rmdir()
                unowned_link.unlink()
                self.assertEqual(
                    manager.uninstall(paths, False, False, False, False), 0
                )
                self.assertFalse(paths.manifest.exists())
                self.assertFalse(release_root.exists())

    def test_file_export_conflict_backup_restore_and_modified_preservation(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-export-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                executable(fixture.bin / "kitty")
                source = paths.generated_home / "kitty/colors.conf"
                source.parent.mkdir(parents=True)
                source.write_text("foreground #ffffff\n", encoding="utf-8")
                target = fixture.config / "kitty/themes/Clavis.conf"
                target.parent.mkdir(parents=True)
                target.write_text("user-original\n", encoding="utf-8")

                with self.assertRaises(manager.ClavisError):
                    manager.enable_export(paths, "kitty", False, False, False)
                self.assertEqual(target.read_text(), "user-original\n")

                self.assertEqual(
                    manager.enable_export(paths, "kitty", True, False, False), 0
                )
                manifest = manager.load_manifest(paths)
                record = manifest["exports"]["kitty"]["files"][0]
                self.assertTrue(Path(record["backupPath"]).is_file())
                self.assertEqual(target.read_text(), source.read_text())

                target.write_text("user-edited-export\n", encoding="utf-8")
                self.assertEqual(manager.disable_export(paths, "kitty", False, False), 1)
                self.assertEqual(target.read_text(), "user-edited-export\n")

    def test_clean_disable_restores_original_atomically(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-disable-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                executable(fixture.bin / "kitty")
                source = paths.generated_home / "kitty/colors.conf"
                source.parent.mkdir(parents=True)
                source.write_text("clavis\n", encoding="utf-8")
                target = fixture.config / "kitty/themes/Clavis.conf"
                target.parent.mkdir(parents=True)
                target.write_text("original\n", encoding="utf-8")
                manager.enable_export(paths, "kitty", True, False, False)
                self.assertEqual(manager.disable_export(paths, "kitty", False, False), 0)
                self.assertEqual(target.read_text(), "original\n")
                self.assertNotIn("kitty", manager.load_manifest(paths)["exports"])

    def test_uninstall_can_retry_a_preserved_export_restore(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-uninstall-export-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                os.environ["CLAVIS_SKIP_SYSTEMD"] = "1"
                executable(fixture.bin / "kitty")
                source = paths.generated_home / "kitty/colors.conf"
                source.parent.mkdir(parents=True)
                source.write_text("clavis\n", encoding="utf-8")
                target = fixture.config / "kitty/themes/Clavis.conf"
                target.parent.mkdir(parents=True)
                target.write_text("original\n", encoding="utf-8")
                manager.enable_export(paths, "kitty", True, False, False)

                exported = target.read_bytes()
                target.write_text("user-modified\n", encoding="utf-8")
                manager.uninstall(paths, False, False, False, False)
                residual = manager.load_manifest(paths)["preservedItems"]
                item = next(record for record in residual if record.get("path") == str(target))
                self.assertEqual(item["action"], "restore-backup")
                self.assertEqual(target.read_text(), "user-modified\n")

                target.write_bytes(exported)
                manager.uninstall(paths, False, False, False, False)
                self.assertEqual(target.read_text(), "original\n")
                self.assertFalse(paths.manifest.exists())

    def test_export_manifest_failures_restore_all_target_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-export-transaction-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                executable(fixture.bin / "kitty")
                source = paths.generated_home / "kitty/colors.conf"
                source.parent.mkdir(parents=True)
                source.write_text("clavis-colors\n", encoding="utf-8")
                target = fixture.config / "kitty/themes/Clavis.conf"
                target.parent.mkdir(parents=True)
                target.write_text("user-original\n", encoding="utf-8")

                with mock.patch.object(
                    manager, "atomic_json", side_effect=OSError("injected failure")
                ):
                    with self.assertRaises(OSError):
                        manager.enable_export(paths, "kitty", True, False, False)
                self.assertEqual(target.read_text(), "user-original\n")
                backup_root = paths.state_home / "backups/exports"
                self.assertFalse(
                    backup_root.exists()
                    and any(path.is_file() for path in backup_root.rglob("*"))
                )

                manager.enable_export(paths, "kitty", True, False, False)
                exported = target.read_text()
                with mock.patch.object(
                    manager, "atomic_json", side_effect=OSError("injected failure")
                ):
                    with self.assertRaises(OSError):
                        manager.disable_export(paths, "kitty", False, False)
                self.assertEqual(target.read_text(), exported)
                self.assertIn("kitty", manager.load_manifest(paths)["exports"])

    def test_desktop_export_records_values_and_preserves_user_changes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-desktop-test.") as name:
            fixture = EnvironmentFixture(Path(name))
            with fixture as paths:
                state = Path(name) / "gsettings.json"
                state.write_text(
                    json.dumps(
                        {
                            "icon-theme": "'Adwaita'",
                            "cursor-theme": "'Adwaita'",
                            "cursor-size": "24",
                            "color-scheme": "'default'",
                        }
                    ),
                    encoding="utf-8",
                )
                os.environ["FAKE_GSETTINGS_STATE"] = str(state)
                executable(
                    fixture.bin / "gsettings",
                    """#!/usr/bin/env python3
import json, os, pathlib, sys
path = pathlib.Path(os.environ['FAKE_GSETTINGS_STATE'])
data = json.loads(path.read_text())
action, _schema, key = sys.argv[1:4]
if action == 'get':
    print(data[key])
    raise SystemExit(0)
value = sys.argv[4]
if key != 'cursor-size' and not value.startswith("'"):
    value = repr(value)
data[key] = value
path.write_text(json.dumps(data))
""",
                )
                values = {
                    "iconTheme": "Papirus-Dark",
                    "cursorTheme": "Bibata-Modern-Ice",
                    "cursorSize": 32,
                    "colorScheme": "prefer-dark",
                }
                self.assertEqual(
                    manager.enable_export(
                        paths, "desktop", False, False, False, values
                    ),
                    0,
                )
                record = manager.load_manifest(paths)["exports"]["desktop"]
                self.assertEqual(len(record["settings"]), 4)
                changed = json.loads(state.read_text())
                changed["color-scheme"] = "'prefer-light'"
                state.write_text(json.dumps(changed), encoding="utf-8")
                self.assertEqual(
                    manager.disable_export(paths, "desktop", False, False), 1
                )
                restored = json.loads(state.read_text())
                self.assertEqual(restored["icon-theme"], "'Adwaita'")
                self.assertEqual(restored["cursor-theme"], "'Adwaita'")
                self.assertEqual(restored["cursor-size"], "24")
                self.assertEqual(restored["color-scheme"], "'prefer-light'")


if __name__ == "__main__":
    unittest.main()
