# Vostok photo reconstruction V59

`build_art.py --photos PATH` rebuilds outlined bilingual signage and small sampled textures from the supplied photo set. It requires Python, Pillow, NumPy, fontTools and system DejaVu fonts; it never modifies another station.

`publish.py prepare OUTPUT GH_PAGES_SHA`, `build OUTPUT`, `finish OUTPUT` use the existing minimal export workflow to replace only the Vostok pack in the live viewer manifest. Other packs, viewer boot, runtime and controls are retained. The GitHub workflow serialises publication with other module updates.

Import/export logs and a SHA-256-addressed Vostok pack are retained as workflow artifacts. Metric reconstruction assumptions and photo mapping are recorded in the station's REFERENCES.md.
