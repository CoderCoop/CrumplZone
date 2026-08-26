class_name Architecture
extends RefCounted

## Buildings, by the way they actually stand up.
##
## A demolition puzzle is only interesting if different buildings fail
## differently, and buildings fail differently because they carry their load
## differently. So these are structural systems taken from real construction
## rather than shapes: each one has a real load path, a real weak point, and
## therefore a demolition that works on it and does not work on the others.
##
##   curtain_wall   A steel frame carries everything; the glass hangs off it
##                  and holds nothing up. Cut the columns and it pancakes.
##   masonry        Load-bearing brick. No frame at all — the outside walls
##                  are the structure, so the piers at the base carry the
##                  whole building, and brick is brittle.
##   panel          Precast large-panel housing, the Plattenbau system.
##                  Panels stacked dry on each other; the joints are the
##                  structure's weakness, so a panel taken out low leaves the
##                  stack above it with nothing to bear on.
##   flat_slab      A car park: thin slabs on slender columns and nothing
##                  else. Real ones fail by punching shear — the slab tears
##                  around the column head — and lose a whole bay at once.
##   stack          A chimney. Slender, heavy, and felled rather than
##                  collapsed: cut a notch on one side and it goes over that
##                  way. The only shape here where direction is the puzzle.
##   shed           A long-span industrial shed. Light steel trusses on tall
##                  slender columns, a sawtooth roof of glazing. Very little
##                  material, spread very wide.
##
## Blocks are rectangles because that is what the level format is. An arch is
## voussoirs, a truss is chords and posts — which is how they are really built
## anyway, and it means the physics gets the joints for free.

const CURTAIN_WALL := "curtain_wall"
const MASONRY := "masonry"
const PANEL := "panel"
const FLAT_SLAB := "flat_slab"
const STACK := "stack"
const SHED := "shed"

## How deep a masonry opening's lintel is. It sits on top of the piers, so it
## adds to the storey height rather than fitting inside it.
const LINTEL_H := 20.0

const TYPES: Array[String] = [
	CURTAIN_WALL, MASONRY, PANEL, FLAT_SLAB, STACK, SHED,
]

## What each one is called on the level card, and the one-line reason it is
## different to knock down.
const ABOUT := {
	CURTAIN_WALL: ["Curtain wall", "a steel frame, glazed. The glass holds nothing up."],
	MASONRY: ["Brick warehouse", "load-bearing walls. No frame — the piers are the building."],
	PANEL: ["Panel block", "precast panels stacked dry. The joints are the weakness."],
	FLAT_SLAB: ["Car park", "flat slabs on slender columns, and nothing else."],
	STACK: ["Chimney", "too slender to crush. It has to be felled."],
	SHED: ["Works shed", "long-span trusses. Little material, spread wide."],
}


