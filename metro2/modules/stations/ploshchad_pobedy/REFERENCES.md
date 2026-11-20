# Площадь Победы / Плошча Перамогі — V65.1

## V65.1 reconstruction corrections

The initial V65 sampling and geometry were inadequate. The column albedo included the tunnel beside the shaft; floor samples included photographed seams; several printed faces were clipped by incorrect perspective coordinates. V65.1 replaces those samples, uses periodic border blending without mirrored mineral patterns, and rebuilds the full information faces as crisp outlined vector artwork from the photographed wording and layout.

Columns now have continuous closed square curved flared capitals. Brown bronze lamp half-trays wrap four corners, with slender restrained amber tubes, bronze cup ornament and muted glass beads; the old luminous triangular sheets and diamond prisms are removed. Wall names sit inside actual 14cm-deep openings with stone reveals, a back and a shaded upper lip. Floor regions are partitioned into non-overlapping cells at one height. Benches have contoured five-module seats and a continuous dark base. Stairs have individual slab treads, darker risers, a landing and rail brackets. Three escalators share four curved wood-faced balustrades with rounded handrail returns, ribbed treads, comb plates, checker landings and tall status posts.

This revision uses `tools/pobedy_photo_v65_1/build_art.py` and a station-only publisher. The existing boot/menu and other station packs are retained. The observations below remain the source inventory; V65.1 geometry supersedes the earlier independent-branch/prism description.

Owner archive `площадь Победы.zip`: 40 photographs and two videos, all dated 20 November 2026. All photographs were inspected; both entire clips were decoded to reference sequences at 0.25-second intervals. Original photos/videos are not redistributed. Only isolated material samples, printed signs and monitor content are included; source hashes and exact crop/homography coordinates are in `art/owner_sources.json`.

| Reference | Reconstructed feature |
| --- | --- |
| 132932, 132934, 133000–133002 variants, 133352 | Two aligned rows of pale marble square shafts with black feet, fine slab joints, four curved white shoulder arms, and four brass/crystal tapered fan chandeliers per column. Physical brass rails, warm diffuser cores and individual faceted prisms; not flat chandelier pictures. |
| 132947–132957, 133029, 133049, 133140, both videos | Red speckled granite floor fields, pale grey framing, dark veined cross-bands beneath columns and longitudinal bands by the shafts, yellow raised-dot platform strips. Backless contoured timber seat modules with dark supports. |
| 133015, 133022–133024, 133127 | Pale marble rectangular wall courses, low red-brown granite plinth, horizontal metal conduit. Actual photographed gold/black Russian and Belarusian station-name plaques. Directional line diagrams with station 117 yellow, white separators and transfers 115/314 and 116/216. |
| 132949, 132952–132953, 133108 | Rectified photographed track-1 and track-2 hanging information faces, their bilingual wording and route strips. Metal cases and hangers fit within the clear column bays. |
| 132921–132926, 133001–133002 variants | Broad stair exit with intermediate landing, yellow nosings, marble side walls, handrails and actual photographed exit sign. |
| 133114 variants, 133122–133124 variants | Three escalators at the opposite end, ochre balustrades, black handrails, ribbed steps, comb-plate landings, indicators, safety cards and distinct photographed exit panel. |
| 133118 variants | White driver mirrors on blue posts, red-orange clock and interval panels, small blue CCTV screens, tunnel mouths and cable bundles. |
| 132956–132957, 133103, 133131 | Double-sided suspended televisions on paired metal rods; actual isolated yellow burger advertisement on screens. |

## Scale and construction

Station-local copy of Station Base: 105 × 10m island, platform datum 1.1805m, original track centres, gauge, contact rails and four connection markers. Native opaque materials for stone, white plaster and crystal geometry. Closed column shafts and solid white soffits; ceiling openings over both exit approaches. Repeated prisms, rails, stone slabs and tactile dots are batched as MultiMeshes. All station artwork and controllers are local to this module.

The archive is not a measured survey. Eighteen opposing column pairs at 4.8m spacing and dimensions of arms, lamps, stairs and floor fields are estimated to fit the established Station Base footprint. Prisms approximate visible crystal construction with opaque faceted geometry and restrained emission. Hidden upper vestibules are omitted. Escalators are architectural geometry; the television card is static. Mirror updating follows the existing nearest-visible 6Hz controller.

`tools/pobedy_photo_v65/build_art.py` reproduces photo samples and outlined route artwork. Source photos must be EXIF-corrected before coordinates are applied. No unrelated station artwork is used. DejaVu font and licence accompany the route generator and existing safety pictograms.

Publication only performs mandatory Godot resource import, mipmap generation and native Web pack export, then extends the current permanent viewer catalog and boot pack. Existing station and train packs are preserved. No game, scene, visual, browser, or performance tests are run.
