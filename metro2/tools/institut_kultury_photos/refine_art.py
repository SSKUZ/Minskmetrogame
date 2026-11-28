"""Rebuild only corrected Institut Kultury surfaces from the owner's original photographs."""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image, ImageOps, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'modules/stations/institut_kultury/art'
p = argparse.ArgumentParser()
p.add_argument('--photos', type=Path, required=True)
args = p.parse_args()
records = json.loads((OUT / 'owner_sources.json').read_text())

def source(stem):
    path = args.photos / ('20261122_' + stem + '.jpg')
    image = ImageOps.exif_transpose(Image.open(path)).convert('RGB')
    image.thumbnail((1500, 1200))
    return path, image

def record(stem, asset, coordinates, treatment):
    path, _ = source(stem)
    records[:] = [r for r in records if r.get('asset') != asset]
    records.append(dict(source=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                        asset=asset, coordinates_at_preview_1500x1200=coordinates,
                        treatment=treatment))

def stone(stem, asset, rect, target):
    _, image = source(stem)
    # Select an uninterrupted slab interior, then remove large photographic light gradients.
    # Never mirror a perspective photograph: that creates repeating diamond patterns.
    image = image.crop(rect).resize((512, 512), Image.Resampling.LANCZOS)
    a = np.asarray(image, dtype=float)
    low = np.asarray(image.filter(ImageFilter.GaussianBlur(24)), dtype=float)
    grain = a - low
    y, x = np.mgrid[:512, :512]
    weight = (np.sin(np.pi*x/512)**2 * np.sin(np.pi*y/512)**2)[..., None]
    total = np.zeros_like(a)
    weights = np.zeros((512, 512, 1))
    for dy, dx in [(0,0), (256,0), (0,256), (256,256)]:
        w = np.roll(weight, (dy, dx), (0,1))
        total += np.roll(grain, (dy, dx), (0,1)) * w
        weights += w
    image = Image.fromarray(np.uint8(np.clip(total / weights + np.array(target), 0, 255)))
    image.save(OUT / asset, quality=93)
    record(stem, asset, rect, 'Uninterrupted stone; high-pass lighting removal; periodic overlapping grain, no mirroring')

stone('172347', 'wall_granite.jpg', (820,380,1000,430), (139,121,104))
stone('172154', 'vestibule_marble.jpg', (100,300,180,330), (192,190,179))
stone('172154', 'stair_granite.jpg', (400,738,740,752), (145,141,131))

# Preserve the actual photographed direction, highlighted station and transfer labels.
_, image = source('172040')
size = (1600, 360)
corners = [(398,490), (1173,490), (1180,661), (387,665)]
a, b = [], []
for (u,v), (x,y) in zip([(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)], corners):
    a.extend([[u,v,1,0,0,0,-x*u,-x*v], [0,0,0,u,v,1,-y*u,-y*v]])
    b.extend([x,y])
h = np.linalg.solve(np.array(a), np.array(b))
image = image.transform(size, Image.Transform.PERSPECTIVE, h, Image.Resampling.BICUBIC)
image.save(OUT / 'wall_route_photo.jpg', quality=95)
record('172040', 'wall_route_photo.jpg', corners, 'Perspective-rectified complete original route board')
(OUT / 'owner_sources.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
