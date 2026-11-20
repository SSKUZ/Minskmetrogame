# Ploshchad Lenina V67

Independent module: `modules/stations/ploshchad_lenina/ploshchad_lenina.tscn`. See its `REFERENCES.md` for photo mapping, the genuine platform opening and descending stairs.

Regenerate artwork: `python3 metro2/tools/lenina_photo_v67/build_art.py --photos /path/to/extracted/archive` (Pillow, numpy, fontTools, ffprobe). Original photos/videos remain private.

The CI imports/exports this module and menu support only, preserves all existing published packs, patches the catalog/menu and publishes a hashed station PCK. No scene, game or browser tests.
