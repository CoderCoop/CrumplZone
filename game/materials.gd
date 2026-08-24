class_name Materials
extends RefCounted

## What things are made of, and how hard they are to break.
##
## Durability is what makes a structure readable before you touch it: glass is
## obviously the weak part, steel is obviously the expensive one, and the
## colours say so without a legend. It is also the difference between a level
## being a shape and being a decision.

const GLASS := "glass"
const BRICK := "brick"
const CONCRETE := "concrete"
const STEEL := "steel"

## `integrity` is how much damage a piece absorbs before it comes apart.
## `pieces` is how many fragments it makes when it does — glass showers, a
## concrete slab breaks into slabs.
const SPEC := {
	GLASS: {
		"integrity": 1,
		"pieces": 4,
		"colour": Color(0.44, 0.62, 0.71, 0.80),
		"density": 0.0006,
	},
	BRICK: {
		"integrity": 2,
		"pieces": 4,
		"colour": Color(0.60, 0.32, 0.26),
		"density": 0.0010,
	},
	CONCRETE: {
		"integrity": 2,
		"pieces": 2,
		"colour": Color(0.66, 0.67, 0.69),
		"density": 0.0013,
	},
	STEEL: {
		"integrity": 3,
		"pieces": 2,
		"colour": Color(0.40, 0.45, 0.52),
		"density": 0.0016,
	},
}

## Smallest piece worth having. Below this a fragment is rubble: it still has
## to end up below the line, but nothing divides it further.
const MIN_PIECE := 14.0


static func of(name: String) -> Dictionary:
	return SPEC.get(name, SPEC[CONCRETE])


## Damaged pieces darken, so a structure shows its wear before it fails. Fully
## intact reads as the material's own colour.
static func colour_at(name: String, integrity_left: int) -> Color:
	var spec := of(name)
	var base: Color = spec["colour"]
	var full: int = spec["integrity"]
	if integrity_left >= full:
		return base
	var wear := 1.0 - float(integrity_left) / float(maxi(1, full))
	return base.lerp(Color(0.20, 0.18, 0.17, base.a), wear * 0.55)
