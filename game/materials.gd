class_name Materials
extends RefCounted

## What things are made of, and how hard they are to break.
##
## Durability is what makes a structure readable before you touch it: glass is
## obviously the weak part, reinforced concrete is obviously not worth your
## moves, and the colours say so without a legend. It is also the difference
## between a level being a shape and being a decision.

const GLASS := "glass"
const BRICK := "brick"
const CONCRETE := "concrete"
const STEEL := "steel"
const REINFORCED := "reinforced"

## `durability` is how much damage a piece absorbs before it comes apart, on a
## scale where one jackhammer blow is Tools.JACKHAMMER_DAMAGE. Read it as hits:
##
## The scale runs 1 to 100, and one jackhammer blow is 12 of it:
##
##   glass        1   one blow, and it was never holding anything up
##   brick       12   one blow
##   concrete    24   two
##   steel       36   three
##   reinforced 100   nine — more than any level's move budget, so in practice
##                    it is the thing you work around rather than through. Two
##                    charges will still do it, which is the point: no piece is
##                    invincible, some are just a terrible use of a move.
##
## `pieces` is how many fragments it makes when it does come apart, and
## `brittle` says how: a brittle material shatters in slivers radiating from
## the point struck, the way a pane of glass does, while everything else parts
## on one or two sloped fracture faces. Nothing is ever deleted.
const SPEC := {
	GLASS: {
		"durability": 1,
		"pieces": 6,
		"brittle": true,
		"colour": Color(0.44, 0.62, 0.71, 0.80),
		"density": 0.0006,
	},
	BRICK: {
		"durability": 12,
		"pieces": 5,
		"brittle": true,
		"colour": Color(0.60, 0.32, 0.26),
		"density": 0.0010,
	},
	CONCRETE: {
		"durability": 24,
		"pieces": 3,
		"colour": Color(0.66, 0.67, 0.69),
		"density": 0.0013,
	},
	STEEL: {
		"durability": 36,
		"pieces": 2,
		"colour": Color(0.40, 0.45, 0.52),
		"density": 0.0016,
	},
	REINFORCED: {
		"durability": 100,
		"pieces": 2,
		"colour": Color(0.52, 0.50, 0.46),
		"density": 0.0019,
	},
}

## How much contact load a piece carries before it starts to suffer, in the
## units the physics engine reports contact impulses in.
##
## Measured, not chosen, and the margin is narrow on purpose. In a settled,
## untouched tower the worst load on a pane is 29; a pane with a floor slab
## resting on it carries 58, and the moment that slab lands it spikes past a
## thousand. A tolerance between 29 and 58 is a pane that holds up a wall
## happily and fails under a floor — which is the point, and there is no wider
## gap available to sit in.
##
## The other materials keep roughly the same ratio to what they carry standing:
## steel columns hold 634 and tolerate 1000, the reinforced core holds 702 and
## tolerates 1400.
##
## There is a second guard under these numbers: stresstest.gd stands the
## building up untouched for six seconds and fails if a single piece so much as
## takes damage. A stress table tuned too low turns every level into one that
## collapses before it is played, and the failure is otherwise silent — the
## solver would just report the level unsolvable.
const STRESS := {
	GLASS: 40.0,
	BRICK: 200.0,
	CONCRETE: 300.0,
	STEEL: 1000.0,
	REINFORCED: 1400.0,
}

## How fast overload turns into damage: three points a second at twice a
## material's tolerance. Calibrated so that the spike from a floor slab landing
## on a pane — 1271 against a tolerance of 90 — takes it out on the blow rather
## than leaving it cracked and standing, which is what a rate of 1 did.
const STRESS_RATE := 3.0

## How much more a piece carries standing still than it survives being hit
## with, as a multiple of its tolerance.
##
## The tolerance above is one number doing two jobs, and it was doing the
## second one badly: the same threshold judged a slab landing on a pane and a
## heap of rubble resting on a floor. Measured over a full collapse, 40% of all
## stress damage was dealt to pieces that were standing still — concrete
## carrying 702-813 against a limit of 300 while moving at under 3 px/s, which
## is a pile that has settled, not a blow.
##
## The split is per material rather than global because it is a real
## difference. Concrete and steel carry a steady load far better than they
## take a shock, so they get a wide margin. Glass does not: a pane under
## sustained weight really does fail, and a pane holding up a floor is
## supposed to crack. Its margin is 1.0 — no change at all.
const REST_TOLERANCE := {
	GLASS: 1.0,
	BRICK: 2.0,
	CONCRETE: 3.0,
	STEEL: 3.0,
	REINFORCED: 3.0,
}

## The speed at which a contact counts as a full-strength impact, in px/s.
##
## Severity rises with the square of speed, because that is how the energy in
## a collision rises. Measured over a full collapse, real impacts land between
## 60 and 400 px/s and account for most of the damage — but a sixth of it was
## being dealt in the 8-25 band, by pieces barely drifting, because tolerance
## used to be a step: anything over 8 px/s was judged exactly as harshly as a
## slab arriving at 400. At 120 as the reference, a 10 px/s nudge is 144 times
## weaker than a real impact rather than equal to one.
const IMPACT_SPEED := 120.0


## How much of a full impact a contact at this speed amounts to, from 0 at
## rest to 1 at IMPACT_SPEED and above.
static func severity(speed: float) -> float:
	var t := clampf(speed / IMPACT_SPEED, 0.0, 1.0)
	return t * t


## And when a resting piece is overloaded past even that, it gives way slowly:
## a quarter of the rate of something being struck. Grossly overloaded rubble
## still fails, which is the point of the mechanism — it just stops grinding
## pieces down for standing there.
const REST_RATE := 0.25


## Tolerance for a piece with nothing moving against it.
static func rest_limit(name: String) -> float:
	return stress_limit(name) * float(REST_TOLERANCE.get(name, 3.0))


static func stress_limit(name: String) -> float:
	return float(STRESS.get(name, STRESS[CONCRETE]))


## Smallest piece worth simulating, as an area. Below twice this a fragment is
## rubble: it still has to end up below the line, but nothing divides it
## further, and a tool that finds only rubble refuses rather than charging a
## move for nothing.
##
## An area rather than a length, because fragments stopped being rectangles —
## a long thin sliver and a small square can have the same width and be worth
## very different amounts of simulation.
const MIN_AREA := 120.0


static func of(name: String) -> Dictionary:
	return SPEC.get(name, SPEC[CONCRETE])


static func durability(name: String) -> int:
	return int(of(name)["durability"])


## How many blows of a given strength a full-strength piece takes. Used by the
## intro screen so the numbers a player is told are the numbers in the game.
static func hits(name: String, per_hit: int) -> int:
	return int(ceil(float(durability(name)) / float(maxi(1, per_hit))))


## Damaged pieces darken as they take damage, so a structure shows its wear
## before it fails and no blow ever reads as nothing happening.
static func colour_at(name: String, wear: float) -> Color:
	var base: Color = of(name)["colour"]
	return base.lerp(Color(0.20, 0.18, 0.17, base.a), clampf(wear, 0.0, 1.0) * 0.55)
