# Восток / Усход — owner-photo reconstruction V59

Reference set: 63 uploaded files (including duplicate photographs), filenames 7957–8015, provided by the project owner on 19 November 2026. These replace the provisional Internet-only architecture assumptions of V57/V58. The station retains the existing Station Base datum, 105 × 10 m island, two tracks and connection markers.

| Photo group | Observed elements used in the reconstruction |
| --- | --- |
| 7959, 7963–7965, 7970–7975, 7999 | High smooth pale single vault; frequent local curved ribs with broad rounded returns; three luminous rounded diffusers per bay; no columns and no cross-hall ribs |
| 8006, 8012 | Bronze raised ВОСТОК / УСХОД letters on pale stone cornice panels; distinct slanted line panels on opposite track walls; station 122 in yellow; interchanges 115/314 and 116/216 |
| 7957, 7960, 8001–8004 | Speckled grey stone paving, stepped red granite motifs, cream rectangular centres, narrow red/cream transverse inlays, red perimeter and yellow tactile stud strip |
| 7966–7969 | Four-sided bronze equipment pylons: purple bilingual route panels, green exit headers and cream destination panels, red tubular guard around ribbed equipment housing, side CCTV, upper screen, stainless waist rails |
| 7997 | Five separate light timber seat modules, no backrest, dark metal divisions/supports; longitudinal alignment beside the pylon |
| 7958, 7961–7962, 7976–7977, 8009–8010, 8013 | Broad two-flight stone stairs with landing, yellow nosings, pale stone parapets and brown handrail caps; raised end galleries, turnstiles/cabin; tall rounded white driver mirrors on blue posts beside tunnel mouths; red time/interval displays |
| 8011 | Exit board: Jasmine and Filimonov streets, National Library, Vostok neighbourhood |
| 8014–8015 | Opposite exit board: Kalinovskogo street, All Saints church, First National Trading House, House of Mercy |
| 7980–7988 | Pylon video screens and separate black suspended monitor, ceiling cable supports |

The exact text on photographed pylons includes both Belarusian and Russian: National Library; Filimonov street; Kalinovskogo street; K. Turovskogo street; All Saints church; House of Mercy; Vostok neighbourhood (Independence Avenue 123–151 / 153–157). Opposite exit faces reverse left/right arrows. Pylon track 1 runs toward Uruchye; track 2 toward Malinovka. The two walls have distinct route panel artwork, rather than a duplicated generic metro map.

Asset provenance and source pixel regions are recorded in `art/photo_assets.json`. Only small stone samples and the isolated screen image are included; faces, passengers and the complete photographs are not embedded in the module. Signs are reconstructed as font-outlined SVG. `station_letters.ttf` is DejaVu Sans Condensed; the accompanying font licence is included. Existing unused V57 signs are retained for compatibility.

## Geometry and operation

- New physical raised TextMesh station names; local curved wall panels, cornice and cable clips.
- Fifty repeated light bays per wall, each with three rounded diffusers; smooth crown with fine joints.
- Three four-sided equipment pylons; longitudinal five-seat benches; side cameras, cabinet ribs, guard tubes, waist rails and screens.
- Two 40-step stair assemblies with an intermediate landing, raised galleries and entrance fittings. These counts and metric spacing are modelling estimates from photos, not a survey.
- Four driver mirrors: native Web-compatible viewport reflections; only the nearest front-facing mirror within 32 m updates, at 6 Hz and 192 × 512 pixels; mirror surfaces are excluded from reflection cameras to prevent recursion.
- Existing four portal clocks and independent departure hooks are retained, with red digits and adjusted mounting height. No change to shared infrastructure or other stations.
- Still screen image taken from the owner photograph; animated advertisement playback and exact hidden vestibule rooms are not reconstructed.

The reference photos support appearance and relative placement. Exact dimensions, station-wide fixture totals, opposite-end assignment to world coordinates, concealed rooms and original letterface cannot be certified from these views. The result is a photo-informed reconstruction, not a measured digital twin.

Validation: native Godot 4.3 resource import and Web pack export completed locally. No game, browser or performance test suite.
