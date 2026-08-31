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
##
## The finding, re-measured on today's buildings: the pile a level is
## estimated to leave is not a bound on the pile it actually leaves. A shed
## estimated at 47 px left 55 on its worst of six runs — the estimate 15%
## under the thing it is supposed to cover — and a house varied between 9 and
## 30 px on the same seed, a spread of 3.5 times.
##
## An earlier note here reported a seven-fold spread on a house and an
## estimate a third of its own worst run. That was measured against a
## different pack and before the house's window sills were moved out of its
## floor joists, and it does not reproduce: re-run twice on today's code, the
## worst spread is 3.5 times. The conclusion survives the numbers changing,
## which is why it is worth keeping — but the numbers are the ones above.
##
## None of this breaks the winning line, which comes from the building's
## height and not from the pile. What it breaks is the assumption behind
## bakelevels' REPEATS: the worst of a handful of samples is not a limit when
## the underlying spread is this wide, so the pile recorded in the pack is a
## number to treat as indicative rather than as a bound.

## Seeds to measure, overridable so that asking a different question does not
## mean editing the harness. A non-numeric argument names a structural system
## and every seed is built as that, which is how a system held back from
## generation can still be measured:
##
##   godot ... res://pilespread.tscn -- 4106 4119
##   godot ... res://pilespread.tscn -- panel 4100 4101 4102
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
var _tall := 0.0
var _lines: Array[String] = []


var _seeds: Array[int] = []
var _system := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			_seeds.append(int(arg))
		else:
			_system = String(arg)
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
	_spec = Generator.generate(_seeds[_seed_at], _system)
	_level.build(_spec)
	_spots = []
	for b in _spec["blocks"]:
		_spots.append(Vector2(float(b["x"]), float(b["y"])))
	# How tall it is before anything touches it. The pile only means something
	# against this: a system whose rubble is most of its own height leaves no
	# room to put a winning line above the pile and still under the roof,
	# which is the whole reason the panel block is held back.
	if _run == 0:
		_tall = _top_now()
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
	var share := 0.0 if _tall <= 0.0 else high / _tall * 100.0
	_lines.append("seed %d %-13s tall %3.0f guessed %3.0f | runs:%s | low %.0f high %.0f mean %.0f | spread %.2fx | guess/worst %.2fx | worst pile is %.0f%% of the building"
		% [_spec["seed"], _spec["kind"], _tall, guessed, each, low, high, mean,
			spread, worst, share])


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
