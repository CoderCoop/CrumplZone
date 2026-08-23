# Spike: is Godot 4's 2D physics deterministic enough for verified generation?

**The decision this supports:** `CHARTER.md` commits to procedurally generating
levels and verifying each one solvable before it is played, on the player's own
device. That guarantee only holds if repeating an identical simulation gives an
identical result. If it doesn't, generate-and-verify has to be replaced by
constrained templates, and that is a large change to make late.

**Answer: generate-and-verify is viable.** Godot's 2D physics is fully
reproducible, but rebuilding an identical scene inside one process does not
reproduce exactly — it cycles between a small number of outcomes. On the metric
the game actually scores, that difference is 0.07 px. Verify with margin and it
is a non-issue.

Run it yourself: `./run.sh` (downloads Godot 4.6 on first use, takes a second).

## Method

`spike.gd` builds a three-storey tower — pillars carrying slabs, with a small
seeded jitter so it isn't perfectly symmetric — drops an impulse on a
load-bearing pillar at tick 60 to simulate an explosive, and simulates 900
physics ticks at 60 Hz so the rubble settles. It does that six times in one
process from the same seed, records every body's final position and rotation,
and compares all fifteen pairs of runs.

Godot 4.6 stable, `--headless --fixed-fps 60`, single machine, x86_64 Linux.

## Results

**Across separate processes: bit-identical.** Running the whole thing twice and
comparing process A's run *i* against process B's run *i* gives an exact match
for every run. Nothing here is random.

**Across rebuilds inside one process: two outcomes, alternating.**

```
run 0 vs run 1: DIVERGED, max delta 4.379180908203125
run 0 vs run 2: bit-identical, max delta 0.0
run 0 vs run 3: DIVERGED, max delta 4.379180908203125
...
distinct outcomes  : 2 across 6 runs
  runs [0, 2, 4]
  runs [1, 3, 5]
highest-body spread: 0.071075 px
```

Period 2, exactly, held across six runs. Every one of the fifteen bodies
differs between the two classes. The divergence survives a ten-tick gap after
teardown, so it is not leftover bodies still in the physics space.

**The magnitudes are the important part**, because the two numbers are very
different:

| Measure | Spread between the two outcomes |
| --- | --- |
| Worst single body, any axis | 4.38 px |
| Every other body | under 0.19 px |
| Highest resting body | **0.071 px** |

The 4.38 px outlier is the demolished pillar's *horizontal* position — where a
launched block skids to a halt. The height-line win condition doesn't read
horizontal position. The number it does read moves by 0.07 px, on blocks 20 px
wide.

## What this means

The engine is deterministic; the *scene rebuild* is not idempotent. Same
sequence position, same result, every time, even in a different process — so
the outcome is a function of how many times the scene has been built and torn
down. That points at allocation or iteration order inside the solver rather
than at floating-point noise, though this spike does not prove the mechanism.

Consequences for the design:

- **Generate-and-verify survives.** A solver evaluating many candidate move
  sequences does many build/teardown cycles, so each candidate is simulated
  under a slightly different ordering than the eventual play-through. The
  resulting error on the scored metric is sub-pixel.
- **Verify with margin, as the charter already says** — and now there's a
  number to size it with rather than a guess. A level whose solution clears the
  height line by a whole block width is not going to be flipped by 0.07 px. A
  level that clears it by a hair could be, and should be rejected by the
  generator.
- **Consider parity-robust verification.** Since outcomes cycle, a cheap
  hardening is to simulate each candidate solution twice, at consecutive
  sequence positions, and require both to pass. That covers the cycle instead
  of hoping the play-through lands on the same phase as the verification.
- **Don't build anything on frame-exact replay across rebuilds.** Recording a
  solution and replaying it expecting an identical collapse will drift. Replay
  as *inputs re-simulated*, and treat the result as equivalent-but-not-equal.

## What this spike does not answer

Stated plainly, because the temptation is to over-read a green result:

- **Cross-platform determinism is untested.** One machine, one architecture.
  Verifying on the player's own device sidesteps this by construction, which is
  why the charter chose that, but nothing here confirms Android and desktop
  agree — and they may well not.
- **One structure, one impulse.** A larger or more chaotic collapse may spread
  further. The 0.07 px figure is evidence, not a bound.
- **The mechanism is a hypothesis.** Allocation ordering fits the period-2
  pattern, but this measures behaviour, not cause.
- **Godot's built-in 2D physics only.** A Box2D GDExtension, still an open
  question in the charter, may behave differently and would need re-measuring.
- **Longer settle times untested.** 900 ticks was enough for this tower to come
  to rest; a structure still creeping at the cutoff could diverge more.

## Turning this into a guard

`run.sh --max-top-spread 1.0` exits non-zero if the height-line metric moves
more than the given number of pixels, so this can become a CI check once the
real generator exists. It is deliberately not wired into CI yet: it would mean
downloading Godot on every run to guard a property no shipped code depends on.
