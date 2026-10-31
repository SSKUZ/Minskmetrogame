# Restore saved GLB

From the repository root, run:

```sh
python3 metro2/assets/v106_mobile/restore_glb.py
```

Keep all 54 files in `parts/` and `manifest.json`. The script checks each part, restores `v106_car01_mobile.glb` beside itself, and verifies the complete SHA-256 before replacing the output.

Size: 21,216,508 bytes.
SHA-256: `aed209d835f6f2a50090cbcbe283ec1467853a2d598591801196618f8ae4c48a`.
