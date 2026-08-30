class_name Pack
extends RefCounted

## Measured rubble heights, baked in CI.
##
## GENERATED FILE — regenerate with bakelevels.tscn, do not hand-edit.
##
## How low a building can physically go decides whether it is fit to ship, and
## it used to be modelled: a per-system guess at how far debris spreads, times
## a safety factor. The model was wrong in a way that could not be fixed by
## tuning it. Its safety factor had to be pessimistic so a level's winning line
## never landed inside its own rubble, and the same number scaled that line — so every pixel of safety made the level more nearly won before it was
## touched. Measured on five panel seeds, the estimate had only 1.08x to 1.30x
## of room against the worst run, where curtain walls had 1.65x and sheds 3.42x;
## and correcting the panel constant put one level's winning line above its own
## roof.
##
## These are measurements instead. Each level is flattened several times and
## the worst result recorded, because the same level does not leave the same
## pile twice — measured, 1.21x to 1.46x between the best and worst run of one
## seed. The worst is what the lines have to clear.
##
## A measured pile needs no safety factor, so nothing inflates the winning
## line, and there is no per-system constant left to be wrong.

## seed -> {"pile": the worst rubble it left, "system": which kind of building
## it is}. Measured, not modelled.
##
## The system is recorded rather than re-drawn from the seed. The bake asks
## for each system by name so that every one of them is covered, so the seed
## alone no longer decides what gets built — and rebuilding from the seed
## alone would give the game a different building than the one measured.
const MEASURED := {
	4100: {"pile": 104, "system": "curtain_wall"},
	4101: {"pile": 86, "system": "curtain_wall"},
	4102: {"pile": 76, "system": "curtain_wall"},
	4103: {"pile": 78, "system": "masonry"},
	4106: {"pile": 81, "system": "flat_slab"},
	4107: {"pile": 91, "system": "flat_slab"},
	4108: {"pile": 98, "system": "flat_slab"},
	4109: {"pile": 17, "system": "stack"},
	4110: {"pile": 14, "system": "stack"},
	4111: {"pile": 21, "system": "stack"},
	4112: {"pile": 59, "system": "shed"},
	4113: {"pile": 59, "system": "shed"},
	4114: {"pile": 41, "system": "shed"},
	4115: {"pile": 26, "system": "house"},
	4116: {"pile": 109, "system": "house"},
	4117: {"pile": 20, "system": "house"},
	4118: {"pile": 40, "system": "retail"},
	4119: {"pile": 38, "system": "retail"},
	4120: {"pile": 28, "system": "retail"},
	4121: {"pile": 61, "system": "overpass"},
	4122: {"pile": 80, "system": "overpass"},
	4123: {"pile": 32, "system": "overpass"},
}
## difficulty -> the same, for the three authored levels.
const AUTHORED := {
	"easy": {"pile": 76},
	"medium": {"pile": 70},
	"hard": {"pile": 70},
}

## The measured pile, or -1 for a level the bake has never covered.
##
## Absent has to be distinguishable from zero, and zero is a real result: a
## chimney can be left with nothing at all above the street, and seed 4103 was
## measured at exactly 0. Returning 0.0 for "no measurement" put that level
## silently back on the estimate — the one path this whole change exists to
## get levels off.
static func for_seed(level_seed: int) -> float:
	return float(MEASURED.get(level_seed, {}).get("pile", -1.0))


static func for_level(difficulty: String) -> float:
	return float(AUTHORED.get(difficulty, {}).get("pile", -1.0))


## Which kind of building a baked seed is, or "" if it is not in the pack.
static func system_for(level_seed: int) -> String:
	return String(MEASURED.get(level_seed, {}).get("system", ""))


## Every seed the pack covers, in order, so the game and the harnesses agree
## on what the generated levels are rather than each picking its own range.
static func seeds() -> Array:
	var all: Array = MEASURED.keys()
	all.sort()
	return all

