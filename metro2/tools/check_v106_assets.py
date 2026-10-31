#!/usr/bin/env python3
"""Offline preflight for the original four-car V106 Godot scene (no Godot needed)."""
from pathlib import Path
import hashlib
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "v106"
EXPECTED = {
    "v106_car_01.glb": (32324584, "40d1d00e66e2bbd4429579f82ecda65a749f5301ff38ced5b5b5193f76c20c4f"),
    "v106_car_02.glb": (28658552, "bf3fac63153e28b9d250d437e95c2f2fd2dfc17b9c750a399bf559c34769cd5b"),
    "v106_car_03.glb": (28658552, "7160a2db252a4a641c80555acd9d0351f2f488e230068980f32eb287333676e1"),
    "v106_car_04.glb": (32305384, "a0257eeca3c8f6e2959025d34dbc3934449901f823ef5668716fc3716d14a6aa"),
}

def main():
    errors = []
    for name, (expected_size, expected_hash) in EXPECTED.items():
        path = ASSETS / name
        if not path.is_file():
            errors.append(f"MISSING: {path}")
            continue
        size = path.stat().st_size
        with path.open("rb") as stream:
            header = stream.read(12)
        if len(header) != 12:
            errors.append(f"TRUNCATED: {name}")
            continue
        magic, version, declared_size = struct.unpack("<4sII", header)
        if (magic, version, declared_size) != (b"glTF", 2, size):
            errors.append(f"INVALID GLB HEADER: {name}")
        if size != expected_size:
            errors.append(f"SIZE MISMATCH: {name}: {size} != {expected_size}")
        h = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                h.update(chunk)
        if h.hexdigest() != expected_hash:
            errors.append(f"SHA256 MISMATCH: {name}")
        else:
            print(f"OK: {name} ({size} bytes)")
    scene = ROOT / "scenes" / "StationV106Integration.tscn"
    if not scene.is_file():
        errors.append(f"MISSING SCENE: {scene}")
    else:
        text = scene.read_text(encoding="utf-8")
        for name in EXPECTED:
            if name not in text:
                errors.append(f"SCENE MISSING REFERENCE: {name}")
        if "StationBaseStatic.tscn" not in text:
            errors.append("SCENE MISSING STATION REFERENCE")
        if "Vector3(0, 0.22, 9.603)" not in text:
            errors.append("SCENE TRAIN Y PLACEMENT NOT FOUND")
    for error in errors:
        print(error, file=sys.stderr)
    print(f"Preflight: {'FAIL' if errors else 'PASS'}")
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main())
