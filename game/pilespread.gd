extends Node2D

## How much does the same level's pile vary between runs?
##
##   godot --headless --fixed-fps 60 --path game res://pilespread.tscn
##
## gentest guesses each level's pile at build time and fails if the guess
## comes in under what the level really leaves, with a safety factor to cover
## the difference. That factor was chosen, not measured — and one panel seed
## came back 114 px on one run and 159 on another, which is wider than the
## factor allows and would have failed the gate on the unlucky ordering.
##
## Physics here does not reproduce across a long multi-charge collapse; that
## is known and the solver already works around it. What was never measured is
## how wide the spread actually is, which is the number the safety factor
## should be sized from.
##
## So this flattens the same seeds over and over and reports the spread. It is
## a measurement, not a gate: it prints what it found and always exits 0, so
## nobody is tempted to tune against it until the number is understood.

## Seeds to measure, overridable so that asking a different question does not
## mean editing the harness:
##
##   godot --headless --fixed-fps 60 --path game res://pilespread.tscn -- 4106 4119
const SEEDS: Array[int] = [4106, 4102, 4110]
const REPEATS := 6
const STAND_TICKS := 240
const CHARGE_EVERY := 14
const SETTLE := 900

var _level: Level
var _spec: Dictionary
var _seed_at := -1
var _run := 0
var _phase := ""
var _ticks := 0
var _charge_at := 0
var _spots: Array[Vector2] = []
var _runs: Array[float] = []
var _lines: Array[String] = []


var _seeds: Array[int] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			_seeds.append(int(arg))
	if _seeds.is_empty():
		_seeds = SEEDS.duplicate()
	_level = Level.new()
	add_child(_level)
	_next_seed()


func _next_seed() -> void:
	_seed_at += 1
	if _seed_at >= _seeds.size():
		_report()
		return
	_runs = []
	_run = 0
	_start()


func _start() -> void:
	# Rebuilt from the seed every run, so each repeat starts from exactly the
	# state a player would meet and nothing carries over from the last one.
	_spec = Generator.generate(_seeds[_seed_at])
	_level.build(_spec)
	_spots = []
	for b in _spec["blocks"]:
		_spots.append(Vector2(float(b["x"]), float(b["y"])))
	_charge_at = 0
	_ticks = 0
	_phase = "standing"


func _physics_process(_delta: float) -> void:
	if _seed_at >= _seeds.size():
		return
	_ticks += 1
	_level.tick_settle()
	match _phase:
		"standing":
			if _ticks < STAND_TICKS:
				return
			_phase = "flatten"
			_ticks = 0
		"flatten":
			if _ticks % CHARGE_EVERY == 0 and _charge_at < _spots.size():
				Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_charge_at], 1.0)
				_charge_at += 1
			if _ticks < SETTLE + _spots.size() * CHARGE_EVERY:
				return
			_runs.append(_top_now())
			_run += 1
			if _run < REPEATS:
				_start()
			else:
				_finish_seed()
				_next_seed()


func _top_now() -> float:
	var floor_y: float = float(_spec["floor_y"])
	var peak := floor_y
	for body in _level.live_blocks():
		var poly: PackedVector2Array = body.get_meta("poly")
		for point in poly:
			peak = minf(peak, body.global_position.y + point.rotated(body.rotation).y)
	return floor_y - peak


func _finish_seed() -> void:
	var low := INF
	var high := -INF
	var total := 0.0
	for v in _runs:
		low = minf(low, v)
		high = maxf(high, v)
		total += v
	var mean := total / float(_runs.size())
	var guessed: float = float(_spec["pile"])
	# The spread as a multiple of the smallest run, which is the shape the
	# safety factor has to cover: the estimate is made once and has to be
	# above whatever the worst run leaves.
	var spread := 99.0 if low <= 0.0 else high / low
	var worst := 99.0 if high <= 0.0 else guessed / high
	var each := ""
	for v in _runs:
		each += " %.0f" % v
	_lines.append("seed %d %-13s guessed %3.0f | runs:%s | low %.0f high %.0f mean %.0f | spread %.2fx | guess/worst %.2fx"
		% [_spec["seed"], _spec["kind"], guessed, each, low, high, mean, spread, worst])


func _report() -> void:
	print("")
	for line in _lines:
		print(line)
	print("")
	print("%d repeats of each seed. 'spread' is the highest pile over the" % REPEATS)
	print("lowest for one level; 'guess/worst' is how much room the estimate")
	print("had against the worst run it saw. Under 1.00 would have failed the")
	print("gate on that ordering.")
	print("")
	print("measurement only — this prints what it found and does not judge it")
	get_tree().quit()
