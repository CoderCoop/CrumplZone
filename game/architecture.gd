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
const HOUSE := "house"
const RETAIL := "retail"
const OVERPASS := "overpass"
const STAND := "stand"

## How deep the course over the openings is. It sits on top of the piers, so it
## adds to the storey height rather than fitting inside it.
##
## Depth is stiffness: this member spans the openings, so it is what stops the
## storeys above sagging into them. Measured at three depths with the parapet
## at each weight, 20 with a full parapet settles least — 15 px, against 29-32
## at every other combination tried. Thinning it to 15 doubled the settle and
## brought self-damage back; deepening it to 24 cleared the damage again but
## not the settle. This is the measured best, not a guess.
const LINTEL_H := 20.0

## How deep the shed's ground work is — the pads under the stanchions and the
## sills the cladding stands on, which are the same depth so nothing is built
## inside anything else.
const BASE_H := 10.0

const TYPES: Array[String] = [
	HOUSE, RETAIL, OVERPASS, STAND,
	CURTAIN_WALL, MASONRY, PANEL, FLAT_SLAB, STACK, SHED,
]

## What the generator may actually build.
##
## Masonry was held back from this list for a while: it settled 15 px
## untouched where the others settled under 2, and no amount of retuning its
## members moved it. It was never settling. Two blocks were being built inside
## other blocks — every upper pier inside the joists beside it, and the
## parapet through the whole top floor — and what looked like a wall bedding
## down was the engine pushing interpenetrating bodies apart. See _masonry,
## where both are now measured rather than assumed.
##
## The thing that found it was a picture. Four rounds of numeric fixes had
## treated a geometry error as a physics one; shots.gd rendered the building
## once and the leaning piers were unmistakable.
## Panel is held back, the way masonry was until its geometry was fixed.
##
## Not because it falls over — it stands perfectly well — but because it
## cannot be scored. A large-panel block's rubble is a big share of its own
## height, and there is no room above a pile like that to put a winning line
## and still be under the roof. Padded to clear its own rubble, one seed's
## winning line landed at 324 px on a 242 px building: a level won before it
## is touched.
##
## Re-measured with pileprobe, worst of six runs on three seeds, as a share
## of the building's own height:
##
##     house           9%
##     curtain wall   21%
##     shed           28%
##     panel        46-51%
##
## The note here used to say 65%, from a single measurement taken long ago.
## The share is smaller now and the conclusion is the same: panel is roughly
## double the worst system that ships. It stays out, and it now stays out on
## a comparison rather than on one number nobody had checked since.
##
## The cause is that a panel block is fifteen big precast slabs where other
## systems are thirty to sixty smaller members, so its debris is coarse and
## stacks high. The fix is in the architecture — more, smaller panels, or more
## storeys to raise the building against its own rubble — not in the scoring,
## and not in a constant. It comes back when its pile is in proportion.
## The grandstand came back in with the frame rebuild: its roof is carried on
## posts standing on the terrace now rather than cantilevered off a tie that
## could only have worked in tension, and twelve seeds in twelve stand.
##
## Load-bearing masonry is back too, and the paragraph above says why. It was
## disabled for carrying on damaging itself after settling — always the same
## brick pier, always standing still — and that was chased through widened
## piers and a raised rest tolerance before anyone rendered it. The cause was
## the interpenetration, and it is fixed and now gated by fittest.
##
## Measured before re-enabling it, sixteen seeds: fifteen hold outright and
## one takes a single point, which is the same shape as every shipped system.
## The old note here concluded it needed rebuilding as a monolithic wall. That
## was written against the broken geometry and is no longer what the numbers
## say, so it has gone rather than been left sitting under a system that
## stands up.
const GENERATED: Array[String] = [
	CURTAIN_WALL, MASONRY, FLAT_SLAB, STACK, SHED,
	HOUSE, RETAIL, OVERPASS, STAND,
]

