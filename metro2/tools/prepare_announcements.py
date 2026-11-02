#!/usr/bin/env python3
"""Copy existing browser announcement recordings into Godot project before import."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[2]
destination = root / "metro2" / "audio"
destination.mkdir(parents=True, exist_ok=True)
for filename in ("malinovka_arrival.mp3", "malinovka_departure_petrovshchina.mp3"):
    source = root / "audio" / filename
    if not source.is_file():
        raise SystemExit(f"Missing browser audio: {source}")
    shutil.copy2(source, destination / filename)
    print(f"ANNOUNCEMENT_READY {filename}")
