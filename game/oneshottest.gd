extends Node2D

## How low does one charge get a building?
##
##   godot --headless --fixed-fps 60 --path game res://oneshottest.tscn
##
## A level cleared by a single tap is no puzzle, and where the survey line sits
## is what decides that. Hard was cleared by one charge at a line of 235 px and
## again at 175. Rather than guess a third time, this tries a charge at every
## sensible spot on the building and reports how high the best of them leaves
## the rubble — the line has to sit below that number.

const TRIALS_ACROSS := 5
const TRIALS_UP := 4
const SETTLE := 620

var _level: Level
var _spec: Dictionary
var _spots: Array[Vector2] = []
var _at := -1
var _ticks := 0
var _best := 1e9
var _best_spot := Vector2.ZERO
var _difficulty := Levels.HARD


func _ready() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_difficulty = OS.get_cmdline_user_args()[0]
	_level = Level.new()
	add_child(_level)
	_spec = Levels.level(_difficulty)
	var left := 1e9
	var right := -1e9
	var top := 1e9
	for b in _spec["blocks"]:
		left = minf(left, float(b["x"]))
		right = maxf(right, float(b["x"]))
		top = minf(top, float(b["y"]))
	var floor_y: float = float(_spec["floor_y"])
	for ix in TRIALS_ACROSS:
		for iy in TRIALS_UP:
			_spots.append(Vector2(
				lerpf(left, right, float(ix) / float(maxi(TRIALS_ACROSS - 1, 1))),
				lerpf(floor_y - 30.0, top, float(iy) / float(maxi(TRIALS_UP - 1, 1)))))
	_next()


func _next() -> void:
	_at += 1
	if _at >= _spots.size():
		_report()
		return
	_level.build(_spec)
	_ticks = 0


func _physics_process(_delta: float) -> void:
	if _at >= _spots.size():
		return
	_ticks += 1
	_level.tick_settle()
	if _ticks == 20:
		Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_at], 1.0)
	if _ticks < SETTLE:
		return
	var floor_y: float = float(_spec["floor_y"])
	var peak := floor_y
	for body in _level.live_blocks():
		var poly: PackedVector2Array = body.get_meta("poly")
		for point in poly:
			peak = minf(peak, body.global_position.y + point.rotated(body.rotation).y)
	var height := floor_y - peak
	if height < _best:
		_best = height
		_best_spot = _spots[_at]
	_next()


func _report() -> void:
	var line: float = float(_spec["floor_y"]) - float(_spec["height_line"])
	print("%s: %d single charges tried" % [_difficulty, _spots.size()])
	print("the best of them leaves rubble %.0f px high, from (%.0f, %.0f)"
		% [_best, _best_spot.x, _best_spot.y])
	print("the line sits at %.0f px" % line)
	print("")
	print("expected : one charge alone does not get everything under the line")
	var ok := _best > line
	print("actual   : one charge leaves it %.0f px %s the line"
		% [absf(_best - line), "over" if ok else "under"])
	print("VERDICT  : %s" % ["PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
