# Park Chelyuskintsev owner-photo reconstruction V61

Source: feature/metro2-park-owner-photo-v61, on the published Moscow/Vostok source.

- Rebuild artwork: python metro2/tools/park_photo_v61/build_art.py --photos /path/to/owner/uploads
- Existing native Station Base retained: two tracks, 105 × 10 m platform, rail gauge and connection datums.
- Art assets are committed; publication never needs the original private photographs or video.
- Isolated Godot 4.3 import and Web PCK export, mipmaps enabled. No gameplay, browser or performance tests.
- Publication snapshots live gh-pages and updates only packs.park_chelyuskintsev and corresponding metadata/resources. All other station and train packs remain unchanged.
- Same permanent viewer URL. No new viewer implementation.
