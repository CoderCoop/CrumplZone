class_name Levels
extends RefCounted

## Where level specs come from. Hand-built for now; the generator emits the
## same dictionary shape, which is why this is a separate file from the thing
## that simulates it.

const CENTRE_X := 400.0
const FLOOR_Y := 540.0

## Where the survey line sits, and this number is measured rather than chosen.
##
## Nothing is ever deleted, so a demolished building has to fit under the line
## as rubble. Pulverised completely — eleven charges, no budget — this one
## settles into a pile 119 px deep spread over 1150 px of street, so a line at
## the old 100 px was asking for something the material volume makes
## impossible: the solver could not find a solution at any depth, and the
## reason was arithmetic rather than tactics.
##
## 135 clears that floor with room for the solver's margin, and still means
## what the line is for: a standing ground-floor stump passes, and anything
## above it does not.
const LINE_ABOVE_GROUND := 135.0

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
		"height_line": FLOOR_Y - LINE_ABOVE_GROUND,
		"blocks": blocks,
		# The solver needs seven of these, and a player is not a beam search.
		# The charter's rule is budget = a solution that exists, plus slack.
		"moves": 8,
	}
