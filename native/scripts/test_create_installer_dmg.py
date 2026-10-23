"""Installer cleanup tests using fake tools; never create or mount a disk image."""

import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name("create-installer-dmg.sh")


class InstallerDMGTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory(prefix="prism-dmg-tests-")
        self.addCleanup(self.workspace.cleanup)
        self.root = pathlib.Path(self.workspace.name).resolve()
        self.script = self.root / "native/scripts/create-installer-dmg.sh"
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(SCRIPT, self.script)
        vendor = self.root / "node_modules/dmg-builder/vendor/dmgbuild/core.py"
        vendor.parent.mkdir(parents=True)
        vendor.touch()
        background = self.root / "native/Resources/Installer/install-background.png"
        background.parent.mkdir(parents=True)
        background.write_bytes(b"synthetic background")
        self.app = self.root / "Prism.app"
        self.app.mkdir()
        self.dmg = self.root / "output.dmg"
        self.calls = self.root / "hdiutil-calls.jsonl"
        self.temporary = self.root / "tmp"
        self.temporary.mkdir()
        commands = self.root / "commands"
        commands.mkdir()
        self.write_command(commands / "ditto", """
import shutil, sys
shutil.copytree(sys.argv[1], sys.argv[2])
""")
        self.write_command(commands / "hdiutil", """
import json, os, pathlib, sys
arguments = sys.argv[1:]
with open(os.environ["DMG_TEST_CALLS"], "a") as log:
    log.write(json.dumps(arguments) + "\\n")
if arguments[0] == "create":
    pathlib.Path(arguments[-1]).touch()
elif arguments[0] == "attach":
    mount = pathlib.Path(arguments[arguments.index("-mountpoint") + 1])
    (mount / "volume-sentinel").write_text("must survive failed detach")
    sys.exit(1)
elif arguments[0] == "detach":
    sys.exit(1)
else:
    sys.exit("unexpected disk image operation")
""")
        self.environment = {
            **os.environ,
            "PATH": str(commands) + os.pathsep + os.environ["PATH"],
            "TMPDIR": str(self.temporary),
            "DMG_TEST_CALLS": str(self.calls),
        }

    @staticmethod
    def write_command(path, source):
        path.write_text("#!" + sys.executable + "\n" + source)
        path.chmod(0o755)

    def run_script(self):
        return subprocess.run(
            ["/bin/zsh", str(self.script), str(self.app), str(self.dmg)],
            env=self.environment, capture_output=True, text=True, timeout=10,
        )

    def test_partial_attach_and_failed_detach_preserve_volume_contents(self):
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual([call[0] for call in calls], ["create", "attach", "detach"])
        mount = pathlib.Path(calls[1][calls[1].index("-mountpoint") + 1])
        self.assertEqual(calls[2], ["detach", str(mount), "-quiet"])
        self.assertEqual((mount / "volume-sentinel").read_text(), "must survive failed detach")
        self.assertIn(str(mount), result.stderr)
        self.assertFalse(self.dmg.exists())

    def test_existing_output_is_preserved_without_mounting(self):
        self.dmg.write_bytes(b"existing installer")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.dmg.read_bytes(), b"existing installer")
        self.assertFalse(self.calls.exists())
        self.assertEqual(list(self.temporary.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
