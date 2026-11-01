#!/usr/bin/env python3
"""Prepare existing GLB assets for the first playable Godot import; no modeling."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CAB = ROOT / "assets/cab"
MANIFEST = CAB / "parts/manifest.json"

def main() -> int:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    target = CAB / data["filename"]
    expected = data["sha256"]
    if target.exists() and target.stat().st_size == data["size"]:
        if hashlib.sha256(target.read_bytes()).hexdigest() == expected:
            print("PASS: cab GLB already restored and verified")
        else:
            print("FAIL: existing cab GLB has wrong checksum; refusing to overwrite", file=sys.stderr)
            return 1
    elif target.exists():
        print("FAIL: existing cab GLB has wrong size; refusing to overwrite", file=sys.stderr)
        return 1
    else:
        subprocess.run([sys.executable, str(CAB / "restore_glb.py")], check=True)
        if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest() != expected:
            print("FAIL: restored cab GLB failed verification", file=sys.stderr)
            return 1
    expected_cars = {
        1: (32324584, "40d1d00e66e2bbd4429579f82ecda65a749f5301ff38ced5b5b5193f76c20c4f"),
        2: (28658552, "bf3fac63153e28b9d250d437e95c2f2fd2dfc17b9c750a399bf559c34769cd5b"),
        3: (28658552, "7160a2db252a4a641c80555acd9d0351f2f488e230068980f32eb287333676e1"),
        4: (32305384, "a0257eeca3c8f6e2959025d34dbc3934449901f823ef5668716fc3716d14a6aa"),
    }
    for number, (expected_size, expected_sha) in expected_cars.items():
        car = ROOT / f"assets/v106/v106_car_{number:02d}.glb"
        if not car.is_file():
            print(f"FAIL: original wagon missing: {car}. Supply previously exported GLB; DO NOT re-export.", file=sys.stderr)
            return 1
        if car.stat().st_size != expected_size or hashlib.sha256(car.read_bytes()).hexdigest() != expected_sha:
            print(f"FAIL: original wagon {number:02d} size/SHA256 mismatch: {car}", file=sys.stderr)
            return 1
        print(f"PASS: original wagon {number:02d}: {expected_size} bytes, SHA256 verified")
    print("PASS: all five GLBs available. Open project in Godot 4.3 to import and inspect.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
