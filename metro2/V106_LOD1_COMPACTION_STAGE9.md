# V106 Mobile — Stage 9: GLB compaction after mesh289 LOD1
Date: 2026-10-31. **Experimental, not integrated.**

Repacked prior experimental car01 GLB by removing unused accessors and bufferViews, remapping references, and deduplicating byte-identical views. Original GLB materials and textures were not modified. Result loaded successfully as a scene by Python trimesh, **325 geometry objects**.

| File | Size, bytes |
|---|---:|
| Original car01 | 32 324 584 |
| Previous welded v3 car01 | 24 254 600 |
| Previous LOD experiment with orphan buffers | 30 503 720 |
| **Stage 9 compact LOD experiment** | **22 181 156** |

Mesh #289: 86 720 → 65 040 triangles (−25%, −21 680). Other meshes are unchanged by the LOD algorithm. Approx. 3.22 MB smaller than welded v3; ~10.14 MB smaller than original car01.

SHA256 compact experiment: `a86a17006692323ae7b4760426fbc143d53b36001be65a9e74e7f9b010e4e9c5`.

**Caveats:** `trimesh` parsing is not equivalent to Godot 4.3 import. Visual appearance, UV seams, normals, transparency, door animation and Android FPS have **not** been validated. LOD1 for other cars **not performed**. Do not replace production model until visual/engine acceptance. No modifications to original files, gloss or textures.
