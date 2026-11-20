# Московская / Маскоўская — owner-photo reconstruction V60

Authoritative visual references: all 31 supplied photographs 7865–7897 and videos 7879.mp4 (13.87 s), 7880.mp4 (8.33 s), supplied by the project owner on 19 November 2026. Both videos were reviewed across their complete duration at one-second frame intervals; full-resolution samples at 11.5 s and 2.6 s supply additional marble-inlay details. These references supersede the V58 assumptions about ceiling panels, stair decoration, benches and signage.

| References | Appearance used |
| --- | --- |
| 7868, 7871, 7874, 7887, 7894 | Red-brown granite rectangles; broad grey paving bands aligned with the columns; thin cream dividing lines; grey platform margin and yellow tactile strip |
| 7875 | Pale polished marble columns with narrow paired vertical channels, thin horizontal slab joints and a low black stone plinth |
| 7874, 7884, 7887, 7889 | High white centre ceiling; frequent narrow transverse ribs with rounded end transitions; lower side aisles; continuous rows of individual long diffusers on the inner upper girder edges |
| 7869–7870, 7877–7878, 7882, 7888, 7896–7897 and both videos | Pale veined marble walls, dark plinth, low-contrast architectural inlays assembled from contrasting marble; fine mouldings around the station lettering band |
| 7872–7873, 7890, 7893 | Separate bilingual side-hung track boards: track 1 toward 122–124, track 2 toward 120–110; station 121 highlighted; film studio, Makaenka and Volgogradskaya streets |
| 7866–7867 | Exit: Independence Avenue, Filimonov street, Belarusfilm studio |
| 7891–7892 | Opposite exit: Makaenka street, Belteleradiocompany, Volgogradskaya street, Belarusian State Agrarian Technical University |
| 7877, 7888 | Distinct diagonal route maps on the two track walls; 121 highlighted; 115/314 and 116/216 interchanges |
| 7895, 7876, 7894 | Five wide timber seat modules without backs, dark solid base and dividers; longitudinal benches between columns |
| 7865–7867, 7881, 7891 | Broad two-flight stairs, yellow nosings, full-height marble side walls, continuous stainless handrails, cable runs, white driver mirrors, red portal clocks and small CCTV screens |
| 7883–7885, 7894 | Suspended black television cases and brackets, back-to-back screens, nearby small equipment boxes |

## Implementation

- The existing station-local Station Base, two tracks, 105 × 10 m island, standard connection markers and shared departure clock hooks are retained.
- The incorrect grey/gold centre coffer panels and decorative stair clocks from V58 are no longer constructed. White ribs, rounded girder transitions, pale side ceilings and girder-edge diffusers follow the owner's modern photographs.
- Two rows of twenty fluted marble columns; shallow channels are physical geometry, not painted stripes. Exact station-wide counts and spacing remain scaled estimates.
- Wall and column materials use small samples of the real stone. Upper inlays use rectified owner photo/video regions under native lighting. They are arranged as a coherent band; their precise station-wide order is not a measured panorama. No passengers or faces are embedded in these crops.
- Bronze station lettering is physical layered TextMesh geometry with dark centres and a narrow bronze rim. Typeface approximation: DejaVu Sans Condensed, with its licence included.
- Five separate seats on each backless bench, side-hung bilingual signs, two distinct wall route panels, two distinct end exit boards, floor grilles/covers and visible equipment fittings.
- Main televisions play an original 21-second vector advertisement loop: coffee, city outings and reading. Each seven-second card has moving highlights/progress and a crossfade; no network requests or video decoding. It is fictional advertising made for the game.
- Four white-framed driver mirrors, independently copied local reflection controller. Only the nearest front-facing mirror within 32 m refreshes at 6 Hz, at 192 × 512 pixels. Small CCTV screens show a still cropped from the supplied train-platform photo.

Photo and video hashes, source regions and sampled times are recorded in `art/owner_photo_assets.json`. Original full photographs, passenger faces, original video audio and complete videos are not redistributed. Legacy V58 Wikimedia assets remain in source with their original credit file but are excluded from the V60 module export.

Validation is limited to native Godot 4.3 resource import and Web pack export. Texture mip levels are generated during the build for oblique marble, floor and signage views. No gameplay, browser, visual or performance test suite. Exact dimensions, hidden rooms, measured photometry and complete fixture counts cannot be established from these views.


## V60.1 — owner-requested continuous marble and solid column correction

Revisited all 31 photographs, especially 7869/7870 (plain marble courses), 7875 (column close-up), 7877/7882/7896/7897 (inlay, lettering band, lower marble and dark plinth). The architecture inlay remains above the moulded lettering band, exactly as the photographs show; the same pale marble continues BELOW that band to a low 0.55 m dark stone plinth. The previous plain lower region now has actual rectified owner marble courses instead of a small, heavily resampled procedural-looking texture. New quiet wall and tall column textures retain the original vein direction. Crop provenance: art/marble_refinement_v60_1.json; reproducible script: tools/moskovskaya_photo_v60/refine_marble_v60_1.py.

Column transparency was consistent with the helper's incorrect counter-clockwise front-face winding. Godot geometry is now clockwise; marble shaders are opaque, two-sided, and do not write ALPHA. Column facings are closed with end caps and an opaque solid core. The square profile now has broad flat marble faces, two rounded narrow flutes per face, bevelled corners, fine horizontal course seams and a small dark foot, rather than five grooves across each face. No transparent or glass material is used. Metric positions and profile dimensions remain estimates from photographs, not a survey.

No scene/game execution, browser, visual or performance tests. Only GitHub's import/export required for publication. Existing station layout, signs, advertisements, mirrors, train and other published station packs are retained.
