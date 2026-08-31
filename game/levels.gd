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

## Padding on the whole estimate, on top of the per-system spreads.
##
## Those spreads were calibrated against buildings that have since changed —
## masonry grew a lintel course, the car park lost a ramp — and the moment they
## did, three seeds produced more rubble than they were estimated to, the worst
## by a fifth. Chasing the constants each time the architecture moves is a
## losing game, and being wrong the other way only makes a level easier.
const ESTIMATE_SAFETY := 1.35
const PACKING := 0.62
const LINE_MIN := 90.0


## Headroom over a measured pile.
##
## Measuring did not remove the need for this, and finding that out is what
## the first bake was worth. The bake flattens each level several times and
## keeps the worst, and five of eleven seeds still went on to leave more than
## that in the very next run — seed 4109 by 35%, 54 px recorded against 73 px
## produced. The distribution has a tail that a handful of samples does not
## reach.
##
## So the margin stays, but it is now a measured one rather than a modelled
## one, and that is the whole difference. It pads an accurate number by a
## factor taken from the observed spread (1.21x to 1.46x between the best and
## worst run of a seed, and up to 1.35x beyond the bake's worst), instead of
## padding a per-system guess whose own error nobody had ever quantified.
## How much clearance over the measured pile a level ought to have before it
## is comfortable rather than merely possible. A warning threshold, not a
## multiplier: it is reported, never applied to a line. Sized from the
## overshoot the first bake missed — five of eleven seeds left more than the
## worst of three runs, the largest by 35%.
const MEASURED_MARGIN := 1.35


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
		return LINE_MIN * 0.42
	var height: float = maxf(bottom - top, 1.0)
	var per_height: float = float(SPREAD_PER_HEIGHT.get(kind, SPREAD_DEFAULT))
	var spread: float = maxf(right - left, 1.0) + height * per_height * 2.0
	return area / (spread * PACKING) * ESTIMATE_SAFETY


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


## Every level the game can offer, in the order it offers them: the three
## authored ones, then the generated ones the bake measured and kept.
##
## Generated levels were built, verified and gated for a while without being
## reachable from anywhere in the game — the pack existed and no player could
## play any of it. One list, and one way to ask for a level by name, is what
## closed that gap.
static func all_ids() -> Array:
	var ids: Array = ORDER.duplicate()
	for level_seed in Pack.seeds():
		ids.append(str(level_seed))
	return ids


## A level by id: one of the authored difficulties, or the seed of a generated
## one written as a string. Everything downstream takes a finished spec and
## cannot tell which kind it was handed, which is the point.
static func by_id(id: String) -> Dictionary:
	if id.is_valid_int():
		# The system comes from the pack, not from the seed, so the game
		# builds the building the bake measured.
		return Generator.generate(id.to_int(), Pack.system_for(id.to_int()))
	return level(id)


## What to call a level in a list. Generated ones are numbered from one in
## pack order, because a seed is not a name a player can use.
static func title_for(id: String) -> String:
	if not id.is_valid_int():
		return TITLES.get(id, "Level")
	var at := Pack.seeds().find(id.to_int())
	return "%d" % (at + 1) if at >= 0 else id


static func level(difficulty: String) -> Dictionary:
	match difficulty:
		EASY:
			return finish(_placed(tower(3, 4, 86.0, false), difficulty, 8))
		HARD:
			return finish(_placed(tower(4, 5, 84.0, true, 2), difficulty, 10))
		_:
			return finish(_placed(tower(3, 5, 86.0, true), difficulty, 8))


