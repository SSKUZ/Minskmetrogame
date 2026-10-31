# V106 Stage 10 — independent numerical LOD1 geometry validation
Date: 2026-10-31. Input: local welded v3 car01 GLB vs compact mesh289 LOD1 car01 GLB.

**Real test executed** using numpy and VTK 9.6 on original and experimental GLB, not a hypothetical proposal.

- Meshes: 325 vs 325; material JSON equal; embedded images: 5 vs 5.
- **Only mesh index 289 changed** (original 86,720 triangles, LOD1 65,040).
- Mesh289 axis-aligned bounds **identical**:
  X -1.1985226..1.1985226, Y 1.3785000..1.9741331, Z -5.5130000..9.2430000 meters.
- Bidirectional VTK `vtkDistancePolyDataFilter` unsigned surface distances, sampled at source vertices:
  - Original → LOD: mean **0.000004621 m**, P99 **0.000106216 m**, max **0.000106801 m** (~**0.107 mm**).
  - LOD → Original: mean **0.000000316 m**, P99 **0.000024067 m**, max **0.000027609 m** (~**0.028 mm**).
- Mesh 289 triangle reduction: **21,680 (25%)**. Whole car original 591,259 → **569,579** triangles (~3.67% fewer). Other 3 cars unchanged.
- GLB file: welded v3 24,254,600 bytes → compact LOD1 22,181,156 bytes.

**Interpretation:** the simplified mesh's sampled surface positions are extremely close to the original, but this is **not** a formal Hausdorff bound over continuous surfaces. It does not validate UVs, shading, normals, transparency, texture seams, material behavior, door animation or Godot rendering. Numeric near-zero geometry error does **not** prove pixel identity.

**Acceptance:** keep as an experimental GLB; do not replace production asset until Godot 4.3 visual import and door regression tests. No changes to original GLBs or appearance settings.
