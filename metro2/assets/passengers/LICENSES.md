# Passenger asset provenance

Character bodies, skin, hair and clothing derive from the MakeHuman core CC0 dataset, via Ara 3D Gen.

- MakeHuman asset license: CC0 1.0, https://static.makehumancommunity.org/makehuman/faq/are_makehuman_files_free.html
- MakeHuman credits: Data Collection AB, Joel Palmius, Jonas Hauquier.
- Ara 3D Gen: https://github.com/olatunde85/3d-gen, source commit `dd716acd32df44f06b8968ab57c5c54428475b94`, MIT code license. Source is a build-time dependency, not loaded by the game.
- Walk and chair animations derive from the CMU Graphics Lab Motion Capture Database, http://mocap.cs.cmu.edu/ (NSF EIA-0196217). Commercial and noncommercial use is allowed; motion data must not be resold as a separate motion dataset.
- Idle and talk animation generation comes from Ara's MIT code.
- Far atlases are rendered directly from these same textured character models, without external runtime requests.

The local Three.js GLTFLoader, SkeletonUtils and BufferGeometryUtils addons are r161, MIT, covered by `js/vendor/THREE-LICENSE.txt`.
