# Changelog

All notable changes to CrumplZone, written for people using it rather than
generated from the commit log. Format follows
[Keep a Changelog](https://keepachangelog.com). There are no releases yet, so
sections are dated.

## [Unreleased]

### Added

- **A playable thing in a browser.** One tower, a height line, and four
  explosive charges. Click or tap to place a charge, `R` to reset. It is a
  slice, not the game — there are no tools to choose between, no generated
  levels and no scoring — but the collapse is real physics and the win
  condition is the one the game will keep.
- Published automatically on every change to `main`, and playable now at
  <https://codercoop.github.io/CrumplZone/>.
- A README that says what the game is, how to play it, and how to work on it.

### Notes

- The build runs on any plain static host, with no special server
  configuration. That is a deliberate constraint rather than a happy accident:
  it is what keeps the game installable as a PWA from a static host.
- The one level is currently far too easy — a single well-placed charge clears
  it with three moves to spare.
