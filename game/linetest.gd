extends Node2D

## Does each level's rubble actually fit under its own survey line?
##
##   godot --headless --fixed-fps 60 --path game res://linetest.tscn
##
## Nothing is ever deleted, so the pile a level makes when it is completely
## destroyed has to fit beneath the line it is judged against. A line below
## that pile makes the level unsolvable for reasons no tactics can fix, and the
## symptom — a beam search that plateaus at every depth — reads exactly like a
## level that is merely hard.
##
## The line is computed from the level's material volume and how far it had to
## fall. That formula was calibrated on one building and was wrong for the
## others: on the two-storey level it assumed debris spread nearly as wide as
## on the four-storey one, predicted a thinner pile than the level really
## makes, and put the line underneath it. This measures the pile instead of
## trusting the formula.

const SETTLE := 1500
## Charges are placed on a grid across the building to pulverise it, rather
## than played well: the question is how big the pile is when everything is
## broken, which is the worst case the line has to clear.
const CHARGE_EVERY := 22

var _queue: Array[String] = []
var _level: Level
var _difficulty := ""
var _ticks := 0
var _charge_at := 0
var _spots: Array[Vector2] = []
var _failures: Array[String] = []
var _lines: Array[String] = []


func _ready() -> void:
	_queue = Levels.ORDER.duplicate()
	_level = Level.new()
	add_child(_level)
	_start()


func _start() -> void:
	_difficulty = _queue.pop_front()
	var spec := Levels.level(_difficulty)
	_level.build(spec)
	_ticks = 0
	_charge_at = 0
	_spots = []
	for b in spec["blocks"]:
		_spots.append(Vector2(float(b["x"]), float(b["y"])))


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_level.tick_settle()
	if _ticks % CHARGE_EVERY == 0 and _charge_at < _spots.size():
		Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_charge_at], 1.0)
		_charge_at += 1
	if _ticks < SETTLE + _spots.size() * CHARGE_EVERY:
		return
	_finish()


func _finish() -> void:
	var floor_y: float = float(_level.spec["floor_y"])
	# Judged against the *last* line now, not the first. Three stars means
	# getting everything under the lowest one, so that is the line the level's
	# own rubble has to fit beneath — the others are easier by construction.
	var all := _level.lines()
	var line: float = float(all[all.size() - 1])
	var peak := floor_y
	for body in _level.live_blocks():
		var poly: PackedVector2Array = body.get_meta("poly")
		for point in poly:
			peak = minf(peak, body.global_position.y + point.rotated(body.rotation).y)
	var pile := floor_y - peak
	var allowed := floor_y - line
	_lines.append("%-7s pile %3.0f px, three-star line %3.0f px, %s"
		% [_difficulty, pile, allowed,
			("%.0f px of room" % (allowed - pile)) if allowed >= pile
			else ("%.0f px SHORT" % (pile - allowed))])
	if pile > allowed:
		_failures.append("%s makes a %.0f px pile but three stars needs everything under %.0f px — unreachable"
			% [_difficulty, pile, allowed])
	if _queue.is_empty():
		_report()
		return
	_start()


func _report() -> void:
	print("")
	for line in _lines:
		print(line)
	print("")
	print("expected : three stars is reachable — the pile fits under the last line")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit()
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
