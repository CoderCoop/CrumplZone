extends Node2D

## What load do pieces really carry standing still, against what they tolerate?
##
##   godot --headless --fixed-fps 60 --path game res://loadtest.tscn
##
## gentest fails a different level every run, always one piece taking one
## point of damage untouched. Before deciding whether that threshold is right,
## the question is why any load is there at all — so this reports the
## distribution rather than a verdict.
##
## For every piece in every shipped level, over the settling window, it keeps
## the worst ratio of summed contact impulse to what the material tolerates at
## rest. A ratio under 1 is a piece comfortably within itself. Just over 1 is a
## piece the model considers overloaded, and how far over says whether that is
## a building genuinely at its limit or a reading that wobbles across a line.

const SETTLE_TICKS := 240
## Only the last stretch counts.
##
## The first version of this sampled the whole window and kept the worst
## reading, which meant it was recording the moment a piece landed and then
## comparing that against the tolerance for a piece standing still. Those are
## the two cases level.gd deliberately tells apart. It reported 27.7% of the
## game over tolerance; almost all of that was pieces arriving, not resting.
const WATCH_FROM := 200

var _level: Level
var _queue: Array = []
var _spec: Dictionary
var _ticks := 0
var _worst := {}
var _rows: Array[String] = []
var _all: Array[float] = []


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	for s in Pack.seeds():
		_queue.append(int(s))
	_start()


func _start() -> void:
	if _queue.is_empty():
		_report()
		return
	var level_seed: int = _queue.pop_front()
	_spec = Levels.by_id(str(level_seed))
	_level.build(_spec)
	_worst = {}
	_ticks = 0


func _physics_process(_delta: float) -> void:
	if _queue.is_empty() and _spec.is_empty():
		return
	_ticks += 1
	_level.tick_settle()
	if _ticks >= WATCH_FROM:
		_sample()
	if _ticks < SETTLE_TICKS:
		return
	_finish()
	_start()


## The same sum level.gd makes, against the same rest tolerance.
func _sample() -> void:
	for body in _level.live_blocks():
		var state := PhysicsServer2D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		# Resting only. A piece still moving is judged by level.gd against the
		# impact tolerance, which is a different and much larger number.
		if body.linear_velocity.length() > 8.0:
			continue
		var load := 0.0
		var contacts := state.get_contact_count()
		for i in contacts:
			load += state.get_contact_impulse(i).length()
		if load <= 0.0:
			continue
		var made_of: String = body.get_meta("material", Materials.CONCRETE)
		# The same effective limit level.gd applies, self-carry included.
		var gravity := float(ProjectSettings.get_setting(
			"physics/2d/default_gravity", 980.0))
		var limit := maxf(Materials.rest_limit(made_of),
			body.mass * gravity / 60.0 * Level.SELF_CARRY)
		var ratio := load / maxf(limit, 0.001)
		var key := body.get_instance_id()
		var seen: Dictionary = _worst.get(key, {})
		if seen.is_empty() or ratio > float(seen["ratio"]):
			_worst[key] = {
				"ratio": ratio, "load": load, "limit": limit,
				"contacts": contacts,
				"what": "%s %s" % [body.get_meta("role", "?"), made_of],
			}


func _finish() -> void:
	var over: Array = []
	for key in _worst:
		var row: Dictionary = _worst[key]
		_all.append(float(row["ratio"]))
		if float(row["ratio"]) > 1.0:
			over.append(row)
	over.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["ratio"]) > float(b["ratio"]))
	if over.is_empty():
		return
	_rows.append("seed %s %-13s %d of %d pieces over tolerance at rest"
		% [_spec.get("seed", "?"), _spec.get("kind", "?"), over.size(),
			_worst.size()])
	for row in over:
		_rows.append("      %-22s %.2fx  load %6.0f  limit %5.0f  %d contacts"
			% [row["what"], row["ratio"], row["load"], row["limit"],
				row["contacts"]])
	_spec = {}


func _report() -> void:
	_all.sort()
	print("")
	for row in _rows:
		print(row)
	print("")
	if _all.is_empty():
		print("no contacts sampled")
		get_tree().quit()
		return
	var over := 0
	for r in _all:
		if r > 1.0:
			over += 1
	print("%d piece-readings, %d over tolerance (%.1f%%)"
		% [_all.size(), over, float(over) * 100.0 / float(_all.size())])
	print("median %.2fx, 90th %.2fx, 99th %.2fx, worst %.2fx" % [
		_all[_all.size() / 2], _all[int(float(_all.size()) * 0.9)],
		_all[int(float(_all.size()) * 0.99)], _all[_all.size() - 1]])
	print("")
	print("measurement only — no verdict")
	get_tree().quit()
