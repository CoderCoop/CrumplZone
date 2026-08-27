class_name Generator
extends RefCounted

## Builds levels from a seed. Emits the same dictionary shape as levels.gd, so
## everything downstream is unaware of where a level came from.
##
## Nothing here decides whether a level is any good — the solver does that, and
## gentest.gd checks the cheap things across many seeds. The generator's job is
## variety that is real rather than cosmetic: a different structural system,
## with different materials, a different silhouette and a different weak point,
## so the demolition that worked last time does not work here.
##
## Where the variety comes from, in order of how much it changes the puzzle:
##
##   1. The structural system — see architecture.gd. Six of them, each with a
##      real load path taken from how the thing is actually built.
##   2. Size: storeys, bays, spans, member sizes, all from the seed.
##   3. Materials: each system has an era, and the era decides what it is made
##      of. A 1900 frame is steel and brick; a 1970 one is concrete.
##   4. The setting behind it — see backdrop.gd. A works shed does not stand
##      in the same place as a curtain-wall office.

const CENTRE_X := 400.0
const FLOOR_Y := 540.0

## Which settings suit which building. A chimney belongs to the works, an
## office to downtown; picking at random would put a Victorian warehouse in a
## glass financial district, which reads as a mistake rather than as variety.
const SETTINGS := {
	Architecture.CURTAIN_WALL: ["downtown", "waterfront"],
	Architecture.MASONRY: ["works", "waterfront"],
	Architecture.PANEL: ["estate", "downtown"],
	Architecture.FLAT_SLAB: ["downtown", "estate"],
	Architecture.STACK: ["works"],
	Architecture.SHED: ["works", "estate"],
}

## An era changes what a system is built from without changing how it stands.
## The same frame in 1900 is riveted steel with brick infill; in 1970 it is
## concrete and glass. Applied as a substitution over the architecture's own
## choice, so the load path is untouched and only the character changes.
const ERAS := {
	"victorian": {Materials.STEEL: Materials.BRICK, Materials.CONCRETE: Materials.TIMBER},
	"interwar": {Materials.GLASS: Materials.BRICK},
	"postwar": {},
	"modern": {Materials.BRICK: Materials.CONCRETE, Materials.TIMBER: Materials.STEEL},
}

## Which eras a system could plausibly have been built in.
const ERA_FOR := {
	Architecture.CURTAIN_WALL: ["postwar", "modern"],
	Architecture.MASONRY: ["victorian", "interwar"],
	Architecture.PANEL: ["postwar"],
	Architecture.FLAT_SLAB: ["postwar", "modern"],
	Architecture.STACK: ["victorian", "interwar"],
	Architecture.SHED: ["interwar", "postwar"],
}


## A level from a seed. `force_kind` names a structural system instead of
## letting the seed pick one — for the picture harness, which wants one of
## each, and for a test that needs to reach a system held back from GENERATED.
## Play never passes it.
static func generate(level_seed: int, force_kind := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed

	var kind: String = Architecture.GENERATED[
		rng.randi() % Architecture.GENERATED.size()]
	if force_kind != "":
		kind = force_kind
	var built := Architecture.build(kind, rng)
	var blocks: Array = built["blocks"]

	var eras: Array = ERA_FOR.get(kind, ["postwar"])
	var era: String = eras[rng.randi() % eras.size()]
	blocks = _weather(blocks, era)

	var places: Array = SETTINGS.get(kind, ["downtown"])
	var setting: String = places[rng.randi() % places.size()]

	# Placed on the street: architecture builds around the origin, the level
	# lives at CENTRE_X with its feet on FLOOR_Y.
	for b in blocks:
		b["x"] = float(b["x"]) + CENTRE_X
		b["y"] = float(b["y"]) + FLOOR_Y

	var about: Array = Architecture.ABOUT.get(kind, ["Building", ""])
	# The measured pile if this seed has been baked, and nothing if it has
	# not — finish() falls back to the estimate, which is what an unbaked seed
	# deserves and no more.
	var measured := Pack.for_seed(level_seed)
	var spec := {
		"centre_x": CENTRE_X,
		"floor_y": FLOOR_Y,
		"blocks": blocks,
		"kind": kind,
		"era": era,
		"setting": setting,
		"title": about[0],
		"about": about[1],
		"seed": level_seed,
	}
	# Only set when there is a measurement, so finish() can tell "measured at
	# zero" from "never measured" by whether the key is there at all.
	if measured >= 0.0:
		spec["pile"] = measured
	return Levels.finish(spec)


## Substitutes materials for the era, leaving the structure alone.
static func _weather(blocks: Array, era: String) -> Array:
	var swap: Dictionary = ERAS.get(era, {})
	if swap.is_empty():
		return blocks
	for b in blocks:
		var made_of: String = b["material"]
		# Reinforced concrete is never substituted: it is the thing a level
		# has to be brought down around, and swapping it away would quietly
		# remove the only piece no tool goes through.
		if made_of == Materials.REINFORCED:
			continue
		if swap.has(made_of):
			b["material"] = swap[made_of]
	return blocks
