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
