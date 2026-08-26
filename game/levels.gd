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
## How high a level's rubble sits when it is completely destroyed, estimated
## from the building rather than measured.
##
## An authored level can be pulverised in a harness and measured. A generated
## one cannot: the estimate has to be made at the moment the level is built,
## with nobody watching. So this is deliberately pessimistic — it assumes the
## debris spreads less than it really does, which over-estimates the pile,
## which puts the lines higher, which makes a level too easy rather than
## impossible. That is the safe direction to be wrong in, and gentest.gd fails
## if the estimate ever comes out *below* what a level really leaves.
##
## The spread term is per unit of height, because debris travels in proportion
## to how far it fell. It is not a constant that can be trusted on its own —
## measured across the authored levels it ranged over a factor of two — which
## is why this is a floor rather than a prediction.
## How far debris spreads per unit of the height it fell, per structural
## system — because how far it spreads follows from how the building fails.
## A chimney goes over in one direction; a shed's roof comes down almost in
## place across a footprint that was already wide; a masonry wall collapses
## into its own plan.
##
## Measured, not chosen. gentest.gd pulverises sampled levels and reports what
## spread each one would have needed for the estimate to have been exact;
## these are the smallest observed for each system, less 15%. Smaller means a
## narrower spread means a higher estimate, and a high estimate only makes a
## level easier — the direction it is safe to be wrong in.
##
## Ranges seen: flat_slab 1.12-3.01, masonry 1.37-1.70, stack 2.15,
## shed 2.17-6.10, curtain_wall 2.40, panel 2.04.
const SPREAD_PER_HEIGHT := {
	"flat_slab": 0.95,
	"masonry": 1.16,
	"panel": 1.73,
	"stack": 1.83,
	"shed": 1.45,
	"curtain_wall": 2.04,
}
const SPREAD_DEFAULT := 0.95
const PACKING := 0.62
const LINE_MIN := 90.0

## No line may sit higher than this share of the building's own height. A wide
## low building has little material over a large footprint, so its estimated
## pile is small and a line set purely as a multiple of it lands near the roof
## — measured, a shed 202 px tall had its winning line at 202, which is a level
## already won before it is touched.
const LINE_OVER_HEIGHT := 0.52


static func estimate_pile(blocks: Array, kind := "") -> float:
	var area := 0.0
	var left := INF
	var right := -INF
	var top := INF
	var bottom := -INF
	for b in blocks:
		area += float(b["w"]) * float(b["h"])
		left = minf(left, float(b["x"]) - float(b["w"]) * 0.5)
		right = maxf(right, float(b["x"]) + float(b["w"]) * 0.5)
		top = minf(top, float(b["y"]) - float(b["h"]) * 0.5)
		bottom = maxf(bottom, float(b["y"]) + float(b["h"]) * 0.5)
	if area <= 0.0:
		return LINE_MIN / WIN_LINE_OVER_PILE
	var height: float = maxf(bottom - top, 1.0)
	var per_height: float = float(SPREAD_PER_HEIGHT.get(kind, SPREAD_DEFAULT))
	var spread: float = maxf(right - left, 1.0) + height * per_height * 2.0
	return area / (spread * PACKING)


const COLUMN := Vector2(22.0, 76.0)
const SLAB_H := 22.0


## The three authored difficulties. Generated levels come from generator.gd
## and go through the same finish() below, so nothing downstream can tell them
## apart.
const EASY := "easy"
const MEDIUM := "medium"
const HARD := "hard"
const ORDER: Array[String] = [EASY, MEDIUM, HARD]

const TITLES := {
	EASY: "Easy",
	MEDIUM: "Medium",
	HARD: "Hard",
}


static func level(difficulty: String) -> Dictionary:
	match difficulty:
		EASY:
			return finish(_placed(tower(3, 4, 86.0, false), difficulty, 8))
		HARD:
			return finish(_placed(tower(4, 5, 84.0, true, 2), difficulty, 10))
		_:
			return finish(_placed(tower(3, 5, 86.0, true), difficulty, 8))


static func _placed(spec: Dictionary, difficulty: String, depth: int) -> Dictionary:
	spec["difficulty"] = difficulty
	spec["moves"] = depth
	spec["title"] = TITLES.get(difficulty, "Level")
	spec["about"] = "a steel frame, glazed. The glass holds nothing up."
	spec["kind"] = "curtain_wall"
	return spec


