#!/usr/bin/env python3
"""Restore only missing/corrupt original train GLBs required by first playable.
No geometry changes, no Godot editor, no APK.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
folders = [
    root / "assets/v106_lod1",
    root / "assets/v106_original/car02",
    root / "assets/v106_original/car03",
    root / "assets/v106_original/car04",
]

def verified(path: Path, manifest: dict) -> bool:
    if not path.is_file() or path.stat().st_size != manifest["size"]:
        return False
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest() == manifest["sha256"]

for folder in folders:
    manifest = json.loads((folder / "parts/manifest.json").read_text(encoding="utf-8"))
    target = folder / manifest["filename"]
    if not verified(target, manifest):
        print("Restoring required car:", target)
        subprocess.run([sys.executable, str(folder / "restore_glb.py")], check=True)
    if not verified(target, manifest):
        raise SystemExit("GLB checksum mismatch: " + str(target))
    print("Verified:", target, manifest["sha256"])
