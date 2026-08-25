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
		"version": "0.6.0",
		"date": "2026-08-25",
		"lines": [
			"Weight breaks things: glazing under a floor cracks and fails, and "
			+ "so does anything hit hard enough.",
			"Levels end properly now, with one to three stars for how much of "
			+ "the bar you had left.",
			"The bar shows what a hold will cost before you let go.",
			"Rubble that comes to rest below the line settles into the street.",
			"Tool buttons are icons, the city has depth, and you can install "
			+ "the game as an app from the help screen.",
		],
	},
	{
		"version": "0.5.1",
		"date": "2026-08-25",
		"lines": [
			"Holding a tool over nothing now lifts it and tells you, instead "
			+ "of quietly doing nothing.",
		],
	},
	{
		"version": "0.5.0",
		"date": "2026-08-25",
		"lines": [
			"Hold to use a tool instead of tapping it. The jackhammer keeps "
			+ "chipping while you hold.",
			"The ball hauls further back the longer you hold, and swings when "
			+ "you let go — a longer haul hits harder.",
			"Moves are gone: there is a power bar now, and how you spend it is "
			+ "up to you.",
			"Holding shows you where it would land before you commit.",
		],
	},
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
