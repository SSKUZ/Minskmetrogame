# Park Chelyuskintsev — owner-photo reconstruction V61, 20 November 2026

Primary reference: all 28 owner photographs 7802–7829 and video 7801.mp4 (3.0323 seconds, 1920×1080, 60 fps). All images were examined, with the complete video sampled every 0.5 seconds. This supersedes the provisional V58 station appearance. The module already existed; it was rebuilt locally rather than creating a second station ID.

| Element | Owner references | Implementation |
| --- | --- | --- |
| Spatial layout | 7802, 7809, 7811, 7815, 7827, 7801.mp4 | Open single vault, no columns; central information pylons, island benches, two end stairs |
| Vault and light coves | 7806, 7813–7815, 7818, 7826–7827 | White transverse ribs, grey-white plaster fields, rounded raised central strip, continuous cove diffusers |
| Cast-glass luminaires | 7806–7807, 7813–7814, 7826 | Reused shared native bowl geometry, eight concentric radial rows, real owner glass colour/relief image, bronze cage, 5×11 side glass inserts with clear upright ends |
| Floor | 7808–7810, 7812, 7827 | Coarse grey aggregate, stepped rose-stone medallions, dark border, aggregate square inset, slab joints, yellow tactile edge and door-position corner marks |
| Track walls and names | 7816–7820, 7825 | Dark granite tiled plinth and lowered coping at ribs; white upper fields; actual sculpted Belarusian/Russian bronze glyphs sampled from owner photos over thin physical plaques |
| Wall route diagrams | 7817, 7819, 7825 | Outlined bilingual vectors, station 120 highlighted, opposite travel progress, lines 2/3 interchanges |
| Four-sided information pylons | 7821–7824 | Brown ribbed speaker housing, two opposite track direction lists, two opposite exit lists, split stainless guard rails, voltage label |
| Exits | 7803–7805, 7822, 7824, 7828–7829 | Separate Kalinina/botanical garden and Tolbukhina/watch factory/children railway boards, Independence Avenue heading |
| Stairs and equipment | 7804–7805, 7828–7829 | Two flights with landing, granite treads, yellow nosings, marble side walls and corbels, curved white lintel, continuous stainless handrails, grille, cameras, emergency signs, upper turnstiles |
| Mirrors and clocks | 7804, 7828–7829 | White mirror frame on blue post at platform ends; four red clocks kept on shared independent track departure logic |
| Benches and screens | 7802, 7811, 7801.mp4 | Long central backless wooden bench seats on dark solid bases; back-to-back television panels on pylons |

Television content is an original 21-second vector advertising loop (coffee, city weekends, reading), with crossfades, moving glint and progress. The owner showed black screens; no exact advertising content is claimed. No external streams or video decoder are required.

Station Base remains unchanged: platform 105×10 m, track gauge, rail heads, connection markers, passenger anchors and station_id. Existing contact rails and Minsk-time / independent departure clocks remain connected. All architecture and reflection code is local to this station, without a dependency on Moscow or Vostok. The closest front-facing mirror within 32 m refreshes at six frames/second, at 192×512.

Photo crops, coordinates and original hashes are recorded in art/owner_photo_assets.json. Only non-person material and lettering fragments are published. No full original owner photographs or videos are included. DejaVu fonts are outlined in signs; their license is included.

Metric dimensions, rib/chandelier counts, bench/pylon placement and fixture counts are estimates from perspective images, not a survey. Repeated texture patches retain sampled lighting. No street environment or concealed underpass plan is invented. Ordinary staircases are visible at both ends; escalators are not shown or added.

Validation scope: mandatory Godot 4.3 import and native Web PCK export. No game execution, browser, visual or performance tests. Publication updates only this station pack and associated entries in the permanent viewer manifests, preserving the other modules.


## V61.1 — owner-reported black roof and photograph comparison

Revisited the complete 7802–7829 reference set, especially 7813/7815/7818/7826/7827. Corrected a construction error: helper triangle winding followed the cross-product normal (counter-clockwise) while Godot front faces are clockwise. ShaderMaterial plaster retained default backface culling, so the intended interior could disappear against the dark viewer background. Interior winding is now clockwise, and plaster explicitly draws both sides. This is a code diagnosis, without a browser reproduction.

The flat central box and fragmented quarter-cove are replaced by a closed continuous curved white crown, 4.56 m wide, with rounded shoulders and repeated shallow transverse rolls. Side fields are neutral light grey-white, with distinct white ribs. Modest material emission represents cove bounce in GLES without realtime GI; the same six existing lights are moved up and recoloured neutral white. Chandeliers join the crown instead of hanging below a gap. Bronze rods stay narrow; glass inserts terminate at the shoulder. Coping recesses now cut through the top stone course and marble stair corbels have full solid side/underside faces.

No local import/export rerun and no game, scene, browser, screenshot, visual or performance tests. GitHub performs only the import/export required to publish the changed module. No extra assets or research were added. Appearance remains subject to the owner's viewer review.

## Owner-requested interior refinement, 22 November 2026

Revisited all 28 original owner photographs 7802–7829 and the existing 7801 video. Continuous closed end-wall masonry follows the vault above both track throats and the staircase opening; concrete throat lining, marble pier returns, recessed bronze bars, bevelled cast-glass tiers, neutral cove lighting, local shadow lights, rounded wooden benches and visible landing equipment were revised. Floor artwork and Station Base datums are retained. Running rails, sleepers and fastenings follow the existing Uruchye implementation, copied locally to preserve module independence; existing contact rails and clocks remain separate.

The booth and turnstiles are reconstructed only to the level visible behind the staircase in 7803/7828/7829; concealed details and exact dimensions are not surveyed. Native meshes, individual instance transforms, material source shaders, original photo-derived textures, metric construction parameters and semantic groups remain available for the future exporter. See portable_module.json for limitations; no Roblox export or compatibility certification is claimed. No game, scene, browser or local export was run; ordinary import and packaging remain in the existing automatic GitHub workflow.
