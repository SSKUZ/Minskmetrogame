#!/usr/bin/env python3
"""Lossless GLB bufferView deduplication; Python 3 stdlib only.

Usage: python3 metro2/tools/optimize_v106_lossless.py original.glb optimized.glb
This never simplifies geometry. Verify in Godot 4.3 before using in the game.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path

def read(path):
    data = path.read_bytes()
    assert data[:4] == b"glTF" and struct.unpack_from("<I", data, 4)[0] == 2
    assert struct.unpack_from("<I", data, 8)[0] == len(data)
    pos = 12
    chunks = []
    while pos < len(data):
        size, kind = struct.unpack_from("<I4s", data, pos)
        pos += 8
        chunks.append((kind, data[pos:pos + size]))
        pos += size
    assert len(chunks) == 2 and chunks[0][0] == b"JSON" and chunks[1][0] == b"BIN\x00"
    return json.loads(chunks[0][1]), chunks[1][1]

def optimize(source, destination):
    doc, blob = read(source)
    original_views = [dict(v) for v in doc["bufferViews"]]
    assert len(doc["buffers"]) == 1
    packed = bytearray()
    known = {}
    duplicates = 0
    for view in doc["bufferViews"]:
        start = view.get("byteOffset", 0)
        payload = blob[start:start + view["byteLength"]]
        assert len(payload) == view["byteLength"]
        key = (hashlib.sha256(payload).digest(), len(payload), view.get("target"), view.get("byteStride"))
        if key in known:
            offset = known[key]
            duplicates += 1
        else:
            packed.extend(b"\0" * (-len(packed) % 4))
            offset = len(packed)
            packed.extend(payload)
            known[key] = offset
        view["byteOffset"] = offset
    packed.extend(b"\0" * (-len(packed) % 4))
    doc["buffers"][0]["byteLength"] = len(packed)
    encoded = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    encoded += b" " * (-len(encoded) % 4)
    total = 12 + 8 + len(encoded) + 8 + len(packed)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(encoded), b"JSON"))
        f.write(encoded)
        f.write(struct.pack("<I4s", len(packed), b"BIN\x00"))
        f.write(packed)
    result, result_blob = read(destination)
    assert len(result["bufferViews"]) == len(original_views)
    for before, after in zip(original_views, result["bufferViews"]):
        old = blob[before.get("byteOffset", 0):before.get("byteOffset", 0) + before["byteLength"]]
        new = result_blob[after["byteOffset"]:after["byteOffset"] + after["byteLength"]]
        assert old == new, "BufferView changed!"
    assert len(result["meshes"]) == len(doc["meshes"])
    print(json.dumps({"input": str(source), "output": str(destination),
        "old_bytes": source.stat().st_size, "new_bytes": destination.stat().st_size,
        "duplicate_views_removed": duplicates,
        "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()}, indent=2))

if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: optimize_v106_lossless.py original.glb optimized.glb")
    optimize(Path(sys.argv[1]), Path(sys.argv[2]))
