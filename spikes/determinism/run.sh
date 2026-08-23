#!/usr/bin/env bash
# Runs the determinism spike and prints a verdict.
#
#   ./run.sh                        # report only
#   ./run.sh --max-top-spread 1.0   # also fail if the height-line metric moves
#                                   # more than 1.0 px between rebuilds
#
# Set GODOT to use an existing binary; otherwise one is downloaded and cached.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.6-stable}"
CACHE="${GODOT_CACHE:-${TMPDIR:-/tmp}/godot-$GODOT_VERSION}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/.determinism.json"
THRESHOLD=""

while [ $# -gt 0 ]; do
  case "$1" in
    --max-top-spread) THRESHOLD="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "${GODOT:-}" ]; then
  GODOT="$CACHE/Godot_v${GODOT_VERSION}_linux.x86_64"
  if [ ! -x "$GODOT" ]; then
    echo "downloading Godot $GODOT_VERSION to $CACHE"
    mkdir -p "$CACHE"
    curl -sSL -o "$CACHE/godot.zip" \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    unzip -oq "$CACHE/godot.zip" -d "$CACHE"
    chmod +x "$GODOT"
  fi
fi

# --fixed-fps decouples the loop from wall-clock time, so the simulation
# advances by a fixed delta as fast as the CPU allows.
"$GODOT" --headless --fixed-fps 60 --path "$HERE" -- "$OUT"

[ -n "$THRESHOLD" ] || exit 0

python3 - "$OUT" "$THRESHOLD" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
limit = float(sys.argv[2])
actual = d["top_spread"]
print(f"\nthreshold check: highest-body spread")
print(f"  expected : <= {limit} px")
print(f"  actual   : {actual} px")
if actual > limit:
    print("  FAIL")
    sys.exit(1)
print("  PASS")
PY
