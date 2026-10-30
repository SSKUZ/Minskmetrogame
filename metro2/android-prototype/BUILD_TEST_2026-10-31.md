# P1 Android build and test — 31 October 2026

Scope: BUILD & TEST ONLY. Initial branch HEAD: 893e7d149a4e9672fc95ecbd29bd0f52ea658798.

## Minimal changes

- project.godot: explicitly enable rendering/textures/vram_compression/import_etc2_astc. Godot 4.3 Android export validation rejected the project without it, with an empty configuration-error message. No textures or game content were added.
- .github/workflows/metro2-p1-build.yml: use Godot CI 4.3 to match the locally verified exporter; copy installed templates to the actual HOME used by GitHub Actions; configure SDK/JDK paths and an ephemeral debug keystore; use MinskMetro2-P1-debug.apk as the output name.
- .gitignore in the prototype: exclude generated .godot and build output.

## Evidence

Godot 4.3.stable.official.77dcf97d8 and matching official templates; OpenJDK 17.0.20; Android platform 34 / Build Tools 34.0.0. Native, Compatibility, ARM64-only debug export completed locally. Package: org.minskmetro.metro2probe; min SDK 21; target SDK 34.

ZIP CRC check passed; libgodot_android.so is ELF AArch64 (machine 183); APK contains only arm64-v8a native libraries. apksigner verified v1/v2/v3 signatures. No WebView/Three.js dependency was introduced.

Project import passed. An external test harness instantiated the existing scene, checked the active camera, simulated drag/pinch/finger-release events, and verified HUD text updates. These checks do not prove Android touchscreen behavior or performance on Honor Pad X9. A dummy-renderer headless shutdown emitted mesh_get_surface_count("m" is null); do not confuse this desktop test limitation with an Android crash.

The previous CI run 41143591137 failed due to export templates under /root while HOME was /github/home, and missing configured JDK/debug key. The workflow changes address these observed environment failures.

## Acceptance status

APK BUILT. ANDROID INSTALLATION AND LAUNCH NOT VERIFIED. No physical device was connected (adb devices empty); no compatible Android emulator or /dev/kvm was available. Desktop scene checks are separate from APK launch acceptance. The final delivery report records the exact build commit, APK hash/size and CI result.

Exporter retained the template's default icon and logged that no custom project icon was specified. No new artwork was added for this probe.
