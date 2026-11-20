# Oktyabrskaya V66 owner-reference build

New independent module: `modules/stations/oktyabrskaya/oktyabrskaya.tscn`. Architectural documentation and transfer clearances are in its `REFERENCES.md`.

Regenerate isolated artwork with `python3 metro2/tools/oktyabrskaya_photo_v66/build_art.py --photos /path/to/extracted/archive` (Pillow, numpy, fontTools, ffprobe). The source archive remains private. The script builds clean stone/amber/oak samples, photographed lettering cutouts, isolated end-frieze sections with height data, outlined bilingual signs and reference manifests.

The CI workflow snapshots the current gh-pages viewer, imports/exports only this station and menu support scripts, patches two boot scripts, and adds the hashed station PCK plus updated catalog/metadata. Existing station/train packs are retained. Mandatory resource import and export only; no game/scene/browser or performance testing.
