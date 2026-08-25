#!/usr/bin/env bash
# Serves an exported build, publishes a change over the top of it, and checks
# the change reaches a browser that already had the old one.
#
#   tools/verify-update.sh [build-dir]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${1:-$ROOT/build/web}"
PORT="${PORT:-8131}"
SHOT="${SHOT:-$ROOT/build/verify/update.png}"

if [ ! -s "$BUILD/index.html" ] || [ ! -s "$BUILD/index.service.worker.js" ]; then
  echo "no web build with a service worker at $BUILD — export one first" >&2
  exit 2
fi

# The test rewrites the served files, so it works on a copy: a build directory
# that has been through this is no longer the one that gets deployed.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -r "$BUILD/." "$WORK/"

if [ -z "${CHROMIUM_PATH:-}" ] && [ -x /opt/pw-browsers/chromium ]; then
  export CHROMIUM_PATH=/opt/pw-browsers/chromium
fi

mkdir -p "$(dirname "$SHOT")"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$WORK" >/dev/null 2>&1 &
server=$!
trap 'kill $server 2>/dev/null || true; rm -rf "$WORK"' EXIT

for _ in $(seq 1 40); do
  curl -sf "http://127.0.0.1:$PORT/index.html" -o /dev/null && break
  sleep 0.25
done

node "$ROOT/tools/verify-update.js" "$WORK" "http://127.0.0.1:$PORT/index.html" "$SHOT"