## How much bar a level gets, per pixel of material in it.
##
## Sized from the building rather than from a solved par. Par had to be
## re-measured with the solver every time the physics changed what a demolition
## costs — which happened twice in one day — and since the rating is drawn on
## the level as lines now, the bar's only job is to be enough. Enough is a
## function of how much building there is.
##
## Calibrated so the medium tower gets about what its measured par bought it.
const POWER_PER_AREA := 0.0048
const POWER_MIN := 140.0

## Where the second and third stars sit, between the winning line and the pile
## the level makes when it is pulverised completely.
##
## The third is a third of a pile's height above that pile — three stars means
## taking the building to very near the flattest it can physically be left,
## which makes it demanding on every level by construction rather than by
## tuning. The second sits midway. The first is where the level is won, and is
## set well clear so that bringing a building down is never the hard part.
const THREE_STAR_OVER_PILE := 1.35
const TWO_STAR_SHARE := 0.5
const WIN_LINE_OVER_PILE := 2.4


## Attaches everything that follows from the shape of the building: how much
## material it has, how high its rubble will sit, where the three lines go, and
## how much bar it gets. Authored and generated levels both come through here.
static func finish(spec: Dictionary) -> Dictionary:
	var blocks: Array = spec["blocks"]
	var area := 0.0
	for b in blocks:
		area += float(b["w"]) * float(b["h"])

	var tall := 0.0
	for b in blocks:
		tall = maxf(tall, float(spec["floor_y"]) - (float(b["y"]) - float(b["h"]) * 0.5))

	var pile: float = spec.get("pile", 0.0)
	if pile <= 0.0:
		pile = estimate_pile(blocks, String(spec.get("kind", "")))
		spec["pile"] = pile

	# The third line is what makes three stars hard; the first is where the
	# level is won and must sit clear of it. Both are held under a share of the
	# building's own height so that a wide low building is not already won.
	# Order matters more than either bound. The third line may never fall below
	# the pile the level will make, or three stars is unreachable — measured, a
	# panel block with a 117 px pile had its third line put at 109 by the
	# height cap alone. So the cap applies, and then the pile wins.
	var ceiling: float = maxf(tall * LINE_OVER_HEIGHT, LINE_MIN)
	var third: float = maxf(minf(pile * THREE_STAR_OVER_PILE, ceiling * 0.62),
		pile * 1.05)
	var win: float = clampf(pile * WIN_LINE_OVER_PILE, third * 1.35,
		maxf(ceiling, third * 1.5))
	var second: float = third + (win - third) * TWO_STAR_SHARE
	var floor_y: float = float(spec["floor_y"])
	spec["lines"] = [floor_y - win, floor_y - second, floor_y - third]
	spec["height_line"] = floor_y - win
	spec["power"] = maxf(area * POWER_PER_AREA, POWER_MIN)
	spec["moves"] = int(spec.get("moves", 8))
	return spec


## A curtain-wall office block: steel columns carrying concrete floor slabs,
## with glass glazing the bays between them, and a reinforced concrete core at
## ground level that no budget of jackhammer blows will get through.
##
## The materials are the puzzle. Glass is free to remove and holds nothing up;
## the concrete floors are what stands above the line; the steel columns are
## what actually carries the building, and the most expensive thing to cut. A
## player who reads the structure can tell all of that before touching it.
##
## Checked by partest.gd (every difficulty solvable, not trivial, and its par
## matching what a solution really costs) and waketest.gd — not by eye.
static func tower(storeys: int = 3, columns: int = 5, spacing: float = 86.0,
		cored: bool = true, cores: int = 1) -> Dictionary:
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
	# Which ground-floor columns are reinforced. Spread out rather than
	# adjacent, so a hard level is not one solid block at the bottom.
	var cored_at := {}
	if cored:
		for n in cores:
			cored_at[posmod(core + n * 2, columns)] = true

	for storey in storeys:
		for i in columns:
			var made_of: String = Materials.STEEL
			if storey == 0 and cored_at.has(i):
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
			# The topmost floor is the roof, and gets a parapet and plant on it.
			"role": "roof" if storey == storeys - 1 else "slab",
			"material": Materials.CONCRETE,
		})
		y -= SLAB_H

	# The lines, the bar and the pile are attached by finish(), which every
	# level goes through whether it was authored or generated. A bare tower()
	# is only ever built by harnesses, so it gets sensible defaults for the
	# fields finish() does not set.
	return {
		"centre_x": CENTRE_X,
		"floor_y": FLOOR_Y,
		"blocks": blocks,
		# `moves` is the solver's search depth: how many tool uses it may chain
		# looking for a solution. A player is not a beam search, so the depth
		# allows one more than the search has ever needed.
		"moves": 8,
		"difficulty": MEDIUM,
		"kind": "curtain_wall",
	}
