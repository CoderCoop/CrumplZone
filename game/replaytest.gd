extends Node2D

## Does the same level, rebuilt, break into the same pieces?
##
##   godot --headless --fixed-fps 60 --path game res://replaytest.tscn
##
## Note what this does *not* claim, and what it used to claim wrongly.
##
## Exact replay does not hold: the physics diverges across a multi-move
## collapse, which is why the solver confirms a candidate rather than trusting
## one run. This first tried to assert that a whole collapse produced the same
## number of pieces, which sounds like fracture geometry but is not — how many
## pieces a collapse makes depends on which pieces took enough damage to
## shatter, and that depends on the physics that is known to diverge. It passed
## while collapses were mild and started failing the moment the explosive got
## stronger and more pieces sat near their thresholds. A test that holds only
## while nothing is near a threshold is not testing what it says.
##
## What is guaranteed, and what broke once, is narrower: a given piece with a
## given seed breaks into the same fragments every time. That is pure geometry
## with no physics in it. It was broken by a counter feeding each piece's seed
## that reset with the Level object rather than with the level, so every
## rebuild broke the same building differently and the solver was comparing
## runs that differed for reasons unrelated to the moves.

## How many pieces to shatter and compare. One is enough to catch the bug; a
## handful catches it wherever in the build order it happens to sit.
const SAMPLES := 6

var _level: Level
var _first: Array = []
var _again: Array = []


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	_first = _shatter_pass()
	_again = _shatter_pass()
	_report()


## Builds the level fresh and shatters the same pieces, recording the exact
## fragments each one produced. No ticks are run: nothing here touches the
## physics, so anything that differs between two passes is the seed.
func _shatter_pass() -> Array:
	_level.build(Levels.level(Levels.MEDIUM))
	var out: Array = []
	for i in SAMPLES:
		var live := _level.live_blocks()
		if live.is_empty():
			break
		var body: RigidBody2D = live[(i * 3) % live.size()]
		var at := body.global_position
		_level.shatter(body, at)
		# What came out, as shapes rather than as a count.
		var shapes: Array = []
		for piece in _level.live_blocks():
			if piece.global_position.distance_to(at) < 90.0:
				var poly: PackedVector2Array = piece.get_meta("poly")
				shapes.append("%d:%.2f" % [poly.size(), Fracture.area(poly)])
		shapes.sort()
		out.append(",".join(shapes))
	return out


func _report() -> void:
	var same := _first == _again
	for i in mini(_first.size(), 3):
		print("piece %d  first: %s" % [i, _first[i].substr(0, 60)])
		print("         again: %s" % _again[i].substr(0, 60))
	print("")
	print("expected : a given piece with a given seed breaks into the same")
	print("           fragments every time, with no physics involved")
	print("VERDICT  : %s" % ["PASS" if same else "FAIL"])
	get_tree().quit(0 if same else 1)
