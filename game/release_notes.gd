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
		"version": "0.11.0",
		"date": "2026-08-26",
		"lines": [
			"Levels are checked by machine before they reach you: each one is "
			+ "flattened over and over to find out how low it can really go, and "
			+ "any level whose third star turns out to be unreachable is thrown "
			+ "away rather than shipped.",
			"The star lines are measured against the building itself now. Three "
			+ "stars is exactly as hard as it was.",
		],
	},
	{
		"version": "0.10.2",
		"date": "2026-08-26",
		"lines": [
			"The shed has walls now. It was a row of columns holding a roof "
			+ "up, which looked more like a viaduct than a building. Clad "
			+ "bays, one of them left open as the door.",
		],
	},
	{
		"version": "0.10.1",
		"date": "2026-08-26",
		"lines": [
			"A sixth kind of building — a brick warehouse. It was in the last "
			+ "version but held back, because it would not stand still.",
			"Every kind of building is drawn as what it is now: flared columns "
			+ "on a concrete frame, joints and windows on precast panels, "
			+ "ribbed cladding on a shed, properly coursed brick. What is "
			+ "holding a building up should be readable before you touch it.",
		],
	},
	{
		"version": "0.10.0",
		"date": "2026-08-26",
		"lines": [
			"Three lines on the level now, not one. The lowest wins it; the "
			+ "two above are two and three stars. Get under the first and you "
			+ "choose: bank it, or keep going with the power you have left.",
			"Every generated level is a different kind of building — a glazed "
			+ "frame, a panel block, a flat-slab frame, a chimney, a shed. Each "
			+ "stands up for a different reason, so each comes down differently.",
			"Buildings come from different periods, and the city behind them "
			+ "matches what you are demolishing.",
			"The charge is far more destructive where it lands, and costs far "
			+ "more. The bar buys about five of them.",
		],
	},
	{
		"version": "0.9.1",
		"date": "2026-08-26",
		"lines": [
			"If you installed this to your home screen, it now picks up new "
			+ "versions on its own. It used to download them and then wait "
			+ "for you to close the app completely before switching over.",
		],
	},
	{
		"version": "0.9.0",
		"date": "2026-08-26",
		"lines": [
			"Three levels — easy, medium and hard — picked from the buttons "
			+ "below.",
			"Stars are rated against par, the best known way to bring the "
			+ "level down. Three stars means finishing within 15% of it, so "
			+ "it means the same thing on every level.",
			"Rubble that has settled no longer grinds away what it is sitting "
			+ "on. How fast something arrives is what does the damage.",
			"Damage lines stay where they were drawn instead of crawling "
			+ "around a piece as it breaks.",
		],
	},
	{
		"version": "0.8.0",
		"date": "2026-08-25",
		"lines": [
			"Rubble that has settled no longer wears away whatever it is "
			+ "sitting on. Glass under weight still cracks — that part was "
			+ "meant to happen.",
			"Reset and help are proper buttons with icons, sized for a thumb.",
			"The game has its own icon on your home screen instead of the "
			+ "engine's, and its own loading screen.",
			"It works offline now, and picks up new versions on its own "
			+ "without interrupting a level.",
		],
	},
	{
		"version": "0.7.0",
		"date": "2026-08-25",
		"lines": [
			"The Install button works now — it never appeared before, on a "
			+ "build that was perfectly installable.",
			"Glass broken down to slivers drops to the ground and holds "
			+ "nothing up.",
			"The building has proper architecture: capped columns, floor "
			+ "fascias, mullioned glazing, a parapet and a plant room.",
			"Clearer tool icons.",
		],
	},
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
