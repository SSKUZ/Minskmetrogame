#!/usr/bin/env python3
"""Refresh dependency warmup metadata in an existing, unchanged module export."""
import json,sys
from pathlib import Path
out=Path(sys.argv[1]);manifest=json.loads((out/'module-packs.json').read_text());report=json.loads((out/'pack-resources.json').read_text())
for group,paths in report['resources'].items():
    manifest['packs'][group]['warmup']=[p.removesuffix('.remap') for p in paths if p.endswith(('.png.remap','.jpg.remap','.jpeg.remap','.webp.remap','.svg.remap'))]
(out/'module-packs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
