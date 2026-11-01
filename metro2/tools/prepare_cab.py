#!/usr/bin/env python3
"""Restore and verify original cab GLB before Godot import. No APK/build."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
cab = root / "assets" / "cab"
manifest = json.loads((cab / "parts" / "manifest.json").read_text(encoding="utf-8"))
target = cab / manifest["filename"]
if manifest["filename"] != "cab_81_717_r2.glb":
    raise SystemExit("Unexpected cab filename")
if manifest.get("units") != "meters" or manifest.get("root_scale") != [1, 1, 1]:
    raise SystemExit("Cab export units/scale mismatch")
if len(manifest["parts"]) != manifest["part_count"]:
    raise SystemExit("Cab parts count mismatch")

def valid_file() -> bool:
    if not target.is_file() or target.stat().st_size != manifest["size"]:
        return False
    digest = hashlib.sha256()
    with target.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest() == manifest["sha256"]

if not valid_file():
    subprocess.run([sys.executable, str(cab / "restore_glb.py")], check=True)
if not valid_file():
    raise SystemExit("Cab GLB SHA-256 validation failed")
print("BLOCK A original cab verified:", target, manifest["sha256"])
