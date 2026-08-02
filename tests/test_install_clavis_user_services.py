from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import tempfile
import unittest


SOURCE_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = SOURCE_ROOT / "scripts/system/install-clavis-user-services.py"
SPEC = importlib.util.spec_from_file_location("install_clavis_user_services", MODULE_PATH)
assert SPEC and SPEC.loader
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class UserServiceInstallerTests(unittest.TestCase):
    def test_renders_stable_key_and_never_starts_units(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-service-install-test.") as name:
            root = Path(name)
            source = root / "source"
            target = root / "target"
            source.mkdir()
            key = root / "bin/key"
            key.parent.mkdir()
            key.write_text("#!/bin/sh\n", encoding="utf-8")
            key.chmod(0o700)
            for unit, command in (
                ("clavis-shell.service", "shell --foreground --no-duplicate"),
                ("clavis-clipboard.service", "clipboard watch"),
            ):
                (source / unit).write_text(
                    "[Unit]\nPartOf=niri.service\n[Service]\n"
                    f"ExecStart=@CLAVIS_KEY@ {command}\nRestart=on-failure\n"
                    "[Install]\nWantedBy=niri.service\n",
                    encoding="utf-8",
                )
            installed = installer.install(source, target, key)
            self.assertEqual({path.name for path in installed}, set(installer.UNITS))
            shell = (target / "clavis-shell.service").read_text(encoding="utf-8")
            self.assertIn(f'ExecStart="{key}" shell --foreground', shell)
            self.assertNotIn("systemctl", shell)

    def test_missing_second_template_writes_nothing(self) -> None:
        with tempfile.TemporaryDirectory(prefix="clavis-service-failure-test.") as name:
            root = Path(name)
            source = root / "source"
            target = root / "target"
            source.mkdir()
            key = root / "key"
            key.write_text("#!/bin/sh\n", encoding="utf-8")
            key.chmod(0o700)
            (source / installer.UNITS[0]).write_text(
                "PartOf=niri.service\n@CLAVIS_KEY@\nRestart=on-failure\n"
                "WantedBy=niri.service\n",
                encoding="utf-8",
            )
            with self.assertRaises(installer.UnitInstallError):
                installer.install(source, target, key)
            self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
