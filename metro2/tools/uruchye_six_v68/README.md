# Uruchye V68 — six owner corrections

Reference: original owner photographs 6695–6709, uploaded 11 November 2026. Photographs 6714–6720 show Borisovsky Trakt and are used only as comparative navigation/stair references. Original images are not republished.

| Request | Change |
| --- | --- |
| Arrival-side wall map | On the same negative-X platform side as the no-boarding boards, a separate outlined diagram runs left-to-right from 124 Uruchye (yellow) through 123–110 (grey), with Malinovka at the far right. The opposite departure-side map and hanging boards retain the existing blue route. |
| Upper exits | Both pairs of stairs now join upper floors, enclosed lit concourses, gate rows, wide gates and glazed security booths. The low blue ceilings, ribs and light fittings stop before the ascending flights. The end facades have upper openings instead of solid headers sealing the landing. |
| Space behind stairs | Solid stair construction, structural upper-floor blocks, complete side/back walls and ceiling returns enclose the back and underside. |
| Track detail | A station-only component hides the simple Base rails, beds and sleepers and builds separate rail foot/web/head pieces, darker raised sleepers, plates, clips, bolts, ballast and covered contact rails with ceramic insulators. The rail top remains y=0 and the gauge 1.615 m. Clock nodes are preserved when replacing plain contact-rail pieces. |
| Service door | Detached poles in front of both central service doors are removed. The round column nearest the north service-door approach is omitted, including its base and capital. The photographed lift remains. |
| Station names | Flat name pictures are replaced with native extruded metal TextMeshes, depth and side faces, backed by a raised blue water emblem. One track wall has УРУЧЬЕ and the other УРУЧЧА. |

The supplied archive does not document a measured upper vestibule layout. The upper gate/security spaces are inferred visual extensions requested by the owner, not a claim to reproduce a surveyed concourse. Gate/security operation and passenger behaviour are outside this visual module. The lettering uses a bundled Cyrillic font; its stylised outlines approximate the real custom lettering.

Publication unpacks the current live Uruchye PCK to retain all existing scene/texture dependencies, imports new support resources with Godot 4.3, replaces only the architecture/track component and new art resources, and publishes a new hashed Uruchye PCK. Other station packs and the viewer boot are retained. Mandatory import/packaging only: no game, scene, visual, browser or performance tests.

Rebuild outlined art with `python3 metro2/tools/uruchye_six_v68/build_art.py` (fontTools). The workflow `metro2-uruchye-six-v68.yml` performs the publication.

V68.1 loading repair: the viewer casts every warmup resource to `Texture2D`. The bundled `station_letters.ttf` must stay in the PCK for the physical name meshes, but must not appear in the texture warmup list. Publication now includes only image resource suffixes in warmup; an existing live manifest can be repaired without rebuilding or replacing the station PCK.

V68.2 final owner corrections (screenshots 8578, 8580, 8582, 8584): all four outer stair walls now follow the tread height as closed stepped marble cheeks. Full-height walls begin at the upper landings. Continuous metal guards with closely spaced vertical infill protect both sides of each flight and extend onto the landings; upper turnstiles and security booths remain. The existing north mirror is clear of the stair mouth, and a second live mirror faces back along the opposite track from the south end. Both mirror faces are excluded from reflection cameras. The platform equipment script is included explicitly in the patch inputs and workflow triggers. Import/pack/publication only; no runtime or visual tests.
