#!/usr/bin/env python3

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


SOURCE_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = SOURCE_ROOT / "scripts/system/manage-niri-config.py"
SPEC = importlib.util.spec_from_file_location("manage_niri_config", MODULE_PATH)
manager = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(manager)


class NiriConfigManagerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="clavis-niri-config-test.")
        self.root = Path(self.temporary.name)
        self.niri = self.root / "niri"
        self.niri.mkdir()
        self.main = self.niri / "config.kdl"
        self.clavis = self.niri / "clavis"
        self.settings = self.root / "clavis/config.json"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    @staticmethod
    def successful_process(stdout: str = "") -> subprocess.CompletedProcess:
        return subprocess.CompletedProcess(["niri"], 0, stdout, "")

    def version_and_validation(self, optional: bool = True):
        version = "niri 26.04" if optional else "niri 25.11"

        def run(command, **_kwargs):
            if command[1] == "--version":
                return self.successful_process(version)
            return self.successful_process()

        return mock.patch.object(manager.subprocess, "run", side_effect=run)

    def test_missing_config_status(self) -> None:
        with self.version_and_validation():
            status = manager.status(self.main, self.clavis, "niri")
        self.assertFalse(status["validation"]["ok"])
        self.assertEqual(status["includes"], [])

    def test_include_graph_preserves_position_and_reports_later_include(self) -> None:
        self.main.write_text(
            'include "first.kdl"\ninclude optional=true "clavis/layout.kdl"\ninclude "last.kdl"\n',
            encoding="utf-8",
        )
        (self.niri / "first.kdl").write_text("input {}\n", encoding="utf-8")
        (self.niri / "last.kdl").write_text("layout { gaps 99; }\n", encoding="utf-8")
        self.clavis.mkdir()
        (self.clavis / "layout.kdl").write_text("layout { gaps 12; }\n", encoding="utf-8")
        includes = manager.walk_includes(self.main)
        self.assertEqual([item["line"] for item in includes], [1, 2, 3])
        self.assertEqual(manager.domain_include(self.main, self.clavis / "layout.kdl")["line"], 2)

    def test_apply_layout_uses_optional_include_only_when_supported(self) -> None:
        self.main.write_text("input {}\n", encoding="utf-8")
        with self.version_and_validation(True):
            manager.apply_domain(self.main, self.clavis, "layout", {"gaps": 16}, "niri")
        self.assertIn('include optional=true "clavis/layout.kdl"', self.main.read_text())
        self.assertIn("gaps 16", (self.clavis / "layout.kdl").read_text())

        second = self.root / "old-niri"
        second.mkdir()
        old_main = second / "config.kdl"
        old_main.write_text("input {}\n", encoding="utf-8")
        with self.version_and_validation(False):
            manager.apply_domain(old_main, second / "clavis", "layout", {}, "niri")
        self.assertIn('include "clavis/layout.kdl"', old_main.read_text())
        self.assertNotIn("optional=true", old_main.read_text())

    def test_invalid_candidate_keeps_last_valid_files(self) -> None:
        self.main.write_text("input {}\n", encoding="utf-8")
        self.clavis.mkdir()
        fragment = self.clavis / "layout.kdl"
        fragment.write_text("known-good\n", encoding="utf-8")

        def run(command, **_kwargs):
            if command[1] == "--version":
                return self.successful_process("niri 26.04")
            return subprocess.CompletedProcess(command, 1, "", "invalid")

        with mock.patch.object(manager.subprocess, "run", side_effect=run):
            with self.assertRaises(manager.NiriConfigError):
                manager.apply_domain(self.main, self.clavis, "layout", {"gaps": 4}, "niri")
        self.assertEqual(fragment.read_text(), "known-good\n")
        self.assertEqual(self.main.read_text(), "input {}\n")

    def test_atomic_replace_failure_preserves_target(self) -> None:
        target = self.root / "target"
        target.write_text("old", encoding="utf-8")

        def fail(_source: str, _destination: str) -> None:
            raise OSError("rename failed")

        with self.assertRaises(OSError):
            manager.atomic_write(target, b"new", fail)
        self.assertEqual(target.read_text(), "old")

    def test_conflicts_are_case_insensitive_and_recursive(self) -> None:
        self.main.write_text('include "user.kdl"\ninclude "second.kdl"\n', encoding="utf-8")
        (self.niri / "user.kdl").write_text("binds {\n Mod+P { close-window; }\n}\n")
        (self.niri / "second.kdl").write_text("binds {\n mod+p { quit; }\n}\n")
        conflicts = manager.find_bind_conflicts(self.main)
        self.assertEqual(len(conflicts), 1)
        self.assertEqual(conflicts[0]["key"], "mod+p")

    def test_binding_key_cannot_inject_kdl(self) -> None:
        with self.assertRaises(manager.NiriConfigError):
            manager.render_binds({
                'Mod+X { spawn "false"; } //': 'spawn "true";'
            })

    def test_duplicate_outputs_are_reported_without_rewriting_user_files(self) -> None:
        self.main.write_text('include "one.kdl"\ninclude "two.kdl"\n', encoding="utf-8")
        (self.niri / "one.kdl").write_text('output "DP-1" { scale 1; }\n')
        (self.niri / "two.kdl").write_text('output "DP-1" { scale 2; }\n')
        conflicts = manager.find_output_conflicts(self.main, self.clavis)
        self.assertEqual(conflicts[0]["output"], "DP-1")
        self.assertEqual(len(conflicts[0]["sources"]), 2)

    def test_migration_backs_up_and_preserves_unknown_clavis_file(self) -> None:
        self.main.write_text(
            "environment {\n}\n"
            'include "binds.kdl"\ninclude "output.kdl"\n'
            'include "startup.kdl"\ninclude optional=true "clavis-effects.kdl"\n',
            encoding="utf-8",
        )
        (self.niri / "binds.kdl").write_text("binds {}\n")
        (self.niri / "startup.kdl").write_text('spawn-at-startup "fcitx5"\n')
        (self.niri / "clavis-effects.kdl").write_text("layer-rule {}\n")
        (self.niri / "output.kdl").write_text(
            'output "DP-1" {\n mode "1920x1080@60"\n scale 1.25\n position x=0 y=0\n}\n'
            'layer-rule { match namespace="clavis"; }\n'
        )
        self.clavis.mkdir()
        (self.clavis / "keep.kdl").write_text("user-owned\n")
        self.settings.parent.mkdir()
        self.settings.write_text('{"theme": {"mode": "dark"}}\n')
        with self.version_and_validation(True):
            backup = manager.migrate_user_config(
                self.main, self.clavis, self.settings,
                Path("/home/test/.local/bin/key"), "niri", None,
            )
        self.assertTrue((backup / "config.kdl").is_file())
        self.assertEqual((self.clavis / "keep.kdl").read_text(), "user-owned\n")
        self.assertIn("Polkit authentication agent", (self.niri / "startup.kdl").read_text())
        migrated = self.main.read_text()
        self.assertIn('include optional=true "clavis/outputs.kdl"', migrated)
        self.assertIn('CLAVIS_KEY "/home/test/.local/bin/key"', migrated)
        settings = json.loads(self.settings.read_text())
        self.assertEqual(settings["theme"]["mode"], "dark")
        self.assertEqual(settings["niri"]["outputs"]["DP-1"]["scale"], 1.25)


if __name__ == "__main__":
    unittest.main()
