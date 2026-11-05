#!/usr/bin/env python3
"""Restore the exact original cab saved at 547fb8742; never re-export a model."""
from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(__file__).resolve().parents[1]/'assets/cab_original_v33'
manifest=json.loads((root/'parts/manifest.json').read_text())
expected='2a3f37650722ba667f61f9cd063d4a3c7795fed37bc85285dd4c01c29b91d1e6'
assert manifest['sha256']==expected and manifest['filename']=='cab_81_717.glb'
target=root/manifest['filename']
if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest()!=expected:
    subprocess.run([sys.executable,str(root/'restore_glb.py')],check=True)
assert target.stat().st_size==5180668 and hashlib.sha256(target.read_bytes()).hexdigest()==expected
print('Original cab verified:',expected)
