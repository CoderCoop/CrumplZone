#!/usr/bin/env bash
# Keeps the `previews` branch: a flat store of built pull request previews,
# one folder per open pull request, that pages.yml folds into the live site
# under /pr/. Nothing here is source; it is a deploy artifact that happens to
# be kept in git because that is the one place a workflow can put 40 MB and
# another workflow can fetch it back without a secret.
#
#   tools/previews-branch.sh put <pr-number> <built-dir>
#   tools/previews-branch.sh remove <pr-number>
#
# Needs GH_TOKEN and GITHUB_REPOSITORY in the environment, which Actions
# provides. The branch is rewritten as a single orphan commit every time, so
# its history never grows: what is on it is exactly what is served, and a
# closed pull request leaves nothing behind.
set -euo pipefail
cmd="${1:?put|remove}"; n="${2:?pr-number}"; src="${3:-}"
case "$cmd" in put) [ -d "$src" ] || { echo "no such dir: $src" >&2; exit 2; }; src="$(cd "$src" && pwd)";; remove) ;; *) echo "unknown: $cmd" >&2; exit 2;; esac

work="$(mktemp -d)"
repo="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
if ! git clone --quiet --depth 1 --branch previews "$repo" "$work" 2>/dev/null; then
  git init --quiet "$work"
  git -C "$work" remote add origin "$repo"
fi
cd "$work"
# Both spellings: previews were briefly stored as pr-<n>/, which leaked into
# the URL as /pr/pr-<n>/ (#72). Removing both migrates a stale one.
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
git push --quiet --force origin rebuilt:previews
echo "previews branch now holds: $(ls -d [0-9]*/ 2>/dev/null | tr -d / | tr '\n' ' ')"
