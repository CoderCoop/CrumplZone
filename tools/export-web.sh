#!/usr/bin/env bash
# Exports the Web preset into a directory and makes it servable.
#
#   tools/export-web.sh <godot-binary> [out-dir]     (out-dir defaults to build/web)
#
# The same steps pages.yml has always run, pulled out so that a pull request
# preview is built the way the live site is built rather than by a second
# copy of the recipe that drifts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${1:?usage: export-web.sh <godot-binary> [out-dir]}"
OUT="${2:-$ROOT/build/web}"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"

# A fresh checkout has no .godot/ import cache. Exporting without one produces
# a build missing its resources, so import first.
"$GODOT" --headless --path "$ROOT/game" --import
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$OUT/index.html"
test -s "$OUT/index.html"
test -s "$OUT/index.wasm"

# What is in this build, in a file anything can read. deploy-drift.yml asks
# whether what players have is what main says, and needs this to ask it.
sed -n 's/^config\/version="\(.*\)"$/\1/p' "$ROOT/game/project.godot" > "$OUT/version.txt"
test -s "$OUT/version.txt"

# Godot regenerates the service worker on every export, so the patch that lets
# it replace itself is applied to the generated one rather than kept in git.
# Without it the worker only stands aside when a page asks it to — and a page
# old enough to matter does not know how to ask.
#
# verify-page-scripts is a second's worth of parsing before any browser
# starts. The hooks the game needs are injected through a quoted string in
# export_presets.cfg, where one unescaped double quote ends the string early
# and leaves a script tag that never closes: a build that exports, deploys,
# serves, and never starts. In a browser that is a canvas which never appears,
# ninety seconds later.
node "$ROOT/tools/patch-service-worker.js" "$OUT"
node "$ROOT/tools/verify-page-scripts.js" "$OUT"
echo "exported $(cat "$OUT/version.txt") to $OUT"
