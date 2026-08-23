# CrumplZone

A casual 2D physics game about demolition. You get a structure, a height line,
and a handful of moves. Bring it down so nothing stands above the line.

**▶ [Play it in your browser](https://codercoop.github.io/CrumplZone/)** — no
install, works on phones, and installable as a PWA.

## What's actually here

Early, but a real puzzle. One hand-built four-storey frame and three tools:

- **Jackhammer** — takes out the single block you point at.
- **Wrecking ball** — swings in from the side you clicked nearer and shoves a
  horizontal band sideways.
- **Explosive** — pushes everything nearby outwards, shatters what is closest.

Pick a tool with the on-screen buttons or the `1`/`2`/`3` keys, click or tap to
use it, `R` to reset. Each costs one move; you get five, and the level can be
cleared in three. A tool that finds nothing to act on costs nothing.

Not built yet: generated levels, scoring, undo, and sound.

[`CHARTER.md`](CHARTER.md) says what it is meant to become and why, including
the decisions already made and the questions still open.

## Why it works the way it does

Brute force is always available and always the expensive way to do it. The
efficient path is finding the load-bearing weak point and letting gravity
finish the job — so difficulty comes from seeing the structure clearly, not
from clicking precisely.

Levels will be procedurally generated and verified solvable before you play
them, with the move budget set from the verified solution plus slack. The
generator and the solver that verifies its output both exist; wiring them in
front of players needs the search to run in the background, because verifying
one level takes several seconds.

That whole approach rests on physics repeating reliably, which was measured
rather than assumed — and the measurement changed the design. A narrow spike
found rebuild-to-rebuild differences of 0.07 px; running real multi-move
solutions found the same effect flipping outcomes outright. So every candidate
solution is replayed and has to clear the line twice, with room to spare.
[`spikes/determinism/`](spikes/determinism/) has the original numbers and the
correction.

## Working on it

```sh
# Play it locally — needs Godot 4.6
godot --path game

# Check the level is still solvable within its budget, and not in one move
godot --headless --fixed-fps 60 --path game res://playtest.tscn

# Export the web build and check it runs on a header-less static host
godot --headless --path game --import
godot --headless --path game --export-release Web ../build/web/index.html
tools/verify-web-export.sh

# Generate levels and verify each one solvable — reports accept rate and cost
godot --headless --fixed-fps 60 --path game res://verify_levels.tscn

# Re-run the physics determinism measurement (downloads Godot on first use)
spikes/determinism/run.sh
```

[`ARCHITECTURE.md`](ARCHITECTURE.md) maps the pieces.
[`CHANGELOG.md`](CHANGELOG.md) says what changed for players.

Every change reaches `main` through a pull request with a green check, and
every push to `main` exports the web build, verifies it in a real browser, and
publishes it.
