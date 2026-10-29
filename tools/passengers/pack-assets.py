"""Deduplicate GLB images, cap texture sizes, and record verifiable asset budgets.

Input: medium and low GLBs exported by the pinned Ara/MakeHuman build in README.
No mesh generation or texture downloads occur at game runtime.
"""
import hashlib
import io
import json
import struct
from pathlib import Path
from PIL import Image, ImageFile

# Two upstream JPGs omit their final scan marker. Re-encoding produces complete images.
ImageFile.LOAD_TRUNCATED_IMAGES = True

ROOT = Path(__file__).resolve().parents[2] / 'assets/passengers'
TEX = ROOT / 'textures'
TEX.mkdir(exist_ok=True)
models = []
for path in sorted(ROOT.glob('*.glb')):
    data = path.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+length])
    blob = data[28+length:]
    images = set()
    for image in doc.get('images', []):
        if 'bufferView' not in image:
            continue
        view_id = image.pop('bufferView')
        images.add(view_id)
        view = doc['bufferViews'][view_id]
        start = view.get('byteOffset', 0)
        raw = blob[start:start+view['byteLength']]
        im = Image.open(io.BytesIO(raw))
        limit = 512 if 'hair' in image.get('name', '') else 1024
        im.thumbnail((limit, limit), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        transparent = 'A' in im.getbands() or 'transparency' in im.info
        im = im.convert('RGBA' if transparent else 'RGB')
        ext = '.png' if transparent else '.jpg'
        im.save(out, format='PNG' if ext == '.png' else 'JPEG', quality=87, optimize=True)
        raw = out.getvalue()
        name = hashlib.sha256(raw).hexdigest()[:16] + ext
        (TEX / name).write_bytes(raw)
        image['uri'] = 'textures/' + name
        image.pop('mimeType', None)
    if images:
        buffer = bytearray()
        views = []
        remap = {}
        for i, view in enumerate(doc['bufferViews']):
            if i in images:
                continue
            remap[i] = len(views)
            start = view.get('byteOffset', 0)
            part = blob[start:start+view['byteLength']]
            views.append({**view, 'byteOffset': len(buffer)})
            buffer.extend(part)
            buffer.extend(b'\0' * (-len(buffer) % 4))
        for accessor in doc['accessors']:
            if 'bufferView' in accessor:
                accessor['bufferView'] = remap[accessor['bufferView']]
            for key in ('indices', 'values'):
                if key in accessor.get('sparse', {}):
                    accessor['sparse'][key]['bufferView'] = remap[accessor['sparse'][key]['bufferView']]
        doc['bufferViews'] = views
        doc['buffers'] = [{'byteLength': len(buffer)}]
        raw_json = json.dumps(doc, separators=(',', ':')).encode()
        raw_json += b' ' * (-len(raw_json) % 4)
        path.write_bytes(struct.pack('<III', 0x46546C67, 2, 28+len(raw_json)+len(buffer))
                         + struct.pack('<II', len(raw_json), 0x4E4F534A) + raw_json
                         + struct.pack('<II', len(buffer), 0x004E4942) + buffer)
    primitives = doc['meshes'][0]['primitives']
    pos = doc['accessors'][primitives[0]['attributes']['POSITION']]
    models.append({'file': path.name, 'bytes': path.stat().st_size,
                   'triangles': sum(doc['accessors'][p['indices']]['count']//3 for p in primitives),
                   'vertices': pos['count'], 'bounds': [pos.get('min'), pos.get('max')],
                   'bones': len(doc['skins'][0]['joints']),
                   'animations': [a['name'] for a in doc.get('animations', [])]})
(ROOT/'manifest.json').write_text(json.dumps({'models': models,
    'textureBytes': sum(p.stat().st_size for p in TEX.iterdir()),
    'generator': 'Ara 3D Gen / MakeHuman CC0; +Y up, +Z forward, metres'}, indent=2)+'\n')
print(json.dumps({'models': len(models), 'geometryMB': round(sum(m['bytes'] for m in models)/1e6, 2),
                  'texturesMB': round(sum(p.stat().st_size for p in TEX.iterdir())/1e6, 2)}))
