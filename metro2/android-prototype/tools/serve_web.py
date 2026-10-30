#!/usr/bin/env python3
"""Local HTTP server for an exported Godot Web build."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os

directory = Path(__file__).resolve().parents[1] / "build" / "web"
if not (directory / "index.html").is_file():
    raise SystemExit("Missing build/web/index.html; export with tools/export_web.sh first")
os.chdir(directory)
print("Open http://127.0.0.1:8000/ (localhost only)")
ThreadingHTTPServer(("127.0.0.1", 8000), SimpleHTTPRequestHandler).serve_forever()
