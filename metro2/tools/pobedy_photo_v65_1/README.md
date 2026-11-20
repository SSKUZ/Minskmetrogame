# Pobedy V65.1 — owner-reference correction

The first V65 release had incorrect sampling and approximate architecture: a tunnel edge was baked into column stone, paving seams were baked into floor samples, photographed information faces were clipped by inaccurate quads, and light trays were separate overbright triangular fixtures. This revision replaces those choices.

`build_art.py --photos /path/to/extracted/archive` samples clean stone regions on EXIF-corrected 800px-wide reference coordinates, removes broad illumination and uses periodic-plus-smooth border blending without mirror patterns. Normal maps supply restrained mineral grain. Names retain the photographed lettering; information faces are rebuilt as outlined bilingual SVGs with the photographed destinations and route cells. Cropped photographic information JPGs are removed from the runtime pack. Materials come from the owner archive; originals are not redistributed.

Architecture uses closed square curved flared capitals, eight bronze half-trays wrapping four corners, amber tubes with low emission, patterned bronze ornament, 14cm-deep real wall openings for names, non-overlapping floor cells on one surface height, contoured bench seats over a continuous base, separate stair treads and risers, and four shared curved escalator balustrades rather than six disconnected straight walls.

`publish.py` exports only the corrected station PCK and updates its existing manifest entry. It keeps the live boot PCK, viewer code and every other published pack. No scene, game, browser, visual or performance tests. Resource import, mipmaps and pack export are mandatory publication steps.