## What each one is called on the level card, and the one-line reason it is
## different to knock down.
const ABOUT := {
	HOUSE: ["Brick house", "two rooms up, two down. The walls are the frame."],
	RETAIL: ["Strip mall", "one storey of shopfront. Almost all of it is glass."],
	OVERPASS: ["Overpass", "spans dropped on piers. Nothing ties them together."],
	STAND: ["Grandstand", "a raked terrace, and a roof on posts over the seats."],
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
		HOUSE:
			blocks = _house(rng)
		RETAIL:
			blocks = _retail(rng)
		OVERPASS:
			blocks = _overpass(rng)
		STAND:
			blocks = _stand(rng)
		_:
			blocks = _curtain_wall(rng)
	return {"blocks": blocks, "type": kind}


# --- a steel frame with glass hung off it ----------------------------------

static func _curtain_wall(rng: RandomNumberGenerator) -> Array:
	var storeys := rng.randi_range(3, 5)
	var columns := rng.randi_range(4, 6)
	var column := Vector2(rng.randf_range(20.0, 26.0), rng.randf_range(70.0, 82.0))
	var slab_h := 22.0
	# How far the glass keeps off the columns either side of it. It holds
	# nothing up and must not start: glazing fitted tight between the columns
	# braces the frame against shear, which took this building from solvable
	# in three moves to unsolvable in seven the one time it was tried.
	var clear := 22.0
	var blocks: Array = []

	# Bays of different widths rather than a repeating grid. The widest bay is
	# the longest span in the building, so the slab over it is the one worth
	# dropping — and which bay that is has to be found rather than assumed,
	# which is the whole difference from a frame where every bay is alike.
	#
	# The span is derived from the bay rather than drawn beside it, so there
	# is always room left over to vary. Drawn independently, a wide column and
	# a narrow spacing left nothing spare and _split fell back to an even
	# split — measured, two seeds in twenty-four came out as the regular grid
	# this is meant to replace, and they came out that way silently.
	var least: float = column.x + clear + 24.0
	var span: float = float(columns - 1) * (least + rng.randf_range(18.0, 44.0))
	var bays := _split(span, columns - 1, rng, 0.55, least)
	var nodes := _nodes(bays, -span * 0.5)

	# A tall ground floor and shallower ones above, the way a real office is
	# built. See _storey_heights: it is also the storey a demolition looks at
	# first, and a stack of identical ones has no such storey.
	var heights := _storey_heights(storeys, column.y,
		rng.randf_range(1.0, 1.32), rng, 0.09)

	# A setback: above some storey the frame steps in by one bay, on one side.
	# It is the largest change to the silhouette available here, it is what
	# every tower of this age actually did, and it makes the top of the
	# building a different shape from the bottom — so the rubble does not
	# arrive in a single square heap.
	#
	# One bay from one side rather than a bay from each. Stepping in from both
	# would put the storey above's columns inboard of the ones below on both
	# sides, which is a tower balanced on its own middle; stepping in from one
	# leaves a continuous line of columns down the other.
	var step_at := -1
	if storeys >= 4 and columns >= 5 and rng.randf() < 0.7:
		step_at = rng.randi_range(2, storeys - 1)
	var step_right: bool = rng.randf() < 0.5

	# One reinforced column at the ground floor on the taller ones: something
	# no tool goes through, so the building has to come down around it.
	var core := -1
	if storeys >= 4:
		core = int(columns / 2)

	var y := 0.0
	for storey in storeys:
		var high: float = heights[storey]
		var lo := 0
		var hi := columns - 1
		if step_at >= 0 and storey >= step_at:
			if step_right:
				hi -= 1
			else:
				lo += 1
		for i in range(lo, hi + 1):
			blocks.append(_block(nodes[i], y - high * 0.5,
				column.x, high, "column",
				Materials.REINFORCED if (storey == 0 and i == core)
					else Materials.STEEL))
		for i in range(lo, hi):
			# Between two columns, clear of both. Derived from the bay it
			# fills rather than from a nominal spacing, so an uneven bay
			# cannot put the glass inside the column beside it.
			var pane: float = bays[i] - column.x - clear
			blocks.append(_block((nodes[i] + nodes[i + 1]) * 0.5,
				y - high * 0.5, pane, high - 20.0, "glazing", Materials.GLASS))
		y -= high
		# The slab reaches the columns it is carrying and no further, so a
		# storey that has stepped in sits on a slab of its own width.
		var slab_w: float = nodes[hi] - nodes[lo] + column.x * 2.0
		blocks.append(_block((nodes[lo] + nodes[hi]) * 0.5, y - slab_h * 0.5,
			slab_w, slab_h, "roof" if storey == storeys - 1 else "slab",
			Materials.CONCRETE))
		y -= slab_h
		if storey == storeys - 1:
			# The plant room: lift overrun, tanks and air handling, in a box
			# on the roof and never in the middle of it. Every building of
			# this kind has one, and it is the heaviest thing at the top of
			# the lightest part of the frame — so which way the tower wants to
			# go over is a question with an answer.
			#
			# It is also what makes this system asymmetric by construction.
			# Uneven bays and a setback left it a mirror image whenever the
			# bays came out palindromic and no setback was drawn, and a gate
			# that passes on a coin toss is not a gate.
			var plant_w: float = (nodes[hi] - nodes[lo]) * rng.randf_range(0.22, 0.34)
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			var plant_x: float = (nodes[lo] + nodes[hi]) * 0.5 \
				+ side * (slab_w * 0.5 - plant_w * 0.5 - 14.0)
			blocks.append(_block(plant_x, y - 17.0, plant_w, 34.0,
				"plant", Materials.CONCRETE))
	return blocks


# --- load-bearing brick, arched openings ------------------------------------

## Uneven openings were built here and taken out again, and the measurements
## are kept because the next attempt should not start from nothing.
##
## A warehouse with a cart entrance is the most characterful thing this
## generator could have, and it cost five seeds in sixteen: 15 of 16 hold with
## the wall as it is here, 10 of 16 with openings of different widths. The loss
## was isolated to this function — the original body inside the otherwise
## changed file holds 15 of 16 — and then four explanations were tested and
## every one of them was wrong:
##
##   pier sized to its tributary opening   no change (10 of 16)
##   fatter piers throughout               worse (11, 8, 8 of 16 at rising ratios)
##   less mass on top (parapet 28>22>18)   no change (10, 10, 11 of 16)
##   milder unevenness (spread .5>.35>.2)  no change (10, 10, 11 of 16)
##
## Forward from the original, uneven bays alone cost two seeds (15 to 13) and
## the rest of the drop came from the other changes compounding, none of which
## cost anything measurable on its own. That is the shape of a system with no
## margin left, and the honest reading is that load-bearing brick here is at
## its limit before any variety is added — not that some constant is wrong.
##
## So it keeps its even bays for now. It is exempt in varietytest.gd, with this
## as the reason, and it comes back when there is an explanation rather than
## another guess. The place to look first is what a warehouse carries: three
## storeys of brick on piers is most of the mass in the game, and giving it
## something to spare is a different change from making it uneven.


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
		# A floor belongs between two storeys, so the top one does not get
		# one — that level is the roof, and the parapet stands on the wall
		# head above it.
		if storey == storeys - 1:
			break
		# The joists bear on the spandrel and must clear the piers standing on
		# it, which are the storey above's and so a different thickness from
		# the ones below. They were sized to the nominal bay and overlapped
		# those piers by 6 to 14 px on each side at every combination of the
		# generator's ranges — so every pier above the ground storey was built
		# inside two joists and shoved sideways out of them on the first
		# frame. That is what the 15 px of untouched sag was: not a wall
		# bedding down, a wall being pushed apart. A picture of it showed it
		# in seconds; four rounds of retuning members had not.
		var above: float = pier * (1.0 + batter * float(storeys - 2 - storey))
		var clear: float = opening + pier - above - 6.0
		for i in bays:
			var mid := first + pier * 0.5 + opening * 0.5 + float(i) * (opening + pier)
			blocks.append(_block(mid, y - floor_h * 0.5, clear,
				floor_h, "joist", Materials.TIMBER))

	# A brick parapet, the detail that makes the top read as a warehouse.
	# It stands on the top spandrel, where a wall head is. It used to be put
	# half a storey up from there, straight through the top floor's joists —
	# a full-width block sharing space with every one of them. That is why
	# lightening it made the building settle further instead of less: the
	# depth was never carrying anything, it was setting how hard the engine
	# had to push to separate two things built inside each other.
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
	var column_w := rng.randf_range(14.0, 18.0)
	var storey_h := rng.randf_range(52.0, 62.0)
	var slab_h := 20.0
	var blocks: Array = []

	# Bays of different widths. A car park is poured to a structural grid and
	# a real one is not square: the bays over the ramp and the lift core are
	# wider than the parking bays, because that is what has to fit under them.
	# The wide bay is the long span, which is the one that drops a whole floor
	# when its column goes.
	#
	# The average pitch is the one this deck has always had, 71 px. Sized from
	# the column instead and drawn freely it came out at a mean of 97, and a
	# car park 37% wider on the same posts is not a change anyone asked for —
	# so it is held to its own size. It did not, however, explain anything:
	# uneven bays cost two seeds in sixteen at either width.
	#
	# What those two seeds do is take one point of damage on one piece, with
	# 2.5 px of sag — the marginal reading loadprobe.gd was written about, not
	# a structure coming apart. Masonry's were three and four points across
	# several piers, which is why that system kept its even bays and this one
	# did not. Neither loss is explained; the difference in kind is the whole
	# of the reason they were decided differently, and it is recorded here so
	# that decision can be argued with rather than guessed at.
	#
	# The floor keeps the core clear of the post beside it and nothing more.
	var least: float = column_w * 2.4 + 14.0
	var pitch: float = least + rng.randf_range(10.0, 26.0)
	var bays := _split(float(columns - 1) * pitch, columns - 1, rng, 0.5, least)
	var nodes := _nodes(bays, -float(columns - 1) * pitch * 0.5)
	var span: float = nodes[columns - 1] - nodes[0] + column_w * 3.0 \
		+ column_w * 0.14 * float(decks - 1)
	var core_at: int = 0 if rng.randf() < 0.5 else columns - 1
	var y := 0.0

	for deck in decks:
		# Columns get bigger lower down, because there is more above them —
		# the same reason a masonry wall batters, and the reason the panel
		# block's ground storey is heavier. A frame of constant column is a
		# drawing convention, not a building: at five decks on 14 px posts,
		# gentest caught the ground storey crushing itself untouched.
		var thickness: float = column_w * (1.0 + 0.14 * float(decks - 1 - deck))
		for i in columns:
			# The stair and lift core stands on one of the end column lines,
			# in place of a column rather than beside one. It is the one stiff
			# thing in a building that is otherwise slabs balanced on sticks,
			# real car parks are braced by exactly this, and it is reinforced
			# — so the decks have to be brought down around it.
			#
			# It is also what makes this system asymmetric by construction.
			# Uneven bays alone left it a mirror image whenever they came out
			# palindromic, and a gate that passes on a coin toss is not a gate.
			#
			# In the column's slot, not through it: a full-height shaft would
			# have every deck built inside it, which is the failure this file
			# has shipped four times.
			var is_core: bool = i == core_at
			blocks.append(_block(nodes[i], y - storey_h * 0.5,
				column_w * 2.4 if is_core else thickness, storey_h,
				"core" if is_core else "post",
				Materials.REINFORCED if is_core else Materials.CONCRETE))
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
	blocks.append(_block(0.0, -16.0, base_w * 1.5, 32.0, "plinth",
		Materials.CONCRETE, true))
	y = -32.0
	for course in courses:
		var t := float(course) / float(maxi(courses - 1, 1))
		var w: float = lerpf(base_w, top_w, t)
		# Built as two half-shafts per course rather than one block, so there
		# is a vertical joint down the middle. A stack does not crush — it
		# hinges and goes over — and it needs somewhere to hinge.
		var low: bool = course < 2
		var made_of: String = Materials.CONCRETE if low else Materials.BRICK
		for side in [-1.0, 1.0]:
			blocks.append(_block(side * w * 0.25, y - course_h * 0.5,
				w * 0.5 - 1.0, course_h, "shaft", made_of, low))
		y -= course_h
	blocks.append(_block(0.0, y - 9.0, top_w * 1.25, 18.0, "cap", Materials.CONCRETE))
	return blocks


# --- long-span shed ---------------------------------------------------------

static func _shed(rng: RandomNumberGenerator) -> Array:
	var bays := rng.randi_range(4, 6)
	var height := rng.randf_range(108.0, 140.0)
	var column_w := rng.randf_range(19.0, 24.0)
	var blocks: Array = []

	# Bays of different widths. A shed is built to whatever it has to house,
	# and the bay over the crane run or the machine is wider than the rest —
	# which is also the bay whose truss carries furthest with least under it.
	#
	# Derived from the pad, so a bay can never be narrower than the two pads
	# either side of it plus the sill between them.
	var least: float = column_w * 2.2 + 42.0
	var total: float = float(bays) * (least + rng.randf_range(8.0, 36.0))
	var widths := _split(total, bays, rng, 0.44, least)
	var nodes := _nodes(widths, -total * 0.5)
	var first: float = nodes[0]
	var span: float = total + column_w
	var y := 0.0

	# One bay is left open as the doorway, which is what a shed is for. Chosen
	# before anything is placed, because the ground work skips it too.
	var door := rng.randi_range(0, bays - 1)

	# Stanchions on pad footings. Measured before they had any: two shed seeds
	# in twelve fell over untouched — a row of slender columns carrying a wide
	# truss is an inverted pendulum, and a real one is bolted to a pad footing
	# for exactly that reason.
	for i in bays + 1:
		var x: float = nodes[i]
		blocks.append(_block(x, -BASE_H * 0.5, column_w * 2.2, BASE_H,
			"footing", Materials.CONCRETE))
		blocks.append(_block(x, -BASE_H - (height - BASE_H) * 0.5,
			column_w, height - BASE_H, "stanchion", Materials.STEEL))
	# A sill between each pair of pads for the cladding to stand on. Cast in
	# bays rather than as one beam across the whole span, which is both how
	# ground work is really poured and what the stress model needs: a piece
	# is judged on the sum of every contact impulse on it, so one member
	# touching the street, every stanchion and every wall accumulates what
	# the same load spread over separate members never does.
	#
	# One continuous beam was tried here first and is the reason that is
	# written down. It read as the obvious simplification — fewer members,
	# a wider base for what is otherwise an inverted pendulum — and it
	# crushed itself standing still. Deepening it made it worse, not better,
	# which is what said the depth was never the problem: at 12 px one shed
	# in twelve failed, at 24 px two did, because the extra concrete was
	# more weight on the same summed contact rather than more section.
	for i in bays:
		if i == door:
			continue
		blocks.append(_block((nodes[i] + nodes[i + 1]) * 0.5,
			-BASE_H * 0.5, _sill_of(widths[i], column_w), BASE_H,
			"footing", Materials.CONCRETE))
	y = -height
	# Truss: a bottom chord across the whole span, a top chord, and posts
	# between them. Light, deep, and it carries a long way on very little.
	blocks.append(_block(0.0, y - 6.0, span, 12.0, "chord", Materials.STEEL))
	blocks.append(_block(0.0, y - 40.0, span, 10.0, "chord", Materials.STEEL))
	# Web posts on every stanchion line and on every bay's middle, which with
	# uneven bays is no longer an even sequence — the truss is panelled to the
	# frame under it, the way a real one is.
	for i in bays + 1:
		blocks.append(_block(nodes[i], y - 23.0, 7.0, 22.0, "web",
			Materials.STEEL))
	for i in bays:
		blocks.append(_block((nodes[i] + nodes[i + 1]) * 0.5, y - 23.0, 7.0,
			22.0, "web", Materials.STEEL))
	# Sawtooth roof: a glazed face and a solid face per bay, north-light,
	# which is what these were built with.
	for i in bays:
		var centre: float = (nodes[i] + nodes[i + 1]) * 0.5
		var wide: float = widths[i]
		blocks.append(_block(centre - wide * 0.22, y - 62.0,
			wide * 0.42, 34.0, "rooflight", Materials.GLASS))
		blocks.append(_block(centre + wide * 0.24, y - 55.0,
			wide * 0.46, 18.0, "sheeting", Materials.TIMBER))

	# Cladding on the walls. Without it this was a row of columns holding a
	# truss up in the air — structurally a shed, and to look at, a viaduct.
	#
	# In horizontal courses rather than one panel per bay, for a physical
	# reason: a full-height sheet 20 px thick standing on the ground between
	# two stanchions has nothing holding it upright and falls over. Courses
	# are wide relative to their height and stack, the way the stack's own
	# shaft does.
	#
	# Clear of the stanchions on each side and of the bottom chord above, so
	# the wall is something the shed carries rather than something bracing it.
	# The curtain wall learned this the expensive way: glazing fitted tight
	# between its columns braced the frame against shear and took the same
	# building from solvable in three moves to unsolvable in seven. Cladding
	# holds nothing up, and has to be built so that it cannot start.
	# Up to just under the eaves. At 30 px of clearance the wall stopped a
	# quarter of the way down the elevation and read as a hoarding rather
	# than a building; 14 leaves the chord free without the gap showing.
	var wall_h := height - 14.0 - BASE_H
	# Shallow courses, because deep ones read as stacked crates rather than
	# as siding — five or six on a wall of this height.
	var rows := maxi(int(wall_h / 22.0), 1)
	var course_h := wall_h / float(rows)
	for i in bays:
		if i == door:
			continue
		var cx: float = (nodes[i] + nodes[i + 1]) * 0.5
		var clad_w: float = _sill_of(widths[i], column_w) - 4.0
		for c in rows:
			blocks.append(_block(cx, -BASE_H - course_h * (float(c) + 0.5),
				clad_w, course_h - 1.0, "sheeting", Materials.TIMBER))
	return blocks


## The clear width between two pads, less a little. Everything at ground level
## in a bay is derived from this one number rather than measured from the bay:
## the sill is this wide and the wall standing on it is narrower still, so
## neither can be built inside a pad. Sizing the wall from the bay instead put
## it 1.4 to 4.4 px into the pads at the ends of the generator's ranges — small
## enough that the stability gate passed anyway, which is what makes it worth
## writing down rather than leaving.
##
## A function rather than a value, because with bays of different widths there
## is now a different answer per bay.
static func _sill_of(bay: float, column_w: float) -> float:
	return bay - column_w * 2.2 - 6.0


# --- a small brick house -----------------------------------------------------

## Two storeys of load-bearing brick with timber floors and a pitched roof.
##
## The smallest thing in the game and the most familiar, and it comes down
## unlike anything else: there is no frame and no core, just two cross walls
## carrying everything. Take a wall out low and the whole thing folds into its
## own footprint. That is what actually happens to a terrace when the one next
## door is demolished badly.
##
## The roof is what makes it read as a house rather than a box, and it is also
## why it is worth demolishing carefully: it is timber, it is the lightest
## thing here, and it comes down first and hurts nothing.
static func _house(rng: RandomNumberGenerator) -> Array:
	var storeys := rng.randi_range(2, 3)
	var width := rng.randf_range(150.0, 205.0)
	var wall := rng.randf_range(20.0, 26.0)
	var storey_h := rng.randf_range(76.0, 88.0)
	var floor_h := 12.0
	var blocks: Array = []
	var half := width * 0.5
	var y := 0.0

	# A stone plinth course. Real brick houses sit on something that does not
	# wick water, and it gives the wall a base that will not crush.
	blocks.append(_block(0.0, -7.0, width, 14.0, "plinth", Materials.STONE))
	y = -14.0
	# Where the floor a storey's windows sit on actually is. On the ground
	# floor it is the plinth; above, it is the top of the joist spanning
	# between the walls — which is 12 px higher than where the piers start,
	# because the piers pass the joist rather than standing on it.
	#
	# The sills used to be placed at the piers' level, which built every
	# first-floor sill 10 px inside the joist under it. fittest found it in
	# every house seed; nothing had ever looked.
	var deck := y

	for storey in storeys:
		for side in [-1.0, 1.0]:
			blocks.append(_block(side * (half - wall * 0.5), y - storey_h * 0.5,
				wall, storey_h, "pier", Materials.BRICK))
		# A window each side of a middle pier on the ground floor, and a
		# smaller pair above: the asymmetry between the two is most of what
		# tells one storey from another at a glance.
		var open_w := (width - wall * 2.0) * 0.5 - 8.0
		if storey == 0:
			blocks.append(_block(0.0, y - storey_h * 0.5, wall * 0.7, storey_h,
				"pier", Materials.BRICK))
		# Windows on sills, not floating in the opening.
		#
		# They used to hang 30 px above the floor with nothing under them, so
		# every one of them fell on the course below the moment the level
		# started and sat there loading it. A window in a masonry wall bears
		# on a sill; this is that, and it is also why the glass in a house
		# reads as part of the wall rather than as something suspended in it.
		var sill_h := 10.0
		var glass_h := storey_h * 0.44
		for i in 2:
			var mid := (-1.0 if i == 0 else 1.0) * (open_w * 0.5 + wall * 0.35)
			blocks.append(_block(mid, deck - sill_h * 0.5, open_w * 0.62,
				sill_h, "plinth", Materials.STONE))
			blocks.append(_block(mid, deck - sill_h - glass_h * 0.5,
				open_w * 0.62, glass_h, "glazing", Materials.GLASS))
		# A stone lintel course over the openings, then the floor.
		y -= storey_h
		blocks.append(_block(0.0, y - 9.0, width, 18.0, "spandrel", Materials.STONE))
		y -= 18.0
		deck = y
		if storey < storeys - 1:
			blocks.append(_block(0.0, y - floor_h * 0.5, width - wall * 2.0 - 8.0,
				floor_h, "joist", Materials.TIMBER))
			deck = y - floor_h

	# A pitched roof, stepped rather than sloped, because every collider here
	# is an axis-aligned rectangle and a stepped gable reads as a pitch at
	# this size. Timber, and the first thing to go.
	var steps := 4
	for i in steps:
		var t := float(i) / float(steps)
		blocks.append(_block(0.0, y - 9.0 - float(i) * 16.0,
			width * (1.0 - t * 0.62), 16.0, "gable", Materials.TIMBER))
	# The chimney, off to one side as they always are, and brick where the
	# roof is timber — the one heavy thing on top of the lightest.
	var stack_x := (half - wall) * (1.0 if rng.randf() < 0.5 else -1.0) * 0.55
	blocks.append(_block(stack_x, y - 9.0 - float(steps) * 16.0 - 18.0,
		26.0, 44.0, "shaft", Materials.BRICK))
	return blocks


# --- a single-storey strip of shops -------------------------------------------

## One storey, wide, and almost entirely glass.
##
## The opposite problem from everything else here: there is barely anything
## holding it up, so the difficulty is not getting it down but getting it down
## *low*. A shopfront leaves a wide flat pile and a parapet that has to be
## brought over as well.
static func _retail(rng: RandomNumberGenerator) -> Array:
	var units := rng.randi_range(3, 5)
	var height := rng.randf_range(96.0, 116.0)
	var column_w := rng.randf_range(16.0, 22.0)
	var blocks: Array = []
	var deck_h := 18.0

	# Shops of different widths, because a parade of identical ones is a
	# drawing convention rather than a street. The widest unit has the longest
	# span of deck over it and the most glass under it, so which shopfront is
	# worth taking out is a question rather than a formality.
	#
	# Derived so there is always room to vary: a unit narrower than a column
	# plus its clearances is a pane of negative width — see _split.
	var least: float = column_w + 46.0
	var span: float = float(units) * (least + rng.randf_range(30.0, 66.0))
	var widths := _split(span, units, rng, 0.5, least)
	var nodes := _nodes(widths, -span * 0.5)

	blocks.append(_block(0.0, -7.0, span, 14.0, "footing", Materials.CONCRETE))
	for i in units + 1:
		blocks.append(_block(nodes[i], -14.0 - (height - 14.0) * 0.5, column_w,
			height - 14.0, "column", Materials.STEEL))
	for i in units:
		var mid: float = (nodes[i] + nodes[i + 1]) * 0.5
		var unit_w: float = widths[i]
		# Glazing standing on the footing and stopping short of the deck:
		# clear of the columns either side so it braces nothing, and bearing
		# on something so it is not suspended.
		#
		# It was sized to neither. Sitting 10 px above the footing with
		# nothing under it, every pane in every shop dropped onto the slab the
		# moment the level started and sat there loading it — measured at
		# sixteen times what glass tolerates at rest. A shopfront pane stands
		# in a frame on the slab; this is that.
		var glass_top := -height + 10.0
		var glass_bottom := -14.0
		blocks.append(_block(mid, (glass_top + glass_bottom) * 0.5,
			unit_w - column_w - 22.0, glass_bottom - glass_top,
			"glazing", Materials.GLASS))
		# An awning over each shopfront, clear of the glass below it.
		#
		# It was built 8.5 px inside the glazing at every height the generator
		# makes — the fourth time in this file that two blocks have been put
		# in the same place, and the reason a shopfront pane was reading
		# fifteen times its resting tolerance. An awning hangs off the fascia
		# above the window, not through it.
		blocks.append(_block(mid, -height + 4.0, unit_w - column_w - 10.0,
			8.0, "awning", Materials.SHEET))
	var y := -height
	blocks.append(_block(0.0, y - deck_h * 0.5, span, deck_h, "deck",
		Materials.CONCRETE))
	y -= deck_h
	# The sign band. Tall, light, and the thing that has to come over.
	blocks.append(_block(0.0, y - 17.0, span, 34.0, "parapet", Materials.SHEET))
	# One unit is the anchor, and its fascia stands proud of the rest — which
	# is what every parade of shops has and none of these did.
	#
	# It is also the reason this system is not a mirror image of itself by
	# construction rather than by luck. Uneven units alone left it symmetric
	# whenever the widths happened to come out palindromic: measured, one seed
	# in twenty-four, which is a gate that passes on a coin toss.
	# At one end of the parade, which is where the big store is, and never in
	# the middle — a raised fascia centred on the middle unit of an odd number
	# of them is symmetric again, which is how the first version of this still
	# left one seed in twenty-four a mirror image.
	var anchor: int = 0 if rng.randf() < 0.5 else units - 1
	blocks.append(_block((nodes[anchor] + nodes[anchor + 1]) * 0.5, y - 46.0,
		widths[anchor] - 12.0, 24.0, "parapet", Materials.SHEET))
	return blocks


# --- a road on legs -----------------------------------------------------------

## Precast spans dropped on piers, which is how most of them are built and the
## whole of why they fail: the spans are not tied to each other or to the pier.
## Take one pier and the two spans it carries drop, and nothing beside them
## much cares.
static func _overpass(rng: RandomNumberGenerator) -> Array:
	var spans := rng.randi_range(3, 5)
	var height := rng.randf_range(118.0, 158.0)
	var pier_w := rng.randf_range(26.0, 34.0)
	var blocks: Array = []
	var deck_h := 20.0

	# Spans of different lengths, which is what an overpass actually has: the
	# one over the road it crosses is longer than the ones over the verge.
	# The long span is the heaviest beam on the thinnest support, so which
	# pier matters most is a question about this bridge rather than a rule
	# about bridges.
	#
	# Derived so the footings can never meet: a span shorter than two pier
	# pads is two pads built into each other.
	var least: float = pier_w * 2.4
	var total: float = float(spans) * (least + rng.randf_range(48.0, 96.0))
	var lengths := _split(total, spans, rng, 0.42, least)
	var nodes := _nodes(lengths, -total * 0.5)
	for i in spans + 1:
		var x: float = nodes[i]
		blocks.append(_block(x, -9.0, pier_w * 2.1, 18.0, "footing",
			Materials.CONCRETE))
		blocks.append(_block(x, -18.0 - (height - 18.0) * 0.5, pier_w,
			height - 18.0, "post", Materials.REINFORCED if i % 3 == 1
				else Materials.CONCRETE))
		# A pier cap, wider than the pier, which is what the spans bear on.
		blocks.append(_block(x, -height - 8.0, pier_w * 1.9, 16.0, "cap",
			Materials.CONCRETE))
	var y := -height - 16.0
	for i in spans:
		var mid: float = (nodes[i] + nodes[i + 1]) * 0.5
		var span_w: float = lengths[i]
		# Each span is its own beam, sitting on two caps and touching nothing
		# else. Separate pieces, because separate is the point.
		# Pier centre to pier centre, less a joint. Each span bears half on
		# each cap and butts against its neighbour, which is what makes it a
		# road rather than a row of stubs — the first version was sized to the
		# gap between the caps and left the deck floating in pieces.
		blocks.append(_block(mid, y - deck_h * 0.5, span_w - 5.0,
			deck_h, "deck", Materials.CONCRETE))
	y -= deck_h
	for i in spans:
		var mid: float = (nodes[i] + nodes[i + 1]) * 0.5
		blocks.append(_block(mid, y - 8.0, lengths[i] - 9.0, 16.0,
			"parapet", Materials.CONCRETE))
	# A sign gantry over one span, on a leg standing on the deck beside the
	# parapet. It is the one thing up here that is not part of the road, it is
	# off to one side, and it is what makes this structure something other
	# than its own mirror image — uneven spans alone left it symmetric
	# whenever the lengths came out palindromic.
	var gantry_at: int = 0 if rng.randf() < 0.5 else spans - 1
	var gantry_x: float = (nodes[gantry_at] + nodes[gantry_at + 1]) * 0.5
	var leg_h := 38.0
	blocks.append(_block(gantry_x - lengths[gantry_at] * 0.28,
		y - 16.0 - leg_h * 0.5, 12.0, leg_h, "post", Materials.STEEL))
	blocks.append(_block(gantry_x, y - 16.0 - leg_h - 9.0,
		lengths[gantry_at] * 0.62, 18.0, "sign", Materials.SHEET))
	return blocks


# --- a grandstand -------------------------------------------------------------

## A raked terrace on legs with a roof reaching out over it.
##
## The roof is the interesting part: it is a cantilever, held down at the back
## and reaching forward over the seats with nothing under its front edge. Take
## the back columns and it goes over forwards, which is the one structure here
## that fails by rotating rather than by dropping.
static func _stand(rng: RandomNumberGenerator) -> Array:
	var tiers := rng.randi_range(5, 7)
	var tread := rng.randf_range(44.0, 56.0)
	var rise := rng.randf_range(26.0, 32.0)
	var leg_w := rng.randf_range(20.0, 26.0)
	var blocks: Array = []
	var depth := float(tiers) * tread
	var first := -depth * 0.5
	var back := first + depth - tread * 0.5
	var head := -16.0 - rise * float(tiers) - 84.0
	# No continuous footing. One slab under the whole stand crushed itself on
	# every seed — the same failure the shed's ground beam had, and for the
	# same reason: a single member in contact with the street, every leg and
	# every step reads the sum of all of them, and concrete's tolerance does
	# not cover it. The terrace needs no footing anyway, because each step is
	# a mass standing on the ground already; only the columns get pads.

	# Terracing as a stepped solid, one block per tier standing on the ground.
	#
	# It was one deck per leg to start with, each step balanced on a single
	# post at its middle like a table, and it fell over on the first frame —
	# which is what a table balanced on one leg does. A terrace is a mass with
	# steps cut into it, not a row of tables, and built that way it is the
	# most stable thing in the game.
	var deck_top: Array[float] = []
	for i in tiers:
		var x := first + tread * 0.5 + float(i) * tread
		var top := -16.0 - rise * float(i + 1)
		blocks.append(_block(x, top * 0.5, tread - 1.0, absf(top),
			"riser", Materials.CONCRETE))
		# The tread itself, a slab across the step, in the lighter material
		# that reads as the seating deck rather than the mass under it.
		blocks.append(_block(x, top - 8.0, tread + 1.0, 16.0, "deck",
			Materials.CONCRETE))
		deck_top.append(top - 16.0)

	# The rear frame stands behind the terrace, on the street.
	#
	# It used to stand at `back`, which is the centre of the last riser — so
	# both pads were built inside the terrace, overlapping it and each other.
	# That is a geometry error wearing a physics failure's clothes: the whole
	# stand sank thirty pixels while the pads squeezed up out of it, and no
	# amount of retuning a material would have touched it. Same class of bug
	# as the masonry piers, found the same way, by printing which piece moved.
	#
	# Everything below is derived from one clearance so it cannot come back:
	# the pads clear the terrace, and they clear each other.
	const CLEAR := 3.0
	var pad_half := leg_w * 0.6
	var spread := leg_w * 1.5
	var frame_x: float = first + depth + CLEAR + spread + pad_half
	var legs_top := head + 7.0
	# Standing on the pad, not through it. The old formula put the stanchion's
	# foot at -7 and the pad at -14 to 0, so seven pixels of every column were
	# inside the thing it was standing on — in every seed, for as long as this
	# system has existed.
	var pad_top := -14.0
	for side in [-1.0, 1.0]:
		var cx: float = frame_x + float(side) * spread
		blocks.append(_block(cx, pad_top * 0.5, pad_half * 2.0, absf(pad_top),
			"footing", Materials.CONCRETE))
		blocks.append(_block(cx, (legs_top + pad_top) * 0.5, leg_w,
			absf(pad_top - legs_top), "stanchion", Materials.STEEL))

	# Props standing on the terrace under the roof, and the whole reason this
	# system was disabled.
	#
	# It was a cantilever: the roof reached forward over the seats and a
	# slender post behind the stanchions was supposed to hold its back span
	# down. Measured over six seeds, that post fell flat on four of them and
	# took the roof with it — and the reason is not that the post was too
	# thin. The roof's centre of mass sat 51 px in front of everything holding
	# it up, so the post was being asked to resist uplift, in a simulation
	# with no joints, where nothing can pull on anything. A post can only
	# push. Widening its footing was tried and did not help, because the
	# footing was never the problem.
	#
	# So the roof is carried from underneath instead, on posts standing on the
	# terrace — which is what most grounds built, obstructed views and all.
	# Every member is in compression, and the demolition is better for it:
	# take a post out and the roof comes down on the seats.
	var roof_front := first + tread * 0.8
	var roof_back := frame_x + spread + leg_w * 0.5
	# Centred on the step it stands on, not wherever the share lands. Placed by
	# the share alone, a prop overhung its deck by 6 px and that 6 px was
	# inside the next riser, twelve pixels above the deck it was standing on —
	# the same interpenetration as the pads, an order of magnitude smaller and
	# just as much a geometry error. A prop is narrower than a tread, so
	# centring it on one is enough to make that impossible rather than
	# unlikely.
	var used := -1
	for share in [0.24, 0.60]:
		var want: float = lerpf(roof_front, roof_back, share)
		var tier: int = clampi(int(floor((want - first) / tread)), 0,
			tiers - 1)
		if tier <= used:
			tier = mini(used + 1, tiers - 1)
		used = tier
		var prop_x: float = first + tread * (float(tier) + 0.5)
		var prop_foot: float = deck_top[tier]
		blocks.append(_block(prop_x, (legs_top + prop_foot) * 0.5,
			leg_w * 0.9, absf(prop_foot - legs_top), "prop",
			Materials.STEEL))

	# The chord across every support, and the roof on top of it. The roof
	# overhangs a little at each end, because a roof flush with its supports
	# reads as a lid.
	var chord_front: float = lerpf(roof_front, roof_back, 0.24) - leg_w
	blocks.append(_block((chord_front + roof_back) * 0.5, legs_top - 8.0,
		roof_back - chord_front, 16.0, "chord", Materials.STEEL))
	blocks.append(_block((roof_front + roof_back) * 0.5, legs_top - 23.0,
		roof_back - roof_front, 14.0, "canopy", Materials.SHEET))
	return blocks


## Splits `total` into `count` pieces that differ in width, sum to exactly
## `total`, and are never narrower than `least`.
##
## This is where variety within a building comes from, and the shape of it is
## a safety property rather than a style. Jittering each member's position by
## a few pixels is the obvious way to break up a regular grid, and it is how
## four systems in this file ended up with blocks built inside each other,
## each chased for rounds as a physics failure. Pieces that tile a span cannot
## overlap: each one begins exactly where the last one ended, whatever the
## random numbers do.
##
## `least` is guaranteed rather than hoped for — every piece is given it
## before any of the remainder is shared out. A caller derives its own members
## from the bay it is filling (a column each side, a pane between), so a bay
## narrower than those add up to is a pane with negative width, and "unlikely
## at the middle of the range" is how the last four of these got shipped.
##
## `spread` applies to the remainder, not to the whole, so it says how uneven
## the spare room is rather than how uneven the bays are. 0.0 is the regular
## grid this replaced.
static func _split(total: float, count: int, rng: RandomNumberGenerator,
		spread: float, least: float) -> Array[float]:
	var parts: Array[float] = []
	if count <= 0:
		return parts
	var spare: float = total - least * float(count)
	if spare <= 0.0:
		# The caller has asked for more pieces than the span holds. An even
		# split is the honest answer; a negative one is not.
		for i in count:
			parts.append(total / float(count))
		return parts
	var weights: Array[float] = []
	var sum := 0.0
	for i in count:
		var weight: float = 1.0 + rng.randf_range(-spread, spread)
		weights.append(weight)
		sum += weight
	for i in count:
		parts.append(least + spare * weights[i] / sum)
	return parts


## The boundaries between pieces that tile a span, both ends included. A
## frame's columns stand on these and its bays fill the gaps between them, so
## a column can never land inside the glass beside it.
static func _nodes(widths: Array[float], left: float) -> Array[float]:
	var out: Array[float] = [left]
	var x := left
	for w in widths:
		x += w
		out.append(x)
	return out


## Storey heights, with a taller one at the bottom.
##
## Real buildings have a tall ground floor — a lobby, a shopfront, a loading
## bay — and it is also the first place a demolition looks: the storey with
## the most slender columns carrying the most weight above them. Soft-storey
## collapse is a real failure mode, and a frame of identical storeys has
## nowhere for it to happen.
static func _storey_heights(count: int, base: float, ground: float,
		rng: RandomNumberGenerator, spread: float) -> Array[float]:
	var out: Array[float] = []
	var total := 0.0
	for i in count:
		out.append(base * (1.0 + rng.randf_range(-spread, spread)))
	if count > 0:
		out[0] = base * ground
	for h in out:
		total += h
	# Rescaled so the building ends up the height it would have been anyway. A
	# taller ground storey comes out of the storeys above it rather than being
	# added on top, which is what a real building does under a height limit —
	# and it keeps `base` meaning what it says, so a caller's storey range
	# still describes the building it gets rather than a number the ground
	# floor then multiplies.
	var want: float = base * float(count)
	if total > 0.0:
		for i in count:
			out[i] = out[i] / total * want
	return out


## `fixed` marks a material that was chosen because a measurement said so,
## rather than for character. generator.gd's era substitution leaves those
## alone, the same way it already leaves reinforced concrete alone.
##
## The chimney is why this exists. Its plinth and the bottom two courses of
## its shaft are concrete because brick there sits within a few percent of
## what brick carries standing still — and the victorian era swaps concrete
## for timber, so it replaced the whole base of a 700 to 950 px stack with
## the softest material in the game. Every victorian chimney fell over
## untouched, five seeds out of five, and all three that reached the pack
## were dropped by the generate step for it. The era is supposed to change what a
## building is made of without changing whether it stands up.
static func _block(x: float, y: float, w: float, h: float, role: String,
		material: String, fixed := false) -> Dictionary:
	var block := {"x": x, "y": y, "w": w, "h": h, "role": role,
		"material": material}
	if fixed:
		block["fixed"] = true
	return block
