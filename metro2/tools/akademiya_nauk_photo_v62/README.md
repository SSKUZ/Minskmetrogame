# Академия наук V62

`build_art.py --photos /path/to/owner/uploads` produces only the station's local art. Pillow, NumPy and fontTools are needed for authoring, not for runtime or CI. Source frames are sampled with ffmpeg at 4fps across the full owner video.

The publication workflow snapshots gh-pages, imports and exports only this module, patches the existing boot catalog/menu and adds a hashed lazy-loaded pack. No scene is instantiated and no tests are run. The permanent viewer URL remains unchanged.
