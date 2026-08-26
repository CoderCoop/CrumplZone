extends Node2D

## Are generated levels playable, and is the pile estimate safe?
##
##   godot --headless --fixed-fps 60 --path game res://gentest.tscn
##
## A generated level cannot be measured before it is played — the estimate of
## how high its rubble will sit is made at build time with nobody watching, and
## everything about the rating hangs off it. If that estimate comes out below
## what the level really leaves, the lowest line sits inside the rubble and
## three stars is unreachable; far enough below and the level cannot be won at
## all. That is the failure the authored levels hit twice.
##
## So this destroys each sampled level completely and holds up a ruler:
##
##   * it stands up untouched (a level that falls over on its own is cleared
##     before the player arrives)
##   * the estimate is not below the pile the level actually makes
##   * every structural system in architecture.gd is exercised
##
## What it deliberately does not do is search for a solution. That is the
## solver's job and it costs minutes per level; this costs seconds per level
## and catches the things that are cheap to catch.

const SAMPLES := 12
const FIRST_SEED := 4100
const STAND_TICKS := 240
const CHARGE_EVERY := 14
const SETTLE := 900

var _level: Level
var _at := -1
var _spec: Dictionary
var _phase := ""
var _ticks := 0
var _standing_before := 0
var _spots: Array[Vector2] = []
var _charge_at := 0
var _failures: Array[String] = []
var _lines: Array[String] = []
var _seen := {}
var _worst_ratio := 99.0


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	_next()


func _next() -> void:
	_at += 1
	if _at >= SAMPLES:
		_report()
		return
	_spec = Generator.generate(FIRST_SEED + _at)
	_level.build(_spec)
	_seen[_spec["kind"]] = int(_seen.get(_spec["kind"], 0)) + 1
	_standing_before = _level.standing()
	_spots = []
	for b in _spec["blocks"]:
		_spots.append(Vector2(float(b["x"]), float(b["y"])))
	_charge_at = 0
	_ticks = 0
	_phase = "standing"


func _physics_process(_delta: float) -> void:
	if _at >= SAMPLES:
		return
	_ticks += 1
	_level.tick_settle()
	match _phase:
		"standing":
			if _ticks < STAND_TICKS:
				return
			if _level.standing() < _standing_before:
				_failures.append("seed %d (%s) falls down on its own"
					% [_spec["seed"], _spec["kind"]])
			_phase = "flatten"
			_ticks = 0
		"flatten":
			if _ticks % CHARGE_EVERY == 0 and _charge_at < _spots.size():
				Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_charge_at], 1.0)
				_charge_at += 1
			if _ticks < SETTLE + _spots.size() * CHARGE_EVERY:
				return
			_judge()
			_next()


func _judge() -> void:
	var floor_y: float = float(_spec["floor_y"])
	var peak := floor_y
	for body in _level.live_blocks():
		var poly: PackedVector2Array = body.get_meta("poly")
		for point in poly:
			peak = minf(peak, body.global_position.y + point.rotated(body.rotation).y)
	var actual := floor_y - peak
	var guessed: float = float(_spec["pile"])
	var third: float = floor_y - float(_spec["lines"][2])
	var ratio := 99.0 if actual <= 0.0 else guessed / actual
	_worst_ratio = minf(_worst_ratio, ratio)
	# The numbers the estimate is built from, so a bad estimate can be
	# calibrated rather than guessed at again.
	var area := 0.0
	var left := INF
	var right := -INF
	var top := INF
	var bottom := -INF
	for b in _spec["blocks"]:
		area += float(b["w"]) * float(b["h"])
		left = minf(left, float(b["x"]) - float(b["w"]) * 0.5)
		right = maxf(right, float(b["x"]) + float(b["w"]) * 0.5)
		top = minf(top, float(b["y"]) - float(b["h"]) * 0.5)
		bottom = maxf(bottom, float(b["y"]) + float(b["h"]) * 0.5)
	var footprint := right - left
	var tall := bottom - top
	var needed := 0.0 if actual <= 0.0 else area / (actual * Levels.PACKING)
	var implied := 0.0 if tall <= 0.0 else (needed - footprint) * 0.5 / tall
	_lines.append("seed %d %-13s %2d blk  pile %3.0f guessed %3.0f (%.2fx)  foot %4.0f tall %3.0f  spread/height needed %.2f"
		% [_spec["seed"], _spec["kind"], _spec["blocks"].size(), actual, guessed,
			ratio, footprint, tall, implied])
	if guessed < actual:
		_failures.append("seed %d (%s) makes a %.0f px pile but was estimated at %.0f"
			% [_spec["seed"], _spec["kind"], actual, guessed])
	if third < actual:
		_failures.append("seed %d (%s) cannot reach three stars: pile %.0f, line %.0f"
			% [_spec["seed"], _spec["kind"], actual, third])


func _report() -> void:
	print("")
	for line in _lines:
		print(line)
	print("")
	print("systems seen: %s" % _seen)
	print("closest the estimate came to being too low: %.2fx" % _worst_ratio)
	var missing: Array[String] = []
	for kind in Architecture.TYPES:
		if not _seen.has(kind):
			missing.append(kind)
	if not missing.is_empty():
		_lines.append("note: not sampled — %s" % str(missing))
		print("note: these systems were not sampled: %s" % str(missing))
	print("")
	print("expected : generated levels stand up, and the pile estimate is never")
	print("           below what the level really leaves")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit()
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
