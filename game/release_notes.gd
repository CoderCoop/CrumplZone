class_name ReleaseNotes
extends RefCounted

## What's new, in the player's words.
##
## CHANGELOG.md is the full record and stays the source of truth for the
## version number — CI checks that the newest heading there matches
## `config/version` in project.godot. This is the short version a player will
## actually read on the intro screen, so it says what changed for them and
## leaves out anything invisible from outside the game.

const NOTES: Array = [
	{
		"version": "0.4.0",
		"date": "2026-08-25",
		"lines": [
			"The wrecking ball is an actual ball on an actual chain — it "
			+ "swings, and hits whatever is in the way.",
			"Its damage is the momentum it is carrying when it lands, so "
			+ "where in the arc you catch the building matters.",
			"Glass shatters into uneven slivers; concrete and steel break on "
			+ "sloped faces.",
			"A broken column no longer holds up what was above it.",
		],
	},
	{
		"version": "0.3.0",
		"date": "2026-08-25",
		"lines": [
			"Every piece has a durability from 1 to 100 — glass 1, concrete 24, "
			+ "steel 36, the reinforced core 100.",
			"One jackhammer blow is 12 of it, a charge is 60.",
			"Damaged pieces crack and darken, and the damage floats up from "
			+ "the impact, so you can see what a blow did.",
			"Everything breaks apart into pieces when its durability runs out. "
			+ "The reinforced core outlasts your whole budget — go around it.",
		],
	},
	{
		"version": "0.2.0",
		"date": "2026-08-24",
		"lines": [
			"The building is made of something: glass breaks first, concrete "
			+ "takes two hits, steel takes three.",
			"Damaged pieces darken, so you can see what you have weakened.",
			"The jackhammer shatters what you point at instead of halving it.",
			"Every tool now shows what it is doing.",
			"Built for a phone: the whole building fits in portrait, and the "
			+ "tools sit where a thumb reaches.",
		],
	},
	{
		"version": "0.1.0",
		"date": "2026-08-24",
		"lines": [
			"First playable. One building, three tools, five moves.",
			"Jackhammer breaks a block in two — nothing is ever deleted.",
			"Fixed: pieces above a cut no longer hang in mid-air.",
			"Runs in the browser and installs as an app.",
		],
	},
]


static func version() -> String:
	var v: String = ProjectSettings.get_setting("application/config/version", "")
	return v if v != "" else "dev"


static func latest() -> Dictionary:
	return NOTES[0] if not NOTES.is_empty() else {}
