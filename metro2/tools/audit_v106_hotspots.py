#!/usr/bin/env python3
"""Read-only mesh hotspots for GLB 2.0. Usage: python audit_v106_hotspots.py car01.glb ..."""
import collections, json, struct, sys
from pathlib import Path
for filename in sys.argv[1:]:
    p=Path(filename); raw=p.read_bytes()
    assert raw[:4]==b"glTF" and struct.unpack_from("<I",raw,8)[0]==len(raw)
    length=struct.unpack_from("<I",raw,12)[0]
    gltf=json.loads(raw[20:20+length])
    owners=collections.defaultdict(list)
    for node in gltf["nodes"]:
        if "mesh" in node:
            owners[node["mesh"]].append(node.get("name","(unnamed)"))
    rows=[]
    for idx,mesh in enumerate(gltf["meshes"]):
        tris=sum((gltf["accessors"][prim["indices"]]["count"] if "indices" in prim
                  else gltf["accessors"][next(iter(prim["attributes"].values()))]["count"])//3
                 for prim in mesh["primitives"] if prim.get("mode",4)==4)
        rows.append((tris,idx,",".join(owners[idx][:2]),len(mesh["primitives"]),
                     ",".join(str(prim.get("material","-")) for prim in mesh["primitives"])))
    rows.sort(reverse=True)
    print(f"\n{p.name}: {sum(x[0] for x in rows):,} triangles; {len(rows)} meshes")
    print("triangles | mesh index | node | primitives | material indices")
    for row in rows[:20]:
        print(" | ".join(map(str,row)))
