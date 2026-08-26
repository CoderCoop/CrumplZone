extends Node2D

## Does every piece's collision shape match the shape that is drawn?
##
##   godot --headless --fixed-fps 60 --path game res://hulltest.tscn
##
## Pieces are convex polygons and the physics uses ConvexPolygonShape2D, which
## quietly substitutes the convex hull when it is handed something concave.
## When that happens the collider is bigger than the piece on screen, so rubble
## rests on empty air and a shard blocks something it does not touch. Godot
## says so, but only as a warning among thousands of lines of solver output.
##
## Fracture cuts convex pieces with half-planes, so every fragment ought to be
## convex by construction. Repeated cutting leaves nearly-collinear vertices,
## and that is where it stops being true.

const SETTLE := 900
const CHARGE_EVERY := 20

var _level: Level
var _ticks := 0
var _charge_at := 0
var _spots: Array[Vector2] = []
var _checked := 0
var _concave := 0
var _worst := 0.0
var _seen := {}
var _flat := 0
var _dupe := 0
var _area_gap := 0.0


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	var spec := Levels.level(Levels.HARD)
	_level.build(spec)
	for b in spec["blocks"]:
		_spots.append(Vector2(float(b["x"]), float(b["y"])))


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_level.tick_settle()
	if _ticks % CHARGE_EVERY == 0 and _charge_at < _spots.size():
		Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_charge_at], 1.0)
		_charge_at += 1
	# Checked as they appear rather than at the end: the warning fires when a
	# piece is made, and a piece that is concave for two seconds and then
	# broken again never reaches a check that only looks at survivors.
	_scan()
	if _ticks < SETTLE + _spots.size() * CHARGE_EVERY:
		return
	_report()


func _scan() -> void:
	for body in _level.live_blocks():
		var id := body.get_instance_id()
		if _seen.has(id):
			continue
		_seen[id] = true
		var poly: PackedVector2Array = body.get_meta("poly")
		if poly.size() < 3:
			continue
		_checked += 1
		# The same test the engine makes: walking the outline, every turn has
		# to go the same way. A count of vertices against the convex hull's is
		# not the same question and misses the case that matters.
		var turn := 0.0
		var bad := false
		var flat := false
		var dupe := false
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var c := poly[(i + 2) % poly.size()]
			if a.distance_to(b) < 0.01:
				dupe = true
			var cross := (b - a).cross(c - b)
			if absf(cross) < 0.0001:
				flat = true
				continue
			if turn == 0.0:
				turn = signf(cross)
			elif signf(cross) != turn:
				bad = true
				_worst = maxf(_worst, absf(cross))
		if bad:
			_concave += 1
		if flat:
			_flat += 1
		if dupe:
			_dupe += 1
		# Does the hull the engine would substitute differ in area from the
		# shape being drawn? That is what decides whether this matters.
		var hull := Geometry2D.convex_hull(poly)
		var area := Fracture.area(poly)
		var hull_area := Fracture.area(hull)
		if area > 0.0:
			_area_gap = maxf(_area_gap, absf(hull_area - area) / area)
func _report() -> void:
	print("pieces checked            : %d" % _checked)
	print("whose collider is not the drawn shape : %d" % _concave)
	print("worst turn against the winding        : %.4f" % _worst)
	print("pieces with a collinear vertex        : %d" % _flat)
	print("pieces with a repeated vertex         : %d" % _dupe)
	print("largest area the hull would add       : %.4f%%" % (_area_gap * 100.0))
	print("")
	print("")
	print("expected : the shape drawn and the shape collided with are the same,")
	print("           and no piece carries a vertex that is not a corner")
	var bad := _concave > 0 or _dupe > 0
	print("VERDICT  : %s" % ["FAIL" if bad else "PASS"])
	get_tree().quit(1 if bad else 0)
