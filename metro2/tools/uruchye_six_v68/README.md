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
