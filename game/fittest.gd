extends Node2D

## Is any piece of a building built inside another piece?
##
##   godot --headless --fixed-fps 60 --path game res://fittest.tscn
##
## Three separate failures in this project have turned out to be this and
## nothing else: masonry piers built 6 to 14 px inside their joists, a shed's
## courses built inside its pad footings, and a grandstand's rear pads built in
## the middle of its back riser. Each was chased for rounds as a physics
## problem — a material retuned, a tolerance raised, a footing widened — and
## none of those changes could have worked, because the geometry was wrong
## before the simulation started.
##
## What it costs is not obvious from the symptom. The engine resolves the
## overlap by pushing the pieces apart, so the building shudders, settles
## somewhere it was not designed to be, and takes damage doing it. That reads
## exactly like a structure that is too weak.
##
## So it is checked here, once, before physics has a say: no two blocks in a
## generated spec may share area. Touching is the whole point of a building and
## is not overlapping — a deck sits exactly on its riser, and that is zero
## area, not a little bit of it.

## How much shared area is worth reporting at all. A block is thousands of
## square pixels; this is a rounding error, and it exists so that two pieces
## meant to touch cannot fail on the last bit of a float.
const CRUMB := 1.0

const SEEDS := 24

var _worst := 0.0
var _worst_line := ""
var _found: Array[String] = []
var _pairs := 0


func _ready() -> void:
	for system in Architecture.GENERATED:
		for i in SEEDS:
			_check(Generator.generate(4100 + i, system), system, 4100 + i)
	for id in Levels.ORDER:
		_check(Levels.level(String(id)), "authored", 0)
	_report()


func _check(spec: Dictionary, system: String, level_seed: int) -> void:
	var blocks: Array = spec["blocks"]
	var worst_here := 0.0
	var worst_what := ""
	for i in blocks.size():
		for j in range(i + 1, blocks.size()):
			_pairs += 1
			var a: Dictionary = blocks[i]
			var b: Dictionary = blocks[j]
			var over_x: float = minf(float(a["x"]) + float(a["w"]) * 0.5,
					float(b["x"]) + float(b["w"]) * 0.5) \
				- maxf(float(a["x"]) - float(a["w"]) * 0.5,
					float(b["x"]) - float(b["w"]) * 0.5)
			if over_x <= 0.0:
				continue
			var over_y: float = minf(float(a["y"]) + float(a["h"]) * 0.5,
					float(b["y"]) + float(b["h"]) * 0.5) \
				- maxf(float(a["y"]) - float(a["h"]) * 0.5,
					float(b["y"]) - float(b["h"]) * 0.5)
			if over_y <= 0.0:
				continue
			var area := over_x * over_y
			if area <= worst_here:
				continue
			worst_here = area
			worst_what = "%s inside %s by %.1f x %.1f px" % [
				a.get("role", "?"), b.get("role", "?"), over_x, over_y]
	if worst_here <= CRUMB:
		return
	var line := "%-13s seed %d: %s (%.0f sq px)" % [system, level_seed,
		worst_what, worst_here]
	_found.append(line)
	if worst_here > _worst:
		_worst = worst_here
		_worst_line = line


func _report() -> void:
	print("systems checked  : %d" % Architecture.GENERATED.size())
	print("seeds each       : %d" % SEEDS)
	print("pairs compared   : %d" % _pairs)
	print("specs with pieces built into each other : %d" % _found.size())
	if not _found.is_empty():
		print("")
		for line in _found:
			print("  " + line)
		print("")
		print("worst: " + _worst_line)
	print("")
	print("expected : nothing is built inside anything else. Touching is not")
	print("           overlapping — a deck sits on its riser at zero area.")
	print("VERDICT  : %s" % ["FAIL" if not _found.is_empty() else "PASS"])
	get_tree().quit(1 if not _found.is_empty() else 0)
