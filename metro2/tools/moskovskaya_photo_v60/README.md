# Moskovskaya photo reconstruction V60

The existing `modules/stations/moskovskaya` module is rebuilt from the owner's photographs and two short videos. Other modules and viewer controls are unchanged.

Rebuild source artwork with Python, Pillow, NumPy, fontTools and DejaVu fonts:

```
ffmpeg -ss 2.6 -i PHOTOS/7880.mp4 -frames:v 1 FRAMES/mural-frame-7880.jpg
ffmpeg -ss 11.5 -i PHOTOS/7879.mp4 -frames:v 1 FRAMES/mural-frame-7879.jpg
python metro2/tools/moskovskaya_photo_v60/build_art.py --photos PHOTOS --frames FRAMES
```

`publish.py prepare OUTPUT GH_PAGES_SHA`, `build OUTPUT`, `finish OUTPUT` preserve the live manifests, export only the Moskovskaya pack with Godot 4.3, then replace only its manifest entry. Publication is serialised with all other permanent-viewer updates. Legacy unused V58 mural/clock artwork is excluded from this pack; licences remain in source.

The ad loop is original vector artwork, animated by native shader TIME, with no external playback service. Reference mapping and reconstruction limits are in the station's REFERENCES.md.
