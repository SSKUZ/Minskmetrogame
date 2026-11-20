# Октябрьская / Кастрычніцкая — V66

Authoritative source: `октябрьская.zip`, 63 owner photographs and two videos dated 20 November 2026. Both complete videos (6.798400s and 6.323167s) were decoded and their full 0.25-second reference sequences reviewed. Original photographs and videos are not redistributed. `art/owner_sources.json` records hashes and exact source coordinates on 800px-wide EXIF-corrected images.

| Source | Architectural decision |
| --- | --- |
| 132232–132244, 132258–132300, 132432–132445, 132523 | Two opposed flights climb to an upper landing in the central island. The bridge crosses a track into a high-level approach. Thin stair soffits and individual treads/risers, sloping marble parapets and handrails leave an open cross-platform route underneath. Marble bridge facing, transverse underside ribs and smoked glazed guards. |
| 132153, 132204, 132209, 132307, 132409, both videos | Two rows of concave fluted pale marble columns. Four-prong torch heads with curved amber glass baskets, dark metal ribs and low-emission warm cells. Pale geometric diamond/rectangular ceiling frames and a cooler upper light wash. |
| 132200–132201, 132223–132230, 132315–132336 | Pale marble wall courses, fine joints, low dark red/brown granite plinth, horizontal conduits, photographed isolated gold/black station letters and directional route panels. Current station 116 and interchange 216, with 115/314 shown on the route. |
| 132245 variants, 132253–132254, 132438–132442, both videos | Plain red/brown speckled granite floor; grey edge slabs and yellow tactile strips, no invented Pobedy transverse floor bands. Backless timber saddle seats over long dark bases. |
| 132144–132149, 132347–132404, 132707 | Escalators at both ends, stainless balustrades, black rounded handrail returns, ribs and comb plates, queue rails, small CCTV screens, red-orange clocks and white driver mirrors. Historical sculptural friezes reconstructed from actual isolated owner images on shallow relief meshes. The yellow maintenance enclosure visible at one end is represented. |
| 132203, 132623, 132707 | Complete outlined bilingual platform/exit signs, red track disks as photographed, current station 116 highlighted, transfer to Купалаўская / Купаловская line 2, Independence Avenue, October Square and the streets visible in the source signs. |

## Transfer geometry and clearances

The new module uses a station-local copy of Station Base: 105 × 10m island, datum 1.1805m, original track centres, gauge and four track connection markers. Two 21-tread flights rise 3.15m over 6.51m runs toward a 4.20m-long upper landing. The bridge extends over one track into a short 5.7m upper approach and a connection marker for a future Kupalovskaya module. No unseen second-line station is invented.

The stair structures are thin inclines and tread shells rather than filled blocks. Four small piers are outside the central crossing strip; the landing beams leave about 2.73m clearance above the platform. Deck, piers and stair slabs/treads have structural box colliders. Passenger markers identify both sides of the lower crossing, the landing and the upper connection. These are integration anchors, not a new passenger AI simulation.

The bridge has a real opening through the upper part of the track wall. Parapets are omitted at the two stair mouths. Its underside and the higher parts of the stairs remain open to views and movement between the two platform sides.

## Fidelity and publication limits

The archive is not a measured survey. Eighteen column pairs and dimensions/placement of structural elements are estimates scaled to Station Base. The visible frieze sections are assembled from different source views; their relief depth is inferred from tonal structure and does not represent a measured sculpture scan. Letter shapes are isolated from the real photographs; information sign text is outlined so it does not depend on runtime fonts. Hidden vestibules and the Kupalovskaya station itself are outside this module. The upper approach ends at a connection marker.

Opaque native stone/paint/metal materials, clean periodically blended samples, closed column profiles and separate non-overlapping paving zones avoid the earlier contaminated textures and intersecting surfaces. Transparent bridge guards are native StandardMaterial3D. Repeated details use MultiMeshes. Relief vertices all stand in front of their backing slabs.

Publication imports resources, generates mipmaps and exports a new native Godot 4.3 Web PCK. It adds the catalog/menu entry while preserving all existing published packs. No game, scene, browser, visual or performance tests are run.
