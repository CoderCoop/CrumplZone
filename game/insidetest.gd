extends Node2D

## Do damage cracks stay inside the piece they belong to?
##
##   godot --headless --fixed-fps 60 --path game res://insidetest.tscn
##
## _crack draws a split running in from an edge, and its comment claims both
## ends lie inside the piece. Only one end was ever checked: the far end was
## placed at a quarter of the piece's reach in an arbitrary direction and never
## tested, and the width was added perpendicular afterwards, which can push a
## corner out through an edge even when both ends are in.
##
## Neither shows up on a square. It shows on the shapes a real demolition
## makes — long slivers and thin wedges, where a quarter of the reach in the
## wrong direction is well outside the piece.
##
## So this shatters real levels, damages every fragment, and checks every
## vertex of every crack against the polygon it is drawn in. No physics ticks:
## the question is geometric.

const LEVELS := 6
const FIRST_SEED := 4100

var _level: Level
var _checked := 0
var _outside := 0
var _worst := 0.0
var _examples: Array[String] = []


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	for i in LEVELS:
		_sweep(Generator.generate(FIRST_SEED + i))
	_report()


## Break the level up, then damage everything left and inspect its cracks.
func _sweep(spec: Dictionary) -> void:
	_level.build(spec)
	var start := _level.live_blocks()
	# Shatter a spread of pieces so the fragments are the real thing: slivers
	# from brittle material, wedges from structural.
	for i in start.size():
		if i % 3 == 0:
			_level.damage(start[i], 200, start[i].global_position)
	for body in _level.live_blocks():
		# Every level of wear, because the number of cracks rises with damage
		# and each one is drawn from a different salt.
		for hits in [1, 3, 9, 26]:
			_level.damage(body, hits, body.global_position)
			_inspect(body)


func _inspect(body: RigidBody2D) -> void:
	if not is_instance_valid(body):
		return
	var poly: PackedVector2Array = body.get_meta("poly")
	if poly.size() < 3:
		return
	for child in body.get_children():
		if not String(child.name).begins_with("crack"):
			continue
		var crack: PackedVector2Array = (child as Polygon2D).polygon
		for point in crack:
			_checked += 1
			if Fracture._contains(poly, point):
				continue
			_outside += 1
			var over := _how_far_out(poly, point)
			_worst = maxf(_worst, over)
			if _examples.size() < 6:
				_examples.append("%s %s: a %s crack corner sits %.1f px outside a %d-sided piece %.0f px across"
					% [body.get_meta("role", "?"), body.get_meta("material", "?"),
						child.name, over, poly.size(), Fracture.reach(poly) * 2.0])


## How far outside the shape a point is, as the deepest it sits beyond any one
## edge. Reported so a near-miss reads differently from a crack drawn in open
## space.
func _how_far_out(poly: PackedVector2Array, point: Vector2) -> float:
	var deepest := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var edge := b - a
		if edge.length() < 0.001:
			continue
		# Positive means outside this edge, for a polygon wound one way; the
		# shape is convex, so the deepest positive is how far out it really is.
		var out := edge.orthogonal().normalized().dot(point - a)
		deepest = maxf(deepest, out)
	return minf(deepest, _how_far_out_other_way(poly, point))


func _how_far_out_other_way(poly: PackedVector2Array, point: Vector2) -> float:
	var deepest := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var edge := b - a
		if edge.length() < 0.001:
			continue
		var out := -edge.orthogonal().normalized().dot(point - a)
		deepest = maxf(deepest, out)
	return deepest


func _report() -> void:
	print("")
	print("checked %d crack corners across %d levels" % [_checked, LEVELS])
	print("outside the piece: %d (%.1f%%), worst %.1f px" % [
		_outside, 0.0 if _checked == 0 else float(_outside) * 100.0 / float(_checked),
		_worst])
	for line in _examples:
		print("  " + line)
	print("")
	print("expected : every corner of every damage crack lies inside the")
	print("           piece it is drawn on")
	if _outside == 0:
		print("VERDICT  : PASS")
		get_tree().quit()
		return
	print("VERDICT  : FAIL")
	get_tree().quit(1)
