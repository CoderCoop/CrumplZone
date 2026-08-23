#!/usr/bin/env bash
# Serves an exported web build on a plain static server — no cross-origin
# isolation headers, same as GitHub Pages — and checks in a real browser that
# it loads, renders and responds to input.
#
#   tools/verify-web-export.sh [build-dir]
#
# Needs node with playwright available. Set CHROMIUM_PATH to point at a browser
# binary; the preinstalled one is used automatically when present.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${1:-$ROOT/build/web}"
PORT="${PORT:-8123}"
SHOTS="${SHOTS:-$ROOT/build/verify}"

if [ ! -s "$BUILD/index.html" ] || [ ! -s "$BUILD/index.wasm" ]; then
  echo "no web build at $BUILD — export one first:" >&2
  echo "  godot --headless --path game --import" >&2
  echo "  godot --headless --path game --export-release Web ../build/web/index.html" >&2
  exit 2
fi

if [ -z "${CHROMIUM_PATH:-}" ] && [ -x /opt/pw-browsers/chromium ]; then
  export CHROMIUM_PATH=/opt/pw-browsers/chromium
fi

mkdir -p "$SHOTS"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$BUILD" >/dev/null 2>&1 &
server=$!
trap 'kill $server 2>/dev/null || true' EXIT

for _ in $(seq 1 40); do
  curl -sf "http://127.0.0.1:$PORT/index.html" -o /dev/null && break
  sleep 0.25
done

node "$ROOT/tools/verify-web-export.js" \
  "http://127.0.0.1:$PORT/index.html" "$SHOTS/canvas"
