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
	4100: {"pile": 119, "system": "curtain_wall"},
	4101: {"pile": 89, "system": "curtain_wall"},
	4102: {"pile": 92, "system": "curtain_wall"},
	4103: {"pile": 101, "system": "flat_slab"},
	4104: {"pile": 59, "system": "flat_slab"},
	4105: {"pile": 109, "system": "flat_slab"},
	4106: {"pile": 44, "system": "stack"},
	4107: {"pile": 72, "system": "stack"},
	4109: {"pile": 55, "system": "shed"},
	4110: {"pile": 39, "system": "shed"},
	4111: {"pile": 46, "system": "shed"},
	4112: {"pile": 123, "system": "house"},
	4113: {"pile": 26, "system": "house"},
	4115: {"pile": 44, "system": "retail"},
	4116: {"pile": 53, "system": "retail"},
	4117: {"pile": 56, "system": "retail"},
	4119: {"pile": 62, "system": "overpass"},
	4120: {"pile": 47, "system": "overpass"},
}
## difficulty -> the same, for the three authored levels.
const AUTHORED := {
	"easy": {"pile": 76},
	"medium": {"pile": 68},
	"hard": {"pile": 87},
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

