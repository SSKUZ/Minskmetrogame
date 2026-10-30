#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
cd "$ROOT"
mkdir -p build/web
"$GODOT_BIN" --headless --path "$ROOT" --import
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" build/web/index.html
echo "Web export created: $ROOT/build/web/index.html"
echo "Serve via HTTP; do not open index.html as file://"
