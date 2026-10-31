#!/usr/bin/env python3
"""Recompress PNG IDAT without changing decoded pixels or GLB geometry.
Run on copies of previously deduplicated GLB files; verify output in Godot.
The PNG filter scanlines and all non-IDAT PNG chunks remain unchanged.
"""
import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

def recompress_png(raw):
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        return raw
    pos = 8
    chunks, compressed = [], []
    while pos + 12 <= len(raw):
        length = struct.unpack_from(">I", raw, pos)[0]
        typ = raw[pos + 4:pos + 8]
        body = raw[pos + 8:pos + 8 + length]
        if len(body) != length:
            raise ValueError("Truncated PNG")
        chunks.append((typ, body))
        pos += 12 + length
        if typ == b"IDAT":
            compressed.append(body)
        if typ == b"IEND":
            break
    if not compressed:
        return raw
    scanlines = zlib.decompress(b"".join(compressed))
    packed = zlib.compress(scanlines, 9)
    if len(packed) >= sum(map(len, compressed)):
        return raw
    output = bytearray(raw[:8])
    emitted = False
    for typ, body in chunks:
        if typ == b"IDAT":
            if emitted:
                continue
            body = packed
            emitted = True
        output += struct.pack(">I", len(body)) + typ + body
        output += struct.pack(">I", zlib.crc32(typ + body))
    assert zlib.decompress(packed) == scanlines
    return bytes(output)

def process(source, target):
    data = source.read_bytes()
    if data[:4] != b"glTF" or struct.unpack_from("<I", data, 8)[0] != len(data):
        raise ValueError("Invalid GLB")
    json_length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_length])
    offset = 20 + json_length
    bin_length = struct.unpack_from("<I", data, offset)[0]
    binary = data[offset + 8:offset + 8 + bin_length]
    if len(doc["buffers"]) != 1:
        raise ValueError("Only single-buffer GLB supported")
    image_views = {image["bufferView"] for image in doc.get("images", [])
                   if image.get("mimeType") == "image/png" and "bufferView" in image}
    output = bytearray()
    reused = {}
    changes = 0
    for i, view in enumerate(doc["bufferViews"]):
        start = view.get("byteOffset", 0)
        payload = binary[start:start + view["byteLength"]]
        if i in image_views:
            revised = recompress_png(payload)
            changes += int(len(revised) < len(payload))
            payload = revised
        key = (hashlib.sha256(payload).digest(), len(payload),
               view.get("target"), view.get("byteStride"))
        if key not in reused:
            output += b"\0" * (-len(output) % 4)
            reused[key] = len(output)
            output += payload
        view["byteOffset"] = reused[key]
        view["byteLength"] = len(payload)
    output += b"\0" * (-len(output) % 4)
    doc["buffers"][0]["byteLength"] = len(output)
    header = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode()
    header += b" " * (-len(header) % 4)
    total = 12 + 8 + len(header) + 8 + len(output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(struct.pack("<4sII", b"glTF", 2, total)
                       + struct.pack("<I4s", len(header), b"JSON") + header
                       + struct.pack("<I4s", len(output), b"BIN\0") + output)
    print(f"{source.name}: {len(data)} -> {total} bytes; PNG images improved: {changes}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: optimize_v106_png_lossless.py input.glb output.glb")
    process(Path(sys.argv[1]), Path(sys.argv[2]))
