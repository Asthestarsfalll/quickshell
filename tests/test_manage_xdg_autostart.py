from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock


SOURCE_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = SOURCE_ROOT / "scripts/system/manage-xdg-autostart.py"
SPEC = importlib.util.spec_from_file_location("manage_xdg_autostart", MODULE_PATH)
assert SPEC and SPEC.loader
autostart = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(autostart)


class XdgAutostartTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="clavis-autostart-test.")
        self.root = Path(self.temporary.name)
        self.config = self.root / "config"
        self.data = self.root / "data"
        self.system = self.root / "system"
        self.environment = mock.patch.dict(os.environ, {
            "XDG_CONFIG_HOME": str(self.config),
            "XDG_CONFIG_DIRS": str(self.system),
            "XDG_DATA_HOME": str(self.data),
            "XDG_DATA_DIRS": str(self.system),
        }, clear=False)
        self.environment.start()

    def tearDown(self) -> None:
        self.environment.stop()
        self.temporary.cleanup()

    def system_entry(self, name: str) -> Path:
        directory = self.system / "autostart"
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / name
        path.write_text(
            "[Desktop Entry]\nType=Application\nName=System App\n"
            "Exec=/usr/bin/example --flag\nHidden=false\n",
            encoding="utf-8",
        )
        return path

    def test_missing_user_directory_and_system_entry_listing(self) -> None:
        source = self.system_entry("example.desktop")
        entries = autostart.list_entries()
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["path"], str(source))
        self.assertFalse(entries[0]["user"])

    def test_custom_command_preserves_spaces_and_arguments(self) -> None:
        path = autostart.add_custom(
            "my-task", "My Task", '/usr/bin/example --name "two words"',
        )
        text = path.read_text(encoding="utf-8")
        self.assertIn('Exec=/usr/bin/example --name "two words"', text)
        self.assertIn("X-Clavis-Managed=true", text)

    def test_hidden_override_does_not_modify_system_entry(self) -> None:
        source = self.system_entry("example.desktop")
        original = source.read_bytes()
        override = autostart.set_hidden("example.desktop", True)
        self.assertIn("Hidden=true", override.read_text(encoding="utf-8"))
        self.assertEqual(source.read_bytes(), original)
        autostart.set_hidden("example.desktop", False)
        self.assertIn("Hidden=false", override.read_text(encoding="utf-8"))

    def test_delete_only_removes_user_entry(self) -> None:
        source = self.system_entry("example.desktop")
        override = autostart.set_hidden("example.desktop", True)
        autostart.delete_user("example.desktop")
        self.assertFalse(override.exists())
        self.assertTrue(source.exists())
        with self.assertRaises(autostart.AutostartError):
            autostart.delete_user("example.desktop")

    def test_refuses_to_overwrite_non_clavis_user_entry(self) -> None:
        directory = self.config / "autostart"
        directory.mkdir(parents=True)
        path = directory / "mine.desktop"
        path.write_text("[Desktop Entry]\nName=Mine\nExec=true\n", encoding="utf-8")
        with self.assertRaises(autostart.AutostartError):
            autostart.add_custom("mine", "Replacement", "/usr/bin/false")
        self.assertIn("Exec=true", path.read_text(encoding="utf-8"))

    def test_adds_installed_application_without_touching_source(self) -> None:
        directory = self.system / "applications"
        directory.mkdir(parents=True, exist_ok=True)
        source = directory / "visual-editor.desktop"
        source.write_text(
            "[Desktop Entry]\nType=Application\nName=Visual Editor\n"
            'Exec=/usr/bin/editor --open "two words"\n',
            encoding="utf-8",
        )
        original = source.read_bytes()
        applications = autostart.list_applications()
        self.assertEqual(applications[0]["id"], source.name)
        target = autostart.add_application(source.name)
        self.assertIn("X-Clavis-Managed=true", target.read_text(encoding="utf-8"))
        self.assertIn("Hidden=false", target.read_text(encoding="utf-8"))
        self.assertEqual(source.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
