# Yakuba Kolasa owner-photo reconstruction V64

Run `build_art.py --photos /path/to/extracted/archive` to recreate isolated texture crops, relief normals, sampled relief heights and the thirteen-pair source inventory. Authoring coordinates are measured against a 400px-wide EXIF-corrected reference. Dependencies: Pillow, NumPy, fontTools. No authoring dependency is needed at runtime.

Publication follows the existing station-only workflow: snapshot live gh-pages, import this module, generate mipmaps, export its native Godot 4.3 Web PCK, patch the current boot menu/catalog and publish hashed files. No scene is instantiated and no tests are run. Runtime JSON height samples must remain included in the pack.
