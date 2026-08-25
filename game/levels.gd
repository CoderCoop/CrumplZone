class_name Levels
extends RefCounted

## Where level specs come from. Hand-built for now; the generator emits the
## same dictionary shape, which is why this is a separate file from the thing
## that simulates it.

const CENTRE_X := 400.0
const FLOOR_Y := 540.0

## How far a demolished building spreads beyond its own footprint, how densely
## broken pieces pack, and how much clearance the line keeps above the pile.
##
## These three turn a level's material volume into a survey line, which has to
## be computed rather than chosen: nothing is ever deleted, so the rubble has
## to fit underneath the line, and a level whose line sits below its own pile
## is unsolvable for reasons no tactics can fix. The symptom is a beam search
## that plateaus at every depth, which reads exactly like a level that is
## merely hard — so a generator that picked a constant would produce
## impossible levels and no way to tell.
##
## Calibrated against a measurement, not a guess: pulverised completely, the
## tower below has 78,912 px² of material and settles into a pile 119 px deep
## across about 1150 px of street. These numbers reproduce that within a few
## pixels and then keep a fifth of it as clearance.
const SPREAD := 350.0        # how far debris travels past each edge
const PACKING := 0.62        # how much of that area broken pieces actually fill
const CLEARANCE := 1.2       # how much room the line keeps above the pile
const LINE_MIN := 90.0


## The line for a set of blocks: high enough that the rubble fits under it, low
## enough that anything still standing breaks it.
static func line_above_ground(blocks: Array) -> float:
	var area := 0.0
	var left := INF
	var right := -INF
	for b in blocks:
		area += float(b["w"]) * float(b["h"])
		left = minf(left, float(b["x"]) - float(b["w"]) * 0.5)
		right = maxf(right, float(b["x"]) + float(b["w"]) * 0.5)
	if area <= 0.0:
		return LINE_MIN
	var spread: float = maxf(right - left, 1.0) + SPREAD * 2.0
	return maxf(LINE_MIN, area / (spread * PACKING) * CLEARANCE)


const COLUMN := Vector2(22.0, 76.0)
const SLAB_H := 22.0


## A curtain-wall office block: steel columns carrying concrete floor slabs,
## with glass glazing the bays between them, and a reinforced concrete core at
## ground level that no budget of jackhammer blows will get through.
##
## The materials are the puzzle. Glass is free to remove and holds nothing up;
## the concrete floors are what stands above the line; the steel columns are
## what actually carries the building, and the most expensive thing to cut. A
## player who reads the structure can tell all of that before touching it.
##
## Checked by playtest.gd (solvable, not trivial), toolcheck.gd (every tool
## does something) and waketest.gd — not by eye.
static func tower(storeys: int = 3, columns: int = 5, spacing: float = 86.0) -> Dictionary:
	var blocks: Array = []
	var first_x := CENTRE_X - (columns - 1) * spacing * 0.5
	var slab_w := (columns - 1) * spacing + COLUMN.x * 2.0
	# Generous clearance around the glazing. At a tight fit the panes wedge
	# between the columns and brace the frame against shear: measured, the same
	# building went from solvable in three moves to unsolvable in seven purely
	# by glazing the bays. A pane should be something the building carries, not
	# something that holds it up.
	var bay := spacing - COLUMN.x - 22.0
	var y := FLOOR_Y

	# The ground-floor core is reinforced concrete. Eight jackhammer blows is
	# more than the whole budget, so it is not a piece you break — it is a
	# piece you bring the building down around. That is the shape of the
	# decision the materials exist to create.
	var core := int(columns / 2)

	for storey in storeys:
		for i in columns:
			var made_of: String = Materials.STEEL
			if storey == 0 and i == core:
				made_of = Materials.REINFORCED
			blocks.append({
				"x": first_x + i * spacing,
				"y": y - COLUMN.y * 0.5,
				"w": COLUMN.x, "h": COLUMN.y,
				"role": "column", "material": made_of,
			})
		# Glazing fills the bays. It carries nothing, so taking it out is
		# cosmetic — which is the point: it teaches that breaking things and
		# bringing a building down are different jobs.
		for i in columns - 1:
			blocks.append({
				"x": first_x + i * spacing + spacing * 0.5,
				"y": y - COLUMN.y * 0.5,
				"w": bay, "h": COLUMN.y - 20.0,
				"role": "glazing", "material": Materials.GLASS,
			})
		y -= COLUMN.y
		blocks.append({
			"x": CENTRE_X,
			"y": y - SLAB_H * 0.5,
			"w": slab_w, "h": SLAB_H,
			"role": "slab", "material": Materials.CONCRETE,
		})
		y -= SLAB_H

	return {
		"centre_x": CENTRE_X,
		"floor_y": FLOOR_Y,
		"height_line": FLOOR_Y - line_above_ground(blocks),
		"blocks": blocks,
		# `moves` is the solver's search depth: how many tool uses it may chain
		# looking for a solution. It needs seven, and a player is not a beam
		# search, so the depth allows eight.
		"moves": 8,
		# Set against the solution the solver actually finds, not against the
		# search depth, and re-measured whenever the physics changes what a
		# demolition costs: 210 before weight broke things, 90 when it first
		# did, 156 once pieces that leave the world stopped being simulated.
		# At 260 a solver-quality run — five uses costing 126 — finishes with
		# about half the bar, which is the two-star band. Three stars is left
		# for playing better than the search does, which is the point of
		# having a rating at all.
		"power": 260.0,
	}
