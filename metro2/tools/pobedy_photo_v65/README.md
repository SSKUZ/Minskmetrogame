# Ploshchad Pobedy owner-reference publication V65

Source: `modules/stations/ploshchad_pobedy/`. New independent station 117 based on Station Base, reconstructed from 40 owner photographs and both owner videos.

Rebuild artwork: `python3 metro2/tools/pobedy_photo_v65/build_art.py --photos /path/to/extracted/archive` (Pillow, numpy, fontTools, ffprobe). Includes rectified photographic names and platform/exit signs, isolated stone and monitor crops, plaster normal map, outlined two-way route maps and a source manifest. Raw archive is not committed.

Workflow `metro2-pobedy-photo-v65.yml` snapshots the current gh-pages viewer, imports and exports only this station and the menu support scripts, patches the boot PCK, and writes newly hashed packs and updated catalog/metadata back to the permanent viewer. Shared publication concurrency prevents competing station publishers. Existing packs are retained. Mandatory build commands only; no gameplay or visual testing.
