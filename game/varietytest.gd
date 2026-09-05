extends Node2D

## Is a generated building more than a repeating grid?
##
##   godot --headless --fixed-fps 60 --path game res://varietytest.tscn
##
## The generator varies a lot between buildings — system, era, setting, size —
## and almost nothing within one. Ten curtain-wall seeds were ten copies of
## the same regular frame at different scales: every bay the same width, every
## storey the same height, the whole thing mirror-symmetric about its middle.
## That reads as a placeholder rather than as a building, and it is flat as a
## puzzle too, because every bay of a regular frame is worth the same to cut.
##
## Two properties, both cheap and both structural rather than cosmetic:
##
##   SYMMETRY  the building is not a mirror image of itself. A real one is
##             not, and a symmetric one has no answer to "which side?" — the
##             question a demolition is mostly about.
##   RANKS     where four or more of the same member stand in a row, they are
##             not evenly spaced. Even spacing is what makes a frame read as
##             repeated units, and an uneven one puts the long span — the
##             weak one — somewhere the player has to find.
##
## Exemptions are per system and each carries its reason. A blanket threshold
## would let a system pass by adding one decorative offset lump, which is the
## opposite of the point.

## How much two numbers may differ and still count as the same. Blocks are
## placed from floats; this is a rounding error, not a tolerance for sloppy
## geometry.
const CRUMB := 0.5

## How many members make a rank worth judging. Three is a pier at each end and
## one in the middle, which is not a repeating unit yet.
const RANK := 4

const SEEDS := 24

## What each system must exhibit, and why anything is let off.
const REQUIRED := {
	Architecture.CURTAIN_WALL: ["symmetry", "ranks"],
	# Uneven openings were built and taken out again: they cost five seeds in
	# sixteen and no explanation for it survived measurement. See the note
	# above _masonry in architecture.gd, which keeps the numbers so the next
	# attempt starts from evidence. This exemption is a debt, not a decision.
	Architecture.MASONRY: [],
	Architecture.FLAT_SLAB: ["symmetry", "ranks"],
	Architecture.RETAIL: ["symmetry", "ranks"],
	Architecture.OVERPASS: ["symmetry", "ranks"],
	Architecture.SHED: ["symmetry", "ranks"],
	# A house is two cross walls and a middle pier: there is no rank of four
	# anything to be regular about. Its asymmetry comes from the chimney.
	Architecture.HOUSE: ["symmetry"],
	# A terrace's treads are the same depth the whole way up — that is what
	# makes it a terrace rather than a staircase. Its asymmetry is the roof.
	Architecture.STAND: ["symmetry"],
	# A chimney is a solid of revolution. A lopsided one is a mistake, not
	# variety, and its courses are a rank of two.
	Architecture.STACK: [],
}

var _failures: Array[String] = []
var _checked := 0


func _ready() -> void:
	for system in Architecture.GENERATED:
		var want: Array = REQUIRED.get(system, [])
		if want.is_empty():
			print("%-14s exempt" % system)
			continue
		var symmetric := 0
		var regular := 0
		var ranks_seen := 0
		for i in SEEDS:
			var spec := Generator.generate(4100 + i, system)
			var blocks: Array = spec["blocks"]
			_checked += 1
			if want.has("symmetry") and _mirrors_itself(blocks):
				symmetric += 1
			if want.has("ranks"):
				var found := _widest_rank(blocks)
				if not found.is_empty():
					ranks_seen += 1
					if _evenly_spaced(found):
						regular += 1
		if want.has("symmetry"):
			print("%-14s %d of %d seeds mirror-symmetric" % [system, symmetric, SEEDS])
			if symmetric > 0:
				_failures.append("%s: %d of %d seeds are a mirror image of themselves"
					% [system, symmetric, SEEDS])
		if want.has("ranks"):
			print("%-14s %d of %d seeds evenly spaced (%d had a rank of %d+)"
				% [system, regular, SEEDS, ranks_seen, RANK])
			if ranks_seen == 0:
				_failures.append(("%s: no rank of %d members to judge, so the "
					+ "spacing check never ran — this table is wrong about it")
					% [system, RANK])
			elif regular > 0:
				_failures.append("%s: %d of %d seeds are an evenly spaced grid"
					% [system, regular, SEEDS])
	_report()


## Is the building a mirror image of itself about its own middle?
func _mirrors_itself(blocks: Array) -> bool:
	var left := INF
	var right := -INF
	for b in blocks:
		left = minf(left, float(b["x"]) - float(b["w"]) * 0.5)
		right = maxf(right, float(b["x"]) + float(b["w"]) * 0.5)
	var middle: float = (left + right) * 0.5
	for b in blocks:
		if not _has_twin(blocks, middle * 2.0 - float(b["x"]), b):
			return false
	return true


func _has_twin(blocks: Array, at: float, like: Dictionary) -> bool:
	for other in blocks:
		if absf(float(other["x"]) - at) > CRUMB:
			continue
		if absf(float(other["y"]) - float(like["y"])) > CRUMB:
			continue
		if absf(float(other["w"]) - float(like["w"])) > CRUMB:
			continue
		if absf(float(other["h"]) - float(like["h"])) > CRUMB:
			continue
		return true
	return false


## The largest row of same-role members standing at the same height — a
## frame's columns, a warehouse's piers, a shed's stanchions.
func _widest_rank(blocks: Array) -> Array[float]:
	var ranks := {}
	for b in blocks:
		var key: String = "%s@%d" % [b.get("role", ""), int(round(float(b["y"])))]
		if not ranks.has(key):
			ranks[key] = [] as Array[float]
		ranks[key].append(float(b["x"]))
	var best: Array[float] = []
	for key in ranks:
		var row: Array[float] = ranks[key]
		if row.size() >= RANK and row.size() > best.size():
			best = row
	best.sort()
	return best


## Are the gaps between them all the same?
func _evenly_spaced(row: Array[float]) -> bool:
	var least := INF
	var most := -INF
	for i in range(1, row.size()):
		var gap: float = row[i] - row[i - 1]
		least = minf(least, gap)
		most = maxf(most, gap)
	return most - least <= CRUMB


func _report() -> void:
	print("")
	print("%d buildings measured" % _checked)
	if _failures.is_empty():
		print("every system varies within a building as well as between them")
		get_tree().quit(0)
		return
	for line in _failures:
		print("  " + line)
	print("A building that repeats one unit across and one storey up is a")
	print("grid, not architecture — and every bay of it is worth the same to")
	print("cut, which is a puzzle with one move in it repeated.")
	get_tree().quit(1)
