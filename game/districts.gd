class_name Districts
extends RefCounted

## The city the levels are in.
##
## A district is a place with a character: which kinds of building stand there,
## what the sky over it looks like, and where it sits on the map. It is what
## turns a list of seeds into somewhere — a player picks the works or the
## waterfront, not level fourteen.
##
## A level's district follows from what kind of building it is, because that is
## the honest relationship: chimneys and sheds are in the works because that is
## where those get built. Nothing is placed by hand.

const DOWNTOWN := "downtown"
const RESIDENTIAL := "residential"
const STRIP := "strip"
const HIGHWAY := "highway"
const WATERFRONT := "waterfront"
const WORKS := "works"
const STADIUM := "stadium"

## Where each district sits on the model, in a space running 0..1 both ways,
## and what it is called. The layout reads like a city rather than a grid: the
## waterfront along one edge, the highway cutting across, downtown at the
## centre with everything else around it.
##
## These are plan coordinates on the board, not screen fractions. citymap.gd
## projects them obliquely, so (0, 0) is the far corner and (1, 1) the near
## one; a district's screen position is not its "at" scaled up.
const PLACES := {
	WATERFRONT: {
		"title": "Waterfront", "at": Vector2(0.20, 0.46),
		"about": "warehouses and a chimney, on the water",
	},
	DOWNTOWN: {
		"title": "Downtown", "at": Vector2(0.52, 0.34),
		"about": "offices and car parks, packed tight",
	},
	WORKS: {
		"title": "The Works", "at": Vector2(0.82, 0.20),
		"about": "sheds and stacks, long and low",
	},
	HIGHWAY: {
		"title": "Interchange", "at": Vector2(0.30, 0.58),
		"about": "spans on piers, tied to nothing",
	},
	STRIP: {
		"title": "Retail Park", "at": Vector2(0.74, 0.60),
		"about": "shopfronts, and very little else",
	},
	RESIDENTIAL: {
		"title": "Old Town", "at": Vector2(0.24, 0.84),
		"about": "brick houses, two up and two down",
	},
	STADIUM: {
		"title": "The Ground", "at": Vector2(0.70, 0.86),
		"about": "a raked terrace under a reaching roof",
	},
}

## Which district a kind of building belongs to. Systems held back from
## generation are listed too, so that re-enabling one puts it somewhere
## instead of leaving it homeless.
const HOME := {
	Architecture.CURTAIN_WALL: DOWNTOWN,
	Architecture.FLAT_SLAB: DOWNTOWN,
	Architecture.HOUSE: RESIDENTIAL,
	Architecture.PANEL: RESIDENTIAL,
	Architecture.RETAIL: STRIP,
	Architecture.OVERPASS: HIGHWAY,
	Architecture.MASONRY: WATERFRONT,
	Architecture.STACK: WATERFRONT,
	Architecture.SHED: WORKS,
	Architecture.STAND: STADIUM,
}

## The backdrop each district is seen against — one each, not one shared
## between three. Seven districts once shared four settings, so the Retail Park
## and the Old Town were seen against the same sky and the Interchange against
## downtown's; a district you cannot tell apart from another is not a place.
##
## Every name here has to exist in Backdrop.SETTINGS. A name that does not is
## not an error: it falls back to downtown and the level simply looks wrong
## somewhere nobody is looking, which is what skytest.gd is for.
const SKY := {
	DOWNTOWN: "downtown",
	RESIDENTIAL: "estate",
	STRIP: "strip",
	HIGHWAY: "highway",
	WATERFRONT: "waterfront",
	WORKS: "works",
	STADIUM: "stadium",
}


static func of_system(system: String) -> String:
	return String(HOME.get(system, DOWNTOWN))


static func title(district: String) -> String:
	return String(PLACES.get(district, {}).get("title", "Somewhere"))


static func about(district: String) -> String:
	return String(PLACES.get(district, {}).get("about", ""))


static func at(district: String) -> Vector2:
	return PLACES.get(district, {}).get("at", Vector2(0.5, 0.5)) as Vector2


## The districts that actually have levels in them, in map order. A district
## with nothing in it is not drawn: three systems are held back at any time
## and an empty pin on the map is a promise the game does not keep.
static func inhabited() -> Array:
	var seen := {}
	for id in Levels.all_ids():
		seen[Levels.district_of(String(id))] = true
	var found: Array = []
	for name in PLACES:
		if seen.has(name):
			found.append(name)
	return found
