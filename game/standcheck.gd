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

## Damage past which a level is degrading rather than disagreeing.
##
## The two harnesses cannot be made to agree, and that is measured rather than
## assumed: the bake now runs this exact check, over the whole accepted pack,
## in pack order, until a round drops nothing — and gentest still fails three
## levels the bake passed, and different ones from those it dropped. Physics
## carries state between builds in a process, so the two histories differ and
## no amount of shared code closes that.
##
## So the bake is the gate for standing — five rolls plus a converged
## validation pass — and gentest reports rather than fails, except past this.
## Measured across a pack: a healthy level accrues exactly nothing after
## settling, the history-dependent ones accrue one to nine points, and a
## building that is actually coming down loses far more than that. Twenty-five
## sits clear above the noise and far below a collapse, so a real regression
## in the physics still turns CI red.
const DEGRADING := 25

## How far the top may move while bedding in, as a share of the building's
## height, never less than this many pixels. Every system settles into its
## contacts once under its own weight and the amount scales with how much is
## stacked up; a building that actually falls over loses tens of percent.
##
## Both directions, and it took a measurement to notice that it had only ever
## been one. Bedding in moves the top either way — pieces built a hair apart
## drop into contact, pieces built a hair overlapping are pushed out of it and
## rise — so the bound is the same size on each side.
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
	# top_of is a height above the street, so a building that sinks makes this
	# smaller and one that lifts makes it larger. That sign is the whole of the
	# bug this replaces: the comparison read `moved > allowed`, which fires
	# only when a building gets taller, under a message that said it sagged.
	# The check had never once caught a building sinking.
	#
	# What it let through, measured: seed 4106 is a chimney whose cap ends the
	# settle on the street — 406 px down to 18 — and the verdict was that it
	# holds. It is in the pack. A player would open that level and watch it
	# fall over before touching it.
	var moved := top_of(level, spec) - top_at_build
	var allowed: float = maxf(SAG_FLOOR, top_at_build * SAG_SHARE)
	if moved < -allowed:
		return "sags %.0f px untouched, over %.0f allowed for its height" % [
			-moved, allowed]
	# Kept, because it is a real failure and not only an accident of the sign:
	# a cantilever roof whose back support gives way see-saws, and its far end
	# is higher than it was built. That is what this arm has been catching.
	if moved > allowed:
		return "lifts %.0f px untouched, over %.0f allowed for its height" % [
			moved, allowed]
	return ""
