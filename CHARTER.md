# CrumplZone — Project Charter

**What this document is for:** it records what CrumplZone is, the design
decisions already made and why, and what is still open. It exists so that
implementation choices can be checked against an agreed intent rather than
re-argued. Read the Open Questions section last — it is the part most likely
to change.

Status: agreed in outline. No game code yet; one spike run, recorded under
`spikes/determinism/`.

---

## The game in one paragraph

CrumplZone is a casual 2D physics game about demolition. Each level presents a
structure standing on a plot. The player has a limited number of moves and a
set of demolition tools — jackhammer, wrecking ball, explosives — and must
bring the structure down so that nothing remains above a marked height line.
Brute force is possible but wasteful; the efficient path is to find the
load-bearing weak points and let gravity do the rest.

## Design pillars

These are the tie-breakers. When a decision is unclear, the option that serves
a pillar higher in this list wins.

1. **The collapse is the reward.** The moment a structure gives way is what the
   player is here for. Everything else — scoring, progression, UI — exists to
   set that moment up and get out of its way.
2. **Reward insight, forgive imprecision.** There is a smart solution and the
   player should feel clever for finding it, but a player who does not find it
   should still finish the level and simply score worse. Difficulty comes from
   seeing the weak point, not from executing a pixel-perfect click.
3. **Casual to pick up, quick to retry.** Sessions are short, a level is a few
   minutes, and restarting is instant and expected.
4. **Honest physics.** The simulation is not faked or scripted. A structure
   falls because it was unsupported, and the player can reason about it.

## Core loop

1. Survey the structure. The height line is drawn on screen; anything above it
   at the end is a failure.
2. Spend a move: choose a tool, place it, commit.
3. Watch the physics resolve. The structure settles.
4. Repeat until the plot is clear or moves run out.
5. Score on moves remaining; retry immediately if unhappy.

One move is one tool use. Play is turn-based: the simulation runs to rest
between moves, so the player always acts on a settled structure. This keeps the
game readable, makes the move budget meaningful, and gives the collapse room to
be watched rather than interrupted.

## Win condition

**Nothing above the height line when the structure comes to rest.**

Chosen because it reads instantly — the player sees the line and sees what is
still above it, with no number to interpret — and because it rewards toppling
over grinding. Pulverising a building block by block is always available and
always the expensive way to do it.

Weak points are not a separate rule. They matter because generated structures
are built so that cutting a support is dramatically cheaper in moves than
demolishing the mass above it. The height line is the rule; load-bearing
structure is how the level makes that rule interesting.

## Tools

Each tool is a distinct verb, not a damage number. Exact costs and parameters
are tuning work, not charter material.

| Tool | Verb | Good at | Bad at |
| --- | --- | --- | --- |
| **Jackhammer** | Remove one block precisely | Severing a specific joint or support; surgical work | Anything at scale, anything out of reach |
| **Wrecking ball** | Swing an impulse along an arc | Toppling tall structures sideways; broad lateral force | Precision; reaching interior structure |
| **Explosives** | Radial impulse and destruction | Taking out a cluster of supports at once | Control — it destroys whatever is nearby |

The intended texture is that the jackhammer is the cheap scalpel, explosives
are the expensive shortcut, and the wrecking ball converts height into
horizontal disaster. A fourth tool that cuts a joint directionally (a cutting
torch or shaped charge) is a likely addition once the first three are tuned,
but is not committed to here.

## Levels: generated, then verified

Levels are **procedurally generated**, and every generated level is **verified
solvable before it is played**. The generator searches for a solution and only
ships the structure if one exists; the move budget is then set to the length of
that solution plus slack.

This is what makes "reward insight, forgive imprecision" concrete: the slack is
the forgiveness, and the verified optimum is the thing worth finding. It also
removes the standard failure of procedural puzzles — handing the player a level
that cannot be beaten.

**Known risk: physics determinism.** A verified solution is only a guarantee if
the simulation that verified it behaves like the simulation the player runs.
Rigid-body physics is sensitive to timestep and to platform floating-point
differences. Two mitigations, both intended:

- Generate and verify **on the player's device**, so the verifying simulation
  is literally the same binary on the same hardware.
- Verify **with margin** — require the solution to succeed comfortably, not by
  a hair — so small divergences do not flip the outcome.

**This has now been measured** — see `spikes/determinism/`. Godot 4.6's 2D
physics is fully reproducible across processes, but rebuilding an identical
scene inside one process cycles between two outcomes rather than repeating
exactly. On the metric the height-line rule actually reads, the two outcomes
differ by 0.07 px, against blocks 20 px wide. Generate-and-verify survives, and
the margin to verify with now has a measured number behind it instead of a
guess. The spike also suggests a cheap hardening: simulate each candidate
solution at two consecutive sequence positions and require both to pass, which
covers the cycle rather than hoping the play-through lands on the same phase.

Cross-platform determinism remains untested, which is the main reason to keep
verification on the player's own device. If it later turns out worse than
expected, the fallback is unchanged: constrained templates, generating by
recombining hand-designed structural motifs with known weak points, where
solvability holds by construction.

## Technology

**Godot 4**, MIT licensed.

Chosen against three requirements: shippable as a PWA or a native mobile app,
open source, and offering as much game-development capability as possible.
Godot exports to Android, iOS and web from one codebase and brings a full
engine — editor, 2D physics, particles, audio, animation, UI — rather than a
set of libraries to assemble. Its scene and resource files are text, so the
project stays reviewable in diffs.

Alternatives considered: **Phaser 3 + Capacitor** (MIT, web-first, PWA nearly
free, trivial CI — but no editor and less built in) and **Defold** (excellent
mobile engine, but source-available under a modified license rather than OSI
open source, which fails the requirement).

Costs accepted with this choice, to be confirmed rather than assumed:

- iOS builds require a Mac with Xcode.
- Godot's threaded web export expects cross-origin isolation headers, which
  GitHub Pages cannot set. A single-threaded export or a service-worker shim is
  the likely answer, and needs verifying before the web build is promised.
- CI is heavier than a plain-JS project: headless Godot, and a test framework
  chosen for it.
- 2D physics engine choice (Godot's built-in 2D physics versus a Box2D
  GDExtension) is unresolved and matters for stacked-body stability.

## Non-goals

Named so they can be declined quickly rather than debated repeatedly:

- 3D. This is a 2D game.
- Multiplayer of any kind.
- A player-facing level editor, at least until generation is good.
- Realistic material science. Physics should be honest and readable, not
  accurate.
- Monetisation, ads, or accounts.

## Open questions

Nothing below blocks starting work, but each will need an answer.

- **Art direction.** Placeholder geometry is fine to start. Is the target
  cartoon, industrial-realistic, or flat-graphic?
- **Controls on touch.** Tool placement on a phone screen is the hardest
  interaction problem here, and it constrains how precise tools are allowed to
  be.
- **Scoring and progression.** Moves remaining is the obvious score. Is there a
  star rating, a run of levels, a difficulty ramp, or is it endless?
- **Session shape.** Endless generated levels, or authored-feeling chapters
  built from generated content?
- **Undo.** Does a move commit permanently, or can the player step back one?
  This interacts directly with how punishing the move budget feels.
- **Audio.** Central to pillar 1 — a collapse without sound is half a collapse
  — but no decision has been made.
