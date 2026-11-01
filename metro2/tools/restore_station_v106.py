#!/usr/bin/env python3
"""Restore the four already saved wagons for station_v106_preview.tscn."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
root = Path(__file__).resolve().parents[1]
for relative in ("v106_lod1", "v106_original/car02", "v106_original/car03", "v106_original/car04"):
    folder = root / "assets" / relative
    manifest = json.loads((folder / "parts/manifest.json").read_text())
    output = folder / manifest["filename"]
    if not (output.is_file() and output.stat().st_size == manifest["size"] and hashlib.sha256(output.read_bytes()).hexdigest() == manifest["sha256"]):
        subprocess.run([sys.executable, str(folder / "restore_glb.py")], check=True)
    print("PASS", relative, manifest["sha256"])
