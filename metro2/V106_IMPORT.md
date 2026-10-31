# V106 static assembly — TZ4

Open `metro2/project.godot` in Godot 4.3 and run `res://scenes/V106Consist.tscn`.
The existing `metro2/android-prototype` project is unchanged and is intentionally ignored by the viewer resource scanner.

Four supplied GLBs were copied byte-for-byte to `metro2/assets/v106/` for local verification.

**GitHub text-only fallback:** models are NOT included in this commit. Download the four original GLBs supplied in chat, place all four under `metro2/assets/v106/`, then open `metro2/project.godot`. Godot extracts embedded PNGs and builds its import cache automatically. The repository alone is not a complete model distribution. Local Git push could not authenticate; text files were saved through the authenticated GitHub API.
Each GLB instance has identity wrapper transforms. Original car transforms and the 180-degree tail orientation are inside the imported models. No extra spacing, scale or rotation is applied. Intercar connections are owned by cars 1–3 only.

## Verification
Godot 4.3 headless editor import completed with exit 0. Loading and instantiating the assembled scene completed with exit 0 and no runtime errors.

| Car | Meshes | Triangles | Z range, metres |
|---|---:|---:|---|
| 1 | 325 | 591259 | -10.055 .. 10.3555 |
| 2 | 162 | 492910 | 9.994 .. 30.3615 |
| 3 | 162 | 492910 | 30.000 .. 50.3675 |
| 4 | 320 | 590883 | 50.006 .. 70.073 |

Total: 969 meshes and 2167962 triangles, matching the exported source. Each GLB contains 16 door-leaf registry entries and 16 warning decals. Their geometry, interiors, bogies, embedded images and transparent glTF materials are retained. Z ranges match the supplied reference; connection extents overlap and do not indicate body spacing errors.

No graphical display or Xvfb is installed. Visual appearance, glazing and decal readability have not been visually accepted; no screenshots were produced. Godot import warned about one non-finite face normal during automatic LOD generation; it did not block import. Nested project warning is expected.

Known export limitations: Arial substituted with Nimbus Sans Bold; Three.js environment PMREM recipe and non-glTF rendering properties are extras and are not automatically applied by Godot. The viewer uses simple neutral lighting; materials were not reworked.

## SHA-256 of original models

- `v106_car_01.glb` (32324584 bytes): `40d1d00e66e2bbd4429579f82ecda65a749f5301ff38ced5b5b5193f76c20c4f`
- `v106_car_02.glb` (28658552 bytes): `bf3fac63153e28b9d250d437e95c2f2fd2dfc17b9c750a399bf559c34769cd5b`
- `v106_car_03.glb` (28658552 bytes): `7160a2db252a4a641c80555acd9d0351f2f488e230068980f32eb287333676e1`
- `v106_car_04.glb` (32305384 bytes): `a0257eeca3c8f6e2959025d34dbc3934449901f823ef5668716fc3716d14a6aa`