## Builds one, and reports what it is. Returns
## {"blocks": Array, "type": String, "footprint": float, "height": float}.
static func build(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var blocks: Array = []
	match kind:
		MASONRY:
			blocks = _masonry(rng)
		PANEL:
			blocks = _panel(rng)
		FLAT_SLAB:
			blocks = _flat_slab(rng)
		STACK:
			blocks = _stack(rng)
		SHED:
			blocks = _shed(rng)
		_:
			blocks = _curtain_wall(rng)
	return {"blocks": blocks, "type": kind}


# --- a steel frame with glass hung off it ----------------------------------

static func _curtain_wall(rng: RandomNumberGenerator) -> Array:
	var storeys := rng.randi_range(3, 5)
	var columns := rng.randi_range(4, 6)
	var spacing := rng.randf_range(78.0, 92.0)
	var column := Vector2(rng.randf_range(20.0, 26.0), rng.randf_range(70.0, 82.0))
	var slab_h := 22.0
	var blocks: Array = []
	var first_x := -float(columns - 1) * spacing * 0.5
	var slab_w := float(columns - 1) * spacing + column.x * 2.0
	var bay := spacing - column.x - 22.0
	var y := 0.0
	# One reinforced column at the ground floor on the taller ones: something
	# no tool goes through, so the building has to come down around it.
	var core := -1
	if storeys >= 4:
		core = int(columns / 2)

	for storey in storeys:
		for i in columns:
			blocks.append(_block(first_x + i * spacing, y - column.y * 0.5,
				column.x, column.y, "column",
				Materials.REINFORCED if (storey == 0 and i == core) else Materials.STEEL))
		for i in columns - 1:
			blocks.append(_block(first_x + i * spacing + spacing * 0.5,
				y - column.y * 0.5, bay, column.y - 20.0, "glazing", Materials.GLASS))
		y -= column.y
		blocks.append(_block(0.0, y - slab_h * 0.5, slab_w, slab_h,
			"roof" if storey == storeys - 1 else "slab", Materials.CONCRETE))
		y -= slab_h
	return blocks


# --- load-bearing brick, arched openings ------------------------------------

static func _masonry(rng: RandomNumberGenerator) -> Array:
	# Three storeys at most. Load-bearing brick past that needs walls thicker
	# out of all proportion to what it gains, which is the reason steel frames
	# replaced it — and measured here, a four-storey warehouse crushed its own
	# piers untouched at every wall thickness tried. The range was arbitrary;
	# the limit is not.
	var storeys := rng.randi_range(2, 3)
	var bays := rng.randi_range(3, 5)
	var pier := rng.randf_range(32.0, 42.0)
	# Walls thicken toward the base, as every load-bearing masonry building's
	# do — there is more above them down there. Measured before they did: the
	# tallest warehouse crushed 15 of its own piers standing untouched, because
	# a wall of constant thickness carrying four storeys of brick is not how
	# anyone ever built one.
	var batter := 0.28
	var opening := rng.randf_range(56.0, 74.0)
	var storey_h := rng.randf_range(78.0, 92.0)
	var floor_h := 16.0
	var blocks: Array = []
	var span := float(bays) * opening + float(bays + 1) * pier
	var first := -span * 0.5 + pier * 0.5
	var y := 0.0

	for storey in storeys:
		# The piers are the building. Everything above bears on them, and
		# there is nothing else holding the floors up.
		var thickness: float = pier * (1.0 + batter * float(storeys - 1 - storey))
		for i in bays + 1:
			blocks.append(_block(first + float(i) * (opening + pier),
				y - storey_h * 0.5, thickness, storey_h, "pier", Materials.BRICK))
		# A segmental arch over each opening, as voussoirs. Five blocks, the
		# middle one the keystone — the joints between them are real joints,
		# so the arch stands the way an arch stands.
		# One spandrel across the whole wall, not a lintel per opening.
		#
		# A brick wall is monolithic, and this was being assembled out of
		# discrete members — a frame wearing masonry. Every separate lintel is
		# two more contact joints, and with a dozen of them the wall bedded
		# down a fraction at each: 20-28 px of sag with individual pieces
		# cracking as it went. That was never one member failing, which is why
		# four rounds of fixing individual members did not move it.
		#
		# The course over the openings is one member now, so a storey has two
		# joints instead of a dozen and the wall above bears on continuous
		# brick. The arched heads are drawn on it rather than built from it.
		blocks.append(_block(0.0, y - storey_h - LINTEL_H * 0.5, span,
			LINTEL_H, "spandrel", Materials.BRICK))
		# Timber floor spanning between the walls, which is what a warehouse
		# of this age actually had.
		# The floor goes in the openings, not across the whole plan, and the
		# storey above stands on the lintels rather than on the timber.
		#
		# It was a full-width slab with the next storey's piers standing on it,
		# which put the entire building above onto the joists — measured, they
		# were the last thing in this system still breaking untouched. In a
		# warehouse the walls carry the building and the joists carry the
		# floor; getting that the wrong way round is the whole difference
		# between a load-bearing wall and a frame.
		y -= storey_h + LINTEL_H
		for i in bays:
			var mid := first + pier * 0.5 + opening * 0.5 + float(i) * (opening + pier)
			blocks.append(_block(mid, y - floor_h * 0.5, opening + pier * 0.4,
				floor_h, "joist", Materials.TIMBER))

	# A brick parapet, the detail that makes the top read as a warehouse.
	blocks.append(_block(0.0, y - 14.0, span, 28.0, "parapet", Materials.BRICK))
	return blocks


# --- precast panels stacked dry ---------------------------------------------

static func _panel(rng: RandomNumberGenerator) -> Array:
	# Five at most. Measured, six storeys of precast panel put more on the
	# bottom course than concrete carries standing still, and the block quietly
	# crushed its own ground floor before anyone touched it.
	# Four at most. Five put more on the bottom course than the stack carries
	# standing still even with a reinforced base — measured, one deck cracked
	# untouched on a five-storey seed.
	var storeys := rng.randi_range(3, 4)
	var wide := rng.randi_range(3, 4)
	var panel_w := rng.randf_range(84.0, 100.0)
	var panel_h := rng.randf_range(58.0, 70.0)
	var floor_h := 14.0
	var blocks: Array = []
	var span := float(wide) * panel_w
	var first := -span * 0.5 + panel_w * 0.5
	var y := 0.0

	for storey in storeys:
		for i in wide:
			# A gap of a pixel between panels, because there is one in the
			# real thing: they are separate units bearing on each other, not
			# a monolithic wall, and that is the whole character of the system.
			# The ground storey is the heavy one, as it is in the real system:
			# a thicker in-situ base carrying the stacked panels above.
			blocks.append(_block(first + float(i) * panel_w, y - panel_h * 0.5,
				panel_w - 2.0, panel_h, "panel",
				Materials.REINFORCED if storey == 0 else Materials.CONCRETE))
		y -= panel_h
		blocks.append(_block(0.0, y - floor_h * 0.5, span, floor_h, "deck",
			Materials.REINFORCED if storey == 0 else Materials.CONCRETE))
		y -= floor_h
	return blocks


# --- flat slabs on slender columns ------------------------------------------

static func _flat_slab(rng: RandomNumberGenerator) -> Array:
	var decks := rng.randi_range(3, 5)
	var columns := rng.randi_range(5, 7)
	var spacing := rng.randf_range(64.0, 78.0)
	var column_w := rng.randf_range(14.0, 18.0)
	var storey_h := rng.randf_range(52.0, 62.0)
	var slab_h := 20.0
	var blocks: Array = []
	var first := -float(columns - 1) * spacing * 0.5
	var span := float(columns - 1) * spacing + column_w * 3.0
	var y := 0.0

	for deck in decks:
		for i in columns:
			blocks.append(_block(first + float(i) * spacing, y - storey_h * 0.5,
				column_w, storey_h, "post", Materials.CONCRETE))
		y -= storey_h
		blocks.append(_block(0.0, y - slab_h * 0.5, span, slab_h, "deck",
			Materials.CONCRETE))
		y -= slab_h
	# No ramp. Two versions of one were tried and both were wrong: the first
	# hung in mid-air, and the second reached the ground but was a 26 px wide
	# full-height freestanding wall, which leaned and dropped about 20 px on
	# every seed. A car park reads perfectly well as slabs on columns, and a
	# thing that has to be braced to stand up is not worth the decoration.
	return blocks


# --- a chimney, to be felled ------------------------------------------------

static func _stack(rng: RandomNumberGenerator) -> Array:
	var courses := rng.randi_range(7, 10)
	var base_w := rng.randf_range(60.0, 74.0)
	var top_w := base_w * rng.randf_range(0.44, 0.58)
	var course_h := rng.randf_range(38.0, 48.0)
	var blocks: Array = []
	var y := 0.0

	# A plinth, wider than the shaft, as every real stack has.
	# A concrete plinth rather than brick. Measured, the bottom of a ten-course
	# brick shaft sits within a few percent of what brick carries standing
	# still, and cracked itself on some seeds before being touched.
	blocks.append(_block(0.0, -16.0, base_w * 1.5, 32.0, "plinth", Materials.CONCRETE))
	y = -32.0
	for course in courses:
		var t := float(course) / float(maxi(courses - 1, 1))
		var w: float = lerpf(base_w, top_w, t)
		# Built as two half-shafts per course rather than one block, so there
		# is a vertical joint down the middle. A stack does not crush — it
		# hinges and goes over — and it needs somewhere to hinge.
		var made_of: String = Materials.CONCRETE if course < 2 else Materials.BRICK
		for side in [-1.0, 1.0]:
			blocks.append(_block(side * w * 0.25, y - course_h * 0.5,
				w * 0.5 - 1.0, course_h, "shaft", made_of))
		y -= course_h
	blocks.append(_block(0.0, y - 9.0, top_w * 1.25, 18.0, "cap", Materials.CONCRETE))
	return blocks


# --- long-span shed ---------------------------------------------------------

static func _shed(rng: RandomNumberGenerator) -> Array:
	var bays := rng.randi_range(4, 6)
	var spacing := rng.randf_range(92.0, 118.0)
	var height := rng.randf_range(108.0, 140.0)
	var column_w := rng.randf_range(19.0, 24.0)
	var blocks: Array = []
	var first := -float(bays) * spacing * 0.5
	var span := float(bays) * spacing + column_w
	var y := 0.0

	# Stanchions on base plates. Measured before they had any: two shed seeds
	# in twelve fell over untouched — a row of slender columns carrying a wide
	# truss is an inverted pendulum, and a real one is bolted to a pad footing
	# for exactly that reason.
	for i in bays + 1:
		var x := first + float(i) * spacing
		blocks.append(_block(x, -5.0, column_w * 2.2, 10.0, "footing",
			Materials.CONCRETE))
		blocks.append(_block(x, -10.0 - (height - 10.0) * 0.5,
			column_w, height - 10.0, "stanchion", Materials.STEEL))
	y = -height
	# Truss: a bottom chord across the whole span, a top chord, and posts
	# between them. Light, deep, and it carries a long way on very little.
	blocks.append(_block(0.0, y - 6.0, span, 12.0, "chord", Materials.STEEL))
	blocks.append(_block(0.0, y - 40.0, span, 10.0, "chord", Materials.STEEL))
	for i in bays * 2 + 1:
		blocks.append(_block(first + float(i) * spacing * 0.5, y - 23.0, 7.0, 22.0,
			"web", Materials.STEEL))
	# Sawtooth roof: a glazed face and a solid face per bay, north-light,
	# which is what these were built with.
	for i in bays:
		var centre := first + spacing * 0.5 + float(i) * spacing
		blocks.append(_block(centre - spacing * 0.22, y - 62.0,
			spacing * 0.42, 34.0, "rooflight", Materials.GLASS))
		blocks.append(_block(centre + spacing * 0.24, y - 55.0,
			spacing * 0.46, 18.0, "sheeting", Materials.TIMBER))
	return blocks


static func _block(x: float, y: float, w: float, h: float, role: String,
		material: String) -> Dictionary:
	return {"x": x, "y": y, "w": w, "h": h, "role": role, "material": material}
