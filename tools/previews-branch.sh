#!/usr/bin/env bash
# Put a pull request's built preview on the `previews` branch, or take it off.
#
# The branch is a deploy artifact: pages.yml folds every folder on it in
# under /pr/. Nothing here is source; it is a deploy artifact that happens to
# live in git, rewritten as a single orphan commit each time so it never
# grows and a closed pull request leaves nothing behind.
#
#   tools/previews-branch.sh put <pr-number> <built-dir>
#   tools/previews-branch.sh remove <pr-number>
#
# Two pull requests can publish at the same moment (#81), and an orphan
# commit force-pushed over another one would drop the other's folder. So the
# push is under a lease on the commit that was cloned: if the branch moved
# meanwhile the push is refused, and the whole change is redone on a fresh
# clone. Last writer no longer wins; every writer lands.
set -euo pipefail

cmd="${1:?put|remove}"; n="${2:?pr-number}"; src="${3:-}"
[ "$cmd" = put ] && [ -z "$src" ] && { echo "put needs a built dir"; exit 2; }
: "${GH_TOKEN:?GH_TOKEN}"; : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY}"

repo="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

for attempt in 1 2 3 4 5; do
  work="$(mktemp -d)"
  expect=""
  if git clone --quiet --depth 1 --branch previews "$repo" "$work" 2>/dev/null; then
    expect="$(git -C "$work" rev-parse HEAD)"
  else
    git init --quiet "$work"
    git -C "$work" remote add origin "$repo"
  fi
  (
    cd "$work"
    # Both spellings: previews were briefly stored as pr-<n>/, which leaked
    # into the URL as /pr/pr-<n>/ (#72). Removing both migrates a stale one.
    rm -rf "pr-$n" "$n"
    [ "$cmd" = put ] && cp -a "$src" "$n"

    # An index, so the folder is browsable rather than a 404 at its root.
    {
      echo '<!doctype html><meta charset="utf-8"><title>CrumplZone pull request previews</title>'
      echo '<h1>Pull request previews</h1><ul>'
      for d in [0-9]*/; do d="${d%/}"; [ -d "$d" ] || continue
        echo "<li><a href=\"$d/\">pull request #$d</a> — <a href=\"$d/shots/\">screenshots</a></li>"
      done
      echo '</ul>'
    } > index.html

    git checkout --quiet --orphan rebuilt
    git add -A
    git -c user.name='github-actions[bot]' \
        -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
        commit --quiet --allow-empty -m "previews: $cmd $n"
  )
  # An empty expectation means "the branch must not exist yet".
  if git -C "$work" push --quiet --force-with-lease="previews:$expect" origin rebuilt:previews; then
    echo "previews branch now holds: $(cd "$work" && ls -d [0-9]*/ 2>/dev/null | tr -d / | tr '\n' ' ')"
    rm -rf "$work"
    exit 0
  fi
  echo "previews branch moved while this ran (attempt $attempt of 5); redoing on a fresh clone"
  rm -rf "$work"
  sleep $((attempt * 3))
done
echo "could not publish: the previews branch kept moving"
exit 1
