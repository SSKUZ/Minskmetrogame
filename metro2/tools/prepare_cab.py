#!/usr/bin/env python3
"""Prepare the original cab-r2 GLB for Godot import (no modelling/optimization).
Run BEFORE opening Godot or invoking --editor --import.
"""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
cab = root / "assets" / "cab"
result = subprocess.run([sys.executable, str(cab / "restore_glb.py")], check=False)
if result.returncode:
    raise SystemExit(result.returncode)
target = cab / "cab_81_717_r2.glb"
if not target.is_file() or target.stat().st_size != 5184476:
    raise SystemExit("Cab GLB restore failed")
print("Original cab-r2 ready for Godot import:", target)
