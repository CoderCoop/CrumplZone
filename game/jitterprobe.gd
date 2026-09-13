extends Node2D

## What is still moving after a collapse has come to rest, and what is it?
##
##   godot --headless --fixed-fps 60 --path game res://jitterprobe.tscn
##
## Reported from playing: small pieces vibrate quickly once everything has
## fallen. There is a candidate in the numbers before anything is measured —
## the game calls a piece at rest below SETTLE_SPEED, 6 px/s, and Godot will
## not let a body sleep until it is under sleep_threshold_linear, 2 px/s, for
## time_before_sleep, half a second. A piece oscillating between those two is
## settled as far as the game is concerned and permanently awake as far as the
## engine is concerned, which is the exact shape of "everything has stopped
## but that bit is still buzzing".
##
## That is a candidate and not a diagnosis, so this measures rather than
## assumes. Each level is flattened, watched until tick_settle() reports rest,
## and then watched for a further window: how many bodies are still awake,
## how fast they are going, and how big they are. Three questions come out of
## it — is it everything or a few, is it the 2-to-6 band, and is it the
## slivers.
##
## Not a gate. It prints a distribution so a fix can be aimed.

const CHARGE_EVERY := 14
const SETTLE := 900
## How long to keep watching after the level says it is at rest. Five seconds:
## long enough that anything still moving is not on its way somewhere.
const WATCH := 300

var _level: Level
var _at := -1
var _spec: Dictionary
var _phase := ""
var _ticks := 0
var _spots: Array[Vector2] = []
var _charge_at := 0
var _watched := 0
var _samples: Array = []
var _levels_done := 0
var _never_slept := 0
var _bodies_seen := 0
var _rested := false
var _rested_count := 0
var _timed_out := 0
var _from_unsettled := 0


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	_next()


func _next() -> void:
	_at += 1
	if _at >= Pack.seeds().size():
		_report()
		return
	_spec = Generator.generate(int(Pack.seeds()[_at]))
	_level.build(_spec)
	_spots = []
	for b in _spec["blocks"]:
		_spots.append(Vector2(float(b["x"]), float(b["y"])))
	_charge_at = 0
	_ticks = 0
	_watched = 0
	_phase = "flatten"


func _physics_process(_delta: float) -> void:
	if _phase == "":
		return
	_ticks += 1
	var at_rest: bool = _level.tick_settle()
	match _phase:
		"flatten":
			if _ticks % CHARGE_EVERY == 0 and _charge_at < _spots.size():
				Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_charge_at], 1.0)
				_charge_at += 1
			if _charge_at < _spots.size():
				return
			# Rest as the game defines it, or a ceiling so one restless level
			# cannot stall the whole run. Which of the two it was is recorded,
			# because a level that never settled is still collapsing and
			# anything measured on it is the collapse, not jitter — without
			# this the two are indistinguishable in the numbers.
			if not at_rest and _ticks < SETTLE + _spots.size() * CHARGE_EVERY:
				return
			_rested = at_rest
			if at_rest:
				_rested_count += 1
			else:
				_timed_out += 1
			_phase = "watching"
			_watched = 0
		"watching":
			_watched += 1
			# Sampled at the end of the window rather than throughout, so
			# what is recorded is the steady state and not the tail of the
			# collapse.
			if _watched < WATCH:
				return
			for body in _level.live_blocks():
				_bodies_seen += 1
				if body.sleeping:
					continue
				_never_slept += 1
				if not _rested:
					_from_unsettled += 1
					continue
				_samples.append({
					"speed": body.linear_velocity.length(),
					"spin": absf(body.angular_velocity),
					"area": Fracture.area(body.get_meta("poly")),
					"material": String(body.get_meta("material", "?")),
				})
			_levels_done += 1
			_phase = ""
			_next()


func _report() -> void:
	print("")
	print("%d levels flattened: %d reached rest, %d hit the ceiling still moving"
		% [_levels_done, _rested_count, _timed_out])
	print("%d pieces in all, %d still awake %d frames later"
		% [_bodies_seen, _never_slept, WATCH])
	print("%d of those are on levels that never settled — still collapsing,"
		% _from_unsettled)
	print("not jitter, and not counted below")
	if _samples.is_empty():
		print("")
		print("Nothing is awake. Either this does not reproduce the report or")
		print("the jitter is somewhere this harness does not look.")
		get_tree().quit(0)
		return

	var bands := {"under 2 (would sleep)": 0, "2 to 6 (the gap)": 0,
		"6 to 20": 0, "over 20 (still falling)": 0}
	var small := 0
	var small_awake_area := 0.0
	var spin_only := 0
	for s in _samples:
		var v: float = s["speed"]
		if v < 2.0:
			bands["under 2 (would sleep)"] += 1
		elif v < 6.0:
			bands["2 to 6 (the gap)"] += 1
		elif v < 20.0:
			bands["6 to 20"] += 1
		else:
			bands["over 20 (still falling)"] += 1
		if v < 2.0 and float(s["spin"]) > 0.14:
			spin_only += 1
		if float(s["area"]) < Materials.MIN_AREA * 4.0:
			small += 1
			small_awake_area += float(s["area"])
	print("")
	print("how fast the awake ones are going:")
	for band in bands:
		print("  %-26s %4d  (%2.0f%%)"
			% [band, bands[band], 100.0 * float(bands[band]) / float(_samples.size())])
	print("")
	print("  under the linear threshold but over the angular one: %d" % spin_only)
	print("  (those are awake because they are turning, not moving)")
	print("")
	var areas: Array = []
	for s in _samples:
		areas.append(float(s["area"]))
	areas.sort()
	print("size of the awake ones: smallest %.0f, median %.0f, largest %.0f px²"
		% [areas[0], areas[areas.size() / 2], areas[areas.size() - 1]])
	print("  under %.0f px² (four times the fracture floor): %d of %d"
		% [Materials.MIN_AREA * 4.0, small, _samples.size()])
	print("")
	print("Read it like this. A tall '2 to 6' band is the gap between what the")
	print("game calls at rest and what the engine will let sleep. A high count")
	print("of small pieces is slivers, which have almost no rotational inertia")
	print("and a two-point contact. A tall 'under 2' with spin is a piece kept")
	print("awake by the angular threshold alone.")
	get_tree().quit(0)
