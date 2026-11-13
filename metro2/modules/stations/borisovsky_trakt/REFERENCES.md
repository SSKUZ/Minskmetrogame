# Borisovsky trakt — TЗ 51

Base source: fix/v106-viewer-loading, 5ff8387ced4f51d8c07d74dfab9627fdc9a2dfe1.
Station-local `station_base.gd` adapts the existing StationBaseStatic builder without changing it. The optional Uruchye architecture reference is removed locally so this package is independent. Datum, track centres (0.992 / -11.732), rail gauge parameters, 1.1805 platform height, 105 x 10 m platform and route +Z basis are retained. These dimensions and ceiling height/bench counts are **estimates**, not surveyed dimensions. Travel toward Uruchye is -Z, toward Vostok +Z. Working west stair at +Z; closed curved east vestibule at -Z.

Primary sources: owner's 16 photographs 6715–6722, 6724, 6726–6732. All uploaded photographs are reference-only. No original or extracted photo pixels are distributed. Signs are redrawn from public station information; stone textures are procedural. The texture builder reads no uploaded images. Track 1 signs point to Uruchye; track 2 signs list Vostok through Malinovka, as photographed. Older photographed maps are reproduced as supplied rather than inventing unphotographed revisions. Clocks are static photo-reference readings.

Additional sources examined:
- https://www.ais.by/story/1305 — 2007 architecture article: warm beige/chocolate/white, stone and metal, blue horizontal signs.
- https://commons.wikimedia.org/wiki/File:Bortr_02.jpg — 2011 full platform view by Antares 610; visual reference only, not redistributed.
- https://commons.wikimedia.org/wiki/File:Minsk-Metro-Borisovski_Trakt-09.jpg — opening-day reference, Redline, public domain.
- https://t.me/s/minskoemetro?before=14696 — operator description of two-span hall with central supports and materials.
- https://ru.wikipedia.org/wiki/Борисовский_тракт_(станция_метро) — six-metre support rhythm and closed eastern vestibule, cross-reference with photos.
- Video search: https://rutube.ru/video/77848d7bf2579f1a2dd708ee7e791e35/ (route informator, not useful for geometric reconstruction); no unverified video geometry used.

No station/game execution, screenshots, browser viewing, performance tests or visual validation. Only mandatory editor import and native resource packaging are used. Passenger anchors are markers only; no passenger systems are included. Meshes and MultiMesh instances remain native Godot geometry for later export.

Limitations: unphotographed hidden rooms and distant vestibule details are omitted. Exact historical letter extrusion and all small service plaques cannot be recovered from the supplied views; wall lettering uses an approximate serif face and outlined shading. Curved ceilings and material proportions are modeled from photographs. Equipment/sign counts are inferred where the complete platform is not visible.
