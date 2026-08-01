#!/usr/bin/env python3
"""Release-manager tests for the Niri-only Clavis profile contract."""

from __future__ import annotations

import importlib.util
import json
import os
import stat
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
                self.assertNotIn("CLAVIS_REAL_HOME", environment)
                self.assertFalse(hasattr(paths, "legacy_home"))
                os.environ["XDG_CONFIG_HOME"] = "relative"
                with self.assertRaises(PathConfigurationError):
                    ClavisPaths.from_environment()

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
