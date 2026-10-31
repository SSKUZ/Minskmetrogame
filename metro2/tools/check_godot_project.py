#!/usr/bin/env python3
"""Preflight the Godot 4 integration without claiming a Godot engine run."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_SCENE = "res://scenes/StationV106Integration.tscn"

def main():
    issues = []
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'^run/main_scene="([^"]+)"', project, re.M)
    if not match or match.group(1) != EXPECTED_SCENE:
        issues.append("project.godot main scene does not target StationV106Integration")
    paths = [
        ROOT / "scenes/StationV106Integration.tscn",
        ROOT / "scenes/StationBaseStatic.tscn",
        ROOT / "scripts/station_base_static.gd",
    ]
    for path in paths:
        if not path.is_file():
            issues.append(f"missing: {path.relative_to(ROOT)}")
    integration = paths[0]
    if integration.is_file():
        text = integration.read_text(encoding="utf-8")
        resource_paths = re.findall(r'\[ext_resource[^\]]*path="(res://[^"]+)"', text)
        for res in resource_paths:
            if not (ROOT / res.removeprefix("res://")).is_file():
                issues.append(f"missing scene dependency: {res}")
        for car in range(1, 5):
            if text.count(f"v106_car_{car:02}.glb") != 1:
                issues.append(f"expected one GLB reference for car {car}")
        if text.count('type="Camera3D"') != 1:
            issues.append("integration scene must have exactly one camera")
        if text.count('type="WorldEnvironment"') != 1:
            issues.append("integration scene must have exactly one environment")
        if "Vector3(0, 0.22, 9.603)" not in text:
            issues.append("source-to-canonical train placement missing")
    print("Godot static project preflight:", "PASS" if not issues else "FAIL")
    for issue in issues:
        print(" -", issue)
    print("NOTE: This does not parse GDScript or execute Godot.")
    return 1 if issues else 0

if __name__ == "__main__":
    sys.exit(main())
