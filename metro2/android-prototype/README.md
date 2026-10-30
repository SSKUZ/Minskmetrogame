# Metro 2.0 — P1 native Android prototype

**State: source-only, unbuilt and untested.** Godot 4.x GL Compatibility, one cube, camera touch controls and performance overlay. No Three.js or WebView. The source is intentionally independent of the old browser game.

## Build gate
1. Install a compatible Godot 4.x editor, Android SDK/build tools, JDK 17 and Android export templates.
2. Open this folder as a Godot project. Run locally and fix any parser/runtime errors.
3. Configure Android export preset (package identifier, signing, SDK), generate APK.
4. Install on physical Honor Pad X9, record exact model/Android version/GPU, native resolution, APK hash, build commit.
5. Test for 15 minutes (idle/orbit/pinch), log FPS distribution, p95 frame time, memory, crashes, thermal throttling.
6. Only after evidence and explicit user approval move to the next phase. Do not claim pass based on browser/SwiftShader.

## Acceptance target (provisional)
Sustained >=30 FPS with no crash or severe input lag in this deliberately empty scene. Report median and p5 FPS and p95 frame time; one instant FPS value is not a pass. CPU/GPU memory and thermals must be recorded by device tools where possible.

## Current environment
At project creation, the available execution container had Java but **no Godot editor, Gradle, or Android SDK found**. APK generation and physical-device testing have NOT occurred. Source must first be validated with Godot and exported.

## Deferred from P0
Batch glTF validation of 24 passengers, independent asset license verification and reproducible export of v106/cab remain mandatory **before importing those assets**, not prerequisites for this empty-scene P1 probe.

## Automated build added (31 October 2026)
GitHub Actions workflow: `.github/workflows/metro2-p1-build.yml` on branch `feature/metro2-godot-p1`.
Uses Godot CI image `barichello/godot-ci:4.4.1`; imports project, exports ARM64 Android debug APK and Web build, and uploads artifacts. Android preset `export_presets.cfg` is for a **debug-only probe**, not a production-signed release.

**Evidence status:** workflow source committed, but CI run completion, APK existence, successful launch and physical-device test are **NOT confirmed**. The GitHub connector's available commit-runs endpoint filters to PR runs and cannot establish push-run success. If CI fails, inspect the run logs and fix the branch before calling it built.

**How to retrieve APK once the run succeeds:** open GitHub repository → Actions → “Metro 2 P1 native Android and Web builds” → latest run on `feature/metro2-godot-p1` → artifact `metro2-p1-android-debug`. Verify SHA256SUMS, install only on a test device, and record launch evidence. Do not treat the presence of an artifact as proof of a successful launch.

## Build/test update — 31 October 2026

A native ARM64 APK has now been built and structurally/signature verified locally using Godot 4.3. Android installation and launch remain unverified. See `BUILD_TEST_2026-10-31.md`; the earlier automated-build evidence status above is historical.
