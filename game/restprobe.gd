extends Node2D

## How long after a demolition does a level actually come to rest, against the
## fixed budget the bake waits out? Measurement only.

const CHARGE_EVERY := 14
const BUDGET := 900

var _level: Level
var _spec: Dictionary
var _queue: Array = []
var _ticks := 0
var _charge_at := 0
var _spots: Array[Vector2] = []
var _rested_at := -1
var _lines: Array[String] = []
var _saved := 0
var _total := 0


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	for id in Pack.seeds():
		_queue.append(int(id))
	_start()


func _start() -> void:
	_spec = Generator.generate(int(_queue[0]), Pack.system_for(int(_queue[0])))
	_level.build(_spec)
	_spots = []
	for b in _spec["blocks"]:
		_spots.append(Vector2(float(b["x"]), float(b["y"])))
	_charge_at = 0
	_ticks = 0
	_rested_at = -1


func _physics_process(_delta: float) -> void:
	_ticks += 1
	var rested: bool = _level.tick_settle()
	if _ticks % CHARGE_EVERY == 0 and _charge_at < _spots.size():
		Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_charge_at], 1.0)
		_charge_at += 1
		return
	# Only meaningful once every charge has gone in.
	if _charge_at < _spots.size():
		return
	if rested and _rested_at < 0:
		_rested_at = _ticks
	var budget: int = BUDGET + _spots.size() * CHARGE_EVERY
	if _ticks < budget:
		return
	var at: int = _rested_at if _rested_at > 0 else budget
	_lines.append("seed %-5d %-13s %3d blocks | rest at %5d of %5d ticks | %3.0f%% wasted"
		% [_spec["seed"], _spec["kind"], _spots.size(), at, budget,
			float(budget - at) / float(budget) * 100.0])
	_total += budget
	_saved += budget - at
	_queue.pop_front()
	if _queue.is_empty():
		_report()
		return
	_start()


func _report() -> void:
	print("")
	for line in _lines:
		print(line)
	print("")
	print("total budget %d ticks, %d of them after everything had stopped (%.0f%%)"
		% [_total, _saved, float(_saved) / float(_total) * 100.0])
	print("measurement only")
	get_tree().quit()
