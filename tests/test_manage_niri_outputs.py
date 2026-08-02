#!/usr/bin/env python3

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


SOURCE_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = SOURCE_ROOT / "scripts/system/manage-niri-outputs.py"
SPEC = importlib.util.spec_from_file_location("manage_niri_outputs", MODULE_PATH)
manager = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(manager)


class NiriOutputConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="clavis-niri-output-test.")
        self.root = Path(self.temporary.name)
        self.target = self.root / "generated/outputs.kdl"
        self.session = self.root / "generated/session.kdl"
        self.target.parent.mkdir(parents=True)
        escaped = manager.escape_kdl_string(str(self.target))
        self.session.write_text(
            "// controlled session\n"
            f'include optional=true "{escaped}"\n',
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    @staticmethod
    def outputs(*names: str):
        return lambda _command: set(names)

    @staticmethod
    def validation(success: bool = True):
        return mock.patch.object(
            manager.subprocess,
            "run",
            return_value=subprocess.CompletedProcess(
                ["niri"], 0 if success else 1, "", "invalid candidate"
            ),
        )

    def apply(self, scales, names, **kwargs) -> None:
        with self.validation():
            manager.apply_output_scales(
                self.session,
                self.target,
                scales,
                set(names),
                output_reader=self.outputs(*names),
                **kwargs,
            )

    def test_single_output(self) -> None:
        self.apply({"eDP-1": 1.25}, ["eDP-1"])
        self.assertEqual(
            self.target.read_text(encoding="utf-8"),
            '// Managed by Clavis. Manual edits will be replaced.\n'
            'output "eDP-1" {\n    scale 1.25\n}\n',
        )

    def test_multiple_outputs_and_special_name(self) -> None:
        self.apply(
            {'DP-1 "desk" \\ main': 1.5, "eDP-1": 1.0},
            ['DP-1 "desk" \\ main', "eDP-1"],
        )
        text = self.target.read_text(encoding="utf-8")
        self.assertIn('output "DP-1 \\"desk\\" \\\\ main"', text)
        self.assertIn('output "eDP-1"', text)

    def test_existing_generated_file_gets_recoverable_copy(self) -> None:
        self.target.write_text('output "old" { scale 1.00 }\n', encoding="utf-8")
        self.apply({"eDP-1": 1.5}, ["eDP-1"])
        self.assertEqual(
            self.target.with_name("outputs.kdl.last-good").read_text(encoding="utf-8"),
            'output "old" { scale 1.00 }\n',
        )

    def test_invalid_candidate_does_not_replace_last_valid_file(self) -> None:
        self.target.write_text("known-good\n", encoding="utf-8")
        with self.validation(False):
            with self.assertRaises(manager.OutputConfigError):
                manager.apply_output_scales(
                    self.session,
                    self.target,
                    {"eDP-1": 1.25},
                    {"eDP-1"},
                    output_reader=self.outputs("eDP-1"),
                )
        self.assertEqual(self.target.read_text(encoding="utf-8"), "known-good\n")

    def test_atomic_replace_failure_keeps_target(self) -> None:
        self.target.write_text("known-good\n", encoding="utf-8")

        def fail_replace(_source: str, destination: str) -> None:
            if Path(destination) == self.target:
                raise OSError("simulated rename failure")
            os.replace(_source, destination)

        with self.validation():
            with self.assertRaises(OSError):
                manager.apply_output_scales(
                    self.session,
                    self.target,
                    {"eDP-1": 1.25},
                    {"eDP-1"},
                    replace=fail_replace,
                    output_reader=self.outputs("eDP-1"),
                )
        self.assertEqual(self.target.read_text(encoding="utf-8"), "known-good\n")

    def test_output_removed_before_save_is_rejected(self) -> None:
        self.target.write_text("known-good\n", encoding="utf-8")
        with self.assertRaisesRegex(manager.OutputConfigError, "disconnected"):
            manager.apply_output_scales(
                self.session,
                self.target,
                {"DP-1": 1.25},
                {"eDP-1", "DP-1"},
                output_reader=self.outputs("eDP-1"),
            )
        self.assertEqual(self.target.read_text(encoding="utf-8"), "known-good\n")

    def test_user_config_without_managed_include_is_never_rewritten(self) -> None:
        user_config = self.root / "user-config.kdl"
        user_config.write_text("input {}\n", encoding="utf-8")
        original = user_config.read_bytes()
        with self.assertRaisesRegex(manager.OutputConfigError, "does not include"):
            manager.apply_output_scales(
                user_config,
                self.target,
                {"eDP-1": 1.25},
                {"eDP-1"},
                output_reader=self.outputs("eDP-1"),
            )
        self.assertEqual(user_config.read_bytes(), original)
        self.assertFalse(self.target.exists())


if __name__ == "__main__":
    unittest.main()
