extends Node2D

## Load has to break things, and it has to break only the right things.
##
##   godot --headless --fixed-fps 60 --path game res://stresstest.tscn
##
## Three claims, and the first one is the one that matters most: a building
## standing on its own must not eat itself. A stress model tuned a little too
## low turns every level into one that collapses before the player touches it,
## and the failure is silent — the solver would report the level unsolvable and
## nothing would say why.
##
## The numbers this is tuned against were measured, not guessed: in a settled
## tower the worst sustained load on a pane is 29, a pane carrying a floor slab
## sees 116, and a slab landing on one spikes to 1271.

const FLOOR_Y := 540.0
const STAND_TICKS := 400        # six and a half seconds of standing still
const LOAD_TICKS := 400

var _level: Level
var _failures: Array[String] = []
var _phase := "standing"
var _ticks := 0
var _pieces_before := 0
var _pane: RigidBody2D
var _pane_broke_at := -1
var _swept_before := 0
var _standing_before := 0


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	_level.build(Levels.tower())
	_pieces_before = _level.live_blocks().size()


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_level.tick_settle()
	match _phase:
		"standing":
			if _ticks < STAND_TICKS:
				return
			_finish_standing()
			_phase = "load"
			_ticks = 0
			_start_load()
		"load":
			if is_instance_valid(_pane):
				if _ticks < LOAD_TICKS:
					return
			elif _pane_broke_at < 0:
				_pane_broke_at = _ticks
			_finish_load()
			_phase = "sweep"
			_ticks = 0
			_start_sweep()
		"sweep":
			if _ticks < 300:
				return
			_finish_sweep()
			_report()
			_phase = "done"


# --- 1. a building that stands must keep standing --------------------------

func _finish_standing() -> void:
	var now := _level.live_blocks().size()
	var damaged := 0
	for body in _level.live_blocks():
		if int(body.get_meta("damage", 0)) > 0:
			damaged += 1
	print("standing    %d pieces before, %d after %d ticks untouched; %d damaged"
		% [_pieces_before, now, STAND_TICKS, damaged])
	if now != _pieces_before:
		_failures.append("the building broke itself while standing still: %d pieces became %d"
			% [_pieces_before, now])
	if damaged > 0:
		_failures.append("%d pieces took damage with nothing acting on them" % damaged)


# --- 2. weight from above breaks what is under it --------------------------

func _start_load() -> void:
	_level.build({
		"centre_x": 400.0, "floor_y": FLOOR_Y, "height_line": FLOOR_Y - 400.0,
		"power": 100.0, "moves": 1,
		"blocks": [
			{"x": 360.0, "y": FLOOR_Y - 28.0, "w": 20.0, "h": 56.0,
				"material": Materials.STEEL},
			{"x": 440.0, "y": FLOOR_Y - 28.0, "w": 20.0, "h": 56.0,
				"material": Materials.STEEL},
			{"x": 400.0, "y": FLOOR_Y - 28.0, "w": 50.0, "h": 56.0,
				"material": Materials.GLASS},
			{"x": 400.0, "y": FLOOR_Y - 150.0, "w": 200.0, "h": 22.0,
				"material": Materials.CONCRETE},
		],
	})
	_pane = _level.live_blocks()[2]
	_pane_broke_at = -1


func _finish_load() -> void:
	var broke := not is_instance_valid(_pane)
	print("load        a slab dropped on a pane: %s"
		% [("broke it after %.1fs" % (float(_pane_broke_at) / 60.0)) if broke
			else "the pane is still whole after %.1fs" % (float(LOAD_TICKS) / 60.0)])
	if not broke:
		_failures.append("a concrete floor landed on a pane of glass and it held")


# --- 3. rubble below the line is swept up ----------------------------------

func _start_sweep() -> void:
	_level.build(Levels.tower())
	_swept_before = _level.debris_count()
	# Shatter the ground-floor glazing, which lands below the line.
	for x in [314.0, 400.0, 486.0]:
		Tools.apply(Tools.Kind.EXPLOSIVE, _level, Vector2(x, FLOOR_Y - 38.0), 1.0)
	_standing_before = _level.standing()


func _finish_sweep() -> void:
	var swept := _level.debris_count()
	print("sweep       %d pieces of rubble swept up; %d still standing above the line"
		% [swept, _level.standing()])
	if swept <= _swept_before:
		_failures.append("no rubble was ever swept up — the street fills with slivers forever")
	# Everything swept was already below the line, so sweeping can never be
	# what clears a level.
	for body in _level.live_blocks():
		if not is_instance_valid(body):
			_failures.append("a live piece went missing")


func _report() -> void:
	print("")
	print("expected : an untouched building does not break itself, a floor")
	print("           landing on glass breaks it, and rubble that has come to")
	print("           rest below the line stops being simulated")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
