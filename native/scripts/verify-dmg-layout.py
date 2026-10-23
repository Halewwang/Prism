#!/usr/bin/env python3
"""Check the installed DMG layout using the project's existing dmg-builder."""
from pathlib import Path
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "node_modules/dmg-builder/vendor"))
from ds_store import DSStore
from mac_alias import Alias, kBookmarkPath

mount = Path(sys.argv[1])
assert (mount / "Prism.app").is_dir()
assert (mount / "Applications").is_symlink()
assert os.readlink(mount / "Applications") == "/Applications"
assert (mount / ".background/install.png").is_file()
with DSStore.open(str(mount / ".DS_Store"), "r") as store:
    bounds = store["."]["bwsp"]
    assert bounds["WindowBounds"] == "{{200, 200}, {640, 400}}"
    assert bounds["ShowToolbar"] is False
    assert bounds["ShowStatusBar"] is False
    assert bounds["ShowPathbar"] is False
    assert store["."]["icvl"] == (b"type", b"icnv")
    assert store["Prism.app"]["Iloc"] == (175, 160)
    assert store["Applications"]["Iloc"] == (465, 160)
    options = store["."]["icvp"]
    assert options["backgroundType"] == 2
    assert options["iconSize"] == 112.0
    background_path = Alias.from_bytes(options["backgroundImageAlias"]).target.posix_path
    assert background_path == "/.background/install.png", repr(background_path)
    assert store["."]["pBBk"][kBookmarkPath] == [".background", "install.png"]
print("Installer layout verified: 640×400, local background, Prism → Applications.")
