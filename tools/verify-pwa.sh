#!/usr/bin/env bash
# Serves an exported web build and checks a real browser would offer to install
# it — and that the game puts the offer on screen.
#
#   tools/verify-pwa.sh [build-dir]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${1:-$ROOT/build/web}"
PORT="${PORT:-8129}"
SHOT="${SHOT:-$ROOT/build/verify/pwa.png}"

if [ ! -s "$BUILD/index.html" ] || [ ! -s "$BUILD/index.manifest.json" ]; then
  echo "no web build with a manifest at $BUILD — export one first" >&2
  exit 2
fi

if [ -z "${CHROMIUM_PATH:-}" ] && [ -x /opt/pw-browsers/chromium ]; then
  export CHROMIUM_PATH=/opt/pw-browsers/chromium
fi

mkdir -p "$(dirname "$SHOT")"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$BUILD" >/dev/null 2>&1 &
server=$!
trap 'kill $server 2>/dev/null || true' EXIT

for _ in $(seq 1 40); do
  curl -sf "http://127.0.0.1:$PORT/index.html" -o /dev/null && break
  sleep 0.25
done

node "$ROOT/tools/verify-pwa.js" "http://127.0.0.1:$PORT/index.html" "$SHOT"
