# Changelog

All notable changes to CrumplZone, written for people using it rather than
generated from the commit log. Format follows
[Keep a Changelog](https://keepachangelog.com). There are no releases yet, so
sections are dated.

## [Unreleased]

Nothing has been released, so this section describes what exists rather than
each step it took to get here.

### Added

- **A game you can play in a browser**, at
  <https://codercoop.github.io/CrumplZone/>. No install, works on phones, and
  installable as a PWA. Published automatically whenever the game changes.
- **One level: a four-storey frame** that has to come down so nothing stands
  above the height line. The best single move leaves six blocks standing, and
  it can be cleared in three. You get five.
- **Three tools.** The jackhammer breaks the block you point at into two. The
  wrecking ball swings in from whichever side you clicked nearer and shoves a
  horizontal band sideways. The explosive pushes everything nearby outwards and
  shatters what is closest. Pick with the on-screen buttons or the `1`/`2`/`3`
  keys, `R` to reset. Each costs one move — they differ in what they do, not
  what they cost.
- **A misclick is free.** A tool that finds nothing to act on does not spend a
  move.

### Fixed

- **Removing a piece now actually brings things down.** Blocks that had settled
  were falling asleep, and cutting away what held them up did not wake them, so
  the stack above hung in mid-air indefinitely. This is the reported "I remove
  pieces and nothing happens".

### Changed

- **Nothing vanishes any more.** The jackhammer breaks a block into two pieces
  and the explosive shatters what is closest, instead of deleting them. Every
  piece stays in the world and still has to end up below the line.

### Notes

- Not built yet: generated levels, scoring, undo, and sound.
- The build runs on any plain static host with no special server
  configuration. That is a deliberate constraint rather than a happy accident:
  it is what keeps the game installable as a PWA from a static host.
- Difficulty is measured rather than eyeballed. A headless search runs the move
  space on every change and fails the build if the level stops being solvable
  within its budget, or becomes solvable in a single move.
- The download is around 37 MB, which is fine on a desktop and unkind on mobile
  data. Not addressed yet.
