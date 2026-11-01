#!/usr/bin/env python3
"""Restore the saved GLB; verify every part and the complete file."""
from pathlib import Path
import hashlib
import json
import os

root = Path(__file__).resolve().parent
manifest = json.loads((root / "parts/manifest.json").read_text())
output = root / manifest["filename"]
temporary = output.with_suffix(".glb.tmp")
try:
    digest = hashlib.sha256()
    total = 0
    with temporary.open("wb") as target:
        for part in manifest["parts"]:
            data = (root / "parts" / part["name"]).read_bytes()
            if len(data) != part["size"] or hashlib.sha256(data).hexdigest() != part["sha256"]:
                raise ValueError("Invalid part: " + part["name"])
            target.write(data)
            digest.update(data)
            total += len(data)
    if total != manifest["size"] or digest.hexdigest() != manifest["sha256"]:
        raise ValueError("Restored GLB checksum mismatch")
    os.replace(temporary, output)
finally:
    temporary.unlink(missing_ok=True)
print(str(output))
print(str(total) + " bytes; SHA-256: " + digest.hexdigest())
