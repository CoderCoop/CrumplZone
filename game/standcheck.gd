class_name StandCheck
extends RefCounted

## Does a building stand up on its own? One answer, one place.
##
## There were two. The bake built a level five times in isolation and decided
## what shipped; gentest built every shipped level once, in sequence, and
## gated CI on the result. Two exams, and they disagreed about whichever
## building sat nearest the edge — the bake would pass a level and CI would
## then reject it, and dropping the culprit only promoted the next borderline
## one. Masonry was benched for it and the failures moved to a house and a
## stack.
##
## The conditions differ because physics carries state between builds in a
## process, and neither harness can reproduce the other's history. So they no
## longer try: the check lives here, both call it, and the bake finishes by
## running it over the whole accepted pack in pack order, which is the shape
## gentest uses. What ships is what passed the check that gates it.

## How long a building is given to settle into its own contacts before
## anything is judged, and how long it is then watched.
const SETTLE_TICKS := 240
const WATCH_TICKS := 90

## How far the top may sink while bedding in, as a share of the building's
## height, never less than this many pixels. Every system settles into its
## contacts once under its own weight and the amount scales with how much is
## stacked up; a building that actually falls over loses tens of percent.
const SAG_FLOOR := 12.0
const SAG_SHARE := 0.06


## Every point of damage in a level, added up.
static func damage_total(level: Level) -> int:
	var total := 0
	for body in level.live_blocks():
		total += int(body.get_meta("damage", 0))
	return total


## The highest point of anything still standing, as a depth below the street.
static func top_of(level: Level, spec: Dictionary) -> float:
	var floor_y: float = float(spec["floor_y"])
	var peak := floor_y
	for body in level.live_blocks():
		var poly: PackedVector2Array = body.get_meta("poly")
		for point in poly:
			peak = minf(peak, body.global_position.y + point.rotated(body.rotation).y)
	return floor_y - peak


## Which pieces have taken damage, by role and material, for the report.
static func culprits(level: Level) -> Dictionary:
	var found := {}
	for body in level.live_blocks():
		if int(body.get_meta("damage", 0)) > 0:
			var what := "%s %s" % [body.get_meta("role", "?"),
				body.get_meta("material", "?")]
			found[what] = int(found.get(what, 0)) + 1
	return found


## Why this level is not fit to ship, or "" if it is.
##
## Damage is judged on what it took after settling, not since it was built.
## Counting from the build counts the bedding-in, where pieces made a hair
## apart resolve into contact — every building does that once and none does it
## twice. Measured on a whole pack, twenty of twenty-two levels take exactly
## nothing further and the rest take two to six points, so there is no
## marginal band to worry about: a level either settles or it is degrading.
static func verdict(level: Level, spec: Dictionary, top_at_build: float,
		settled_damage: int) -> String:
	var carried_on := damage_total(level) - settled_damage
	if carried_on > 0:
		return "keeps damaging itself after settling: %d more points, %s" % [
			carried_on, culprits(level)]
	var dropped := top_of(level, spec) - top_at_build
	var allowed: float = maxf(SAG_FLOOR, top_at_build * SAG_SHARE)
	if dropped > allowed:
		return "sags %.0f px untouched, over %.0f allowed for its height" % [
			dropped, allowed]
	return ""