static func _placed(spec: Dictionary, difficulty: String, depth: int) -> Dictionary:
	var measured := Pack.for_level(difficulty)
	if measured >= 0.0:
		spec["pile"] = measured
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
## What share of the power bar a run may spend and still earn each star.
##
## Against the bar rather than against par, and that is a retreat from
## something better that did not survive being measured.
##
## Par — what the cheapest clearing the solver can find costs — is the right
## thing to rate against in principle, because it means the same on every
## level. The bake measured it, and the numbers said not to trust it: the
## medium authored level priced at 238 while the harder one priced at 104,
## which is not a thing that can be true, and the search found no clearing at
## all for six of twelve generated levels at depth five — levels gentest has
## separately shown are winnable, their rubble fitting under their line. A
## par that is too high hands out three stars; one that is too low makes them
## impossible. Rating against a number wrong in both directions is worse than
## rating against a cruder one that is right.
##
## The bar is sized from the building's own material, so a share of it is at
## least proportionate to what is there to knock down. That is the honest
## claim for it, and it is weaker than par's: two levels are comparable only
## as far as their bars are.
##
## What would fix this is a search that clears every level and finds a route
## worth calling best. Until there is one, this is measured against something
## real rather than something invented.
const THREE_STAR_SHARE := 0.34
const TWO_STAR_SHARE := 0.62


## How many stars a finished run earned: what it spent against the bar it was
## given.
static func stars(spent: float, bar: float) -> int:
	if bar <= 0.0:
		return 1
	var share := spent / bar
	if share <= THREE_STAR_SHARE:
		return 3
	if share <= TWO_STAR_SHARE:
		return 2
	return 1


## Attaches everything that follows from the shape of the building: how much
## material it has, how high its rubble will sit, where its winning line goes,
## and how much bar it gets. Authored and generated levels both come through
## here.
static func finish(spec: Dictionary) -> Dictionary:
	var blocks: Array = spec["blocks"]
	var area := 0.0
	for b in blocks:
		area += float(b["w"]) * float(b["h"])

	var tall := 0.0
	for b in blocks:
		tall = maxf(tall, float(spec["floor_y"]) - (float(b["y"]) - float(b["h"]) * 0.5))

	# A measured pile if one was baked for this level, and the estimate only
	# when there is not. The two are not equivalent and the difference is the
	# point: a measurement is what the level really leaves, and needs no
	# safety factor, so nothing pads the winning line. See pack.gd.
	# Presence decides, not the value: zero is a real measurement — a chimney
	# can be left with nothing above the street — and testing `pile <= 0`
	# quietly put exactly that level back on the estimate.
	var pile: float = 0.0
	if spec.has("pile"):
		# The pack records what was measured, unpadded, so it stays a record
		# of fact. The headroom is applied here, in one visible place.
		pile = float(spec["pile"])
		spec["pile_measured"] = true
	else:
		pile = estimate_pile(blocks, String(spec.get("kind", "")))
		spec["pile"] = pile
		spec["pile_measured"] = false

	# The third line is what makes three stars hard; the first is where the
	# level is won and must sit clear of it. Both are held under a share of the
	# building's own height so that a wide low building is not already won.
	# Order matters more than either bound. The third line may never fall below
	# the pile the level will make, or three stars is unreachable — measured, a
	# panel block with a 117 px pile had its third line put at 109 by the
	# height cap alone. So the cap applies, and then the pile wins.
	# One line, and it is a fact about the building: how far down its own
	# height it has been brought. It does not depend on the rubble.
	#
	# It used to. The pile scaled it, and the pile is a number that must never
	# come in low — so every pixel of caution pushed the winning line up,
	# toward a level already won on arrival. Measuring the piles did not fix
	# that either: at a 1.5x margin on a measured pile the hard level's line
	# moved 204 to 239 and one charge cleared it.
	#
	# There were three lines here for a while, and the rating was how many of
	# them everything got under. That is gone. The rating is what the run
	# cost, so the only line that matters is the one that says the building is
	# down.
	var win: float = maxf(tall * LINE_OVER_HEIGHT, LINE_MIN)
	var floor_y: float = float(spec["floor_y"])
	spec["height_line"] = floor_y - win
	# Fit to ship, judged against what the level really leaves. A winning line
	# below the achievable pile is a level nobody can finish, and the bake
	# drops such a level rather than shipping it. Only a measured level can be
	# judged — an estimated one is marked fit because there is nothing
	# trustworthy to judge it against, which is itself a reason to bake every
	# level.
	spec["reachable"] = true
	spec["headroom"] = 0.0
	if bool(spec.get("pile_measured", false)):
		spec["reachable"] = win >= pile
		spec["headroom"] = 99.0 if pile <= 0.0 else win / pile
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
