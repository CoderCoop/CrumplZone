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
## `pieces` is how many fragments it makes when it does come apart — glass
## showers, a concrete slab breaks into slabs. Nothing is ever deleted.
const SPEC := {
	GLASS: {
		"durability": 1,
		"pieces": 4,
		"colour": Color(0.44, 0.62, 0.71, 0.80),
		"density": 0.0006,
	},
	BRICK: {
		"durability": 12,
		"pieces": 4,
		"colour": Color(0.60, 0.32, 0.26),
		"density": 0.0010,
	},
	CONCRETE: {
		"durability": 24,
		"pieces": 2,
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

## Smallest piece worth having. Below this a fragment is rubble: it still has
## to end up below the line, but nothing divides it further, and a tool that
## finds only rubble refuses rather than charging a move for nothing.
const MIN_PIECE := 9.0


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
