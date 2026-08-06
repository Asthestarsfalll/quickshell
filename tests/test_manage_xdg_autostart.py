from __future__ import annotations

import contextlib
import io
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


class UserAutostartTests(unittest.TestCase):
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

    def user_directory(self) -> Path:
        directory = self.config / "autostart"
        directory.mkdir(parents=True, exist_ok=True)
        return directory

    def write_user_entry(self, name: str = "example.desktop") -> Path:
        path = self.user_directory() / name
        path.write_text(
            "[Desktop Entry]\nType=Application\nName=示例应用\n"
            "Exec=/usr/bin/example --flag %U\nIcon=example\n"
            "Hidden=false\nX-User-Value=preserve\n",
            encoding="utf-8",
        )
        return path

    def write_system_entry(self, name: str = "system.desktop") -> Path:
        directory = self.system / "autostart"
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / name
        path.write_text(
            "[Desktop Entry]\nType=Application\nName=系统组件\n"
            "Exec=/usr/bin/system-component\nHidden=false\n",
            encoding="utf-8",
        )
        return path

    def test_missing_directory_is_not_created_and_system_entries_are_ignored(self) -> None:
        system_entry = self.write_system_entry()

        result = autostart.list_entries()

        self.assertEqual(result["entries"], [])
        self.assertFalse((self.config / "autostart").exists())
        self.assertTrue(system_entry.exists())

    def test_user_directory_respects_xdg_config_home(self) -> None:
        self.assertEqual(autostart.autostart_dir(), self.config / "autostart")

    def test_add_application_preserves_original_exec_and_unicode_fields(self) -> None:
        path = autostart.add_application(
            "org.example.Editor.desktop",
            "文本编辑器",
            "/usr/bin/editor --open %U",
            "accessories-text-editor",
        )

        text = path.read_text(encoding="utf-8")
        self.assertEqual(path.parent, self.config / "autostart")
        self.assertTrue(path.parent.is_dir())
        self.assertIn("Name=文本编辑器", text)
        self.assertIn("Exec=/usr/bin/editor --open %U", text)
        self.assertIn("Icon=accessories-text-editor", text)
        self.assertIn("Hidden=false", text)

    def test_duplicate_application_is_rejected_without_overwrite(self) -> None:
        path = self.write_user_entry("clavis-org.example.Editor.desktop")
        original = path.read_bytes()

        with self.assertRaises(autostart.AutostartError):
            autostart.add_application(
                "org.example.Editor.desktop", "Replacement", "/usr/bin/false", ""
            )

        self.assertEqual(path.read_bytes(), original)

    def test_application_does_not_override_same_named_system_entry(self) -> None:
        system_entry = self.write_system_entry("org.example.Editor.desktop")
        self.user_directory()

        user_entry = autostart.add_application(
            "org.example.Editor.desktop", "编辑器", "/usr/bin/editor", ""
        )

        self.assertEqual(user_entry.name, "clavis-org.example.Editor.desktop")
        self.assertTrue(user_entry.exists())
        self.assertTrue(system_entry.exists())

    def test_custom_command_action_is_not_supported(self) -> None:
        for action in ("init", "add-custom"):
            with self.subTest(action=action):
                with contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit):
                        autostart.parser().parse_args([action])

    def test_hidden_only_changes_hidden_and_preserves_other_fields(self) -> None:
        path = self.write_user_entry()
        original_prefix = "[Desktop Entry]\nType=Application\nName=示例应用\n"

        autostart.set_hidden("example.desktop", True)
        hidden_text = path.read_text(encoding="utf-8")
        self.assertTrue(hidden_text.startswith(original_prefix))
        self.assertIn("Exec=/usr/bin/example --flag %U", hidden_text)
        self.assertIn("Icon=example", hidden_text)
        self.assertIn("X-User-Value=preserve", hidden_text)
        self.assertIn("Hidden=true", hidden_text)

        autostart.set_hidden("example.desktop", False)
        self.assertIn("Hidden=false", path.read_text(encoding="utf-8"))

    def test_invalid_entry_is_listed_and_can_be_deleted(self) -> None:
        path = self.user_directory() / "broken.desktop"
        path.write_text("not a desktop entry\n", encoding="utf-8")

        entries = autostart.list_entries()["entries"]

        self.assertEqual(len(entries), 1)
        self.assertFalse(entries[0]["valid"])
        autostart.delete_user("broken.desktop")
        self.assertFalse(path.exists())

    def test_path_traversal_is_sanitized_inside_user_directory(self) -> None:
        self.user_directory()

        path = autostart.add_application(
            "../../outside.desktop", "安全测试", "/usr/bin/test", ""
        )

        self.assertEqual(path.parent, self.config / "autostart")
        self.assertTrue(path.exists())
        self.assertFalse((self.config / "outside.desktop").exists())

    def test_system_entry_cannot_be_toggled_or_deleted(self) -> None:
        system_entry = self.write_system_entry("system.desktop")

        with self.assertRaises(autostart.AutostartError):
            autostart.set_hidden("system.desktop", True)
        with self.assertRaises(autostart.AutostartError):
            autostart.delete_user("system.desktop")

        self.assertIn("Hidden=false", system_entry.read_text(encoding="utf-8"))

    def test_symlinked_user_directory_is_rejected(self) -> None:
        target = self.root / "real-autostart"
        target.mkdir()
        self.config.mkdir(parents=True, exist_ok=True)
        (self.config / "autostart").symlink_to(target, target_is_directory=True)

        with self.assertRaises(autostart.AutostartError):
            autostart.list_entries()


if __name__ == "__main__":
    unittest.main()
