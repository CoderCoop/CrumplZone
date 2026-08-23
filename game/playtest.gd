extends Node2D

## Headless difficulty check for a hand-built level.
##
##   godot --headless --fixed-fps 60 --path game res://playtest.tscn
##
## Answers two questions a designer would otherwise answer by eye and get
## wrong. Is the level too easy — can one move clear it? And is it solvable
## at all within its move budget?
##
## It works by brute force: build the level, apply a candidate move, simulate
## to rest, count what is still above the line, repeat. Greedy from the best
## first move outward. That is a crude version of the solver the charter's
## generate-and-verify needs, run against a hand-built level instead of a
## generated one, and it lives here so the same seam gets exercised early.

const MAX_TICKS_PER_MOVE := 260
const GRID_X: Array[float] = [232.0, 300.0, 366.0, 400.0, 434.0, 500.0, 568.0]
const GRID_Y: Array[float] = [520.0, 440.0, 350.0, 260.0, 180.0]

var _level: Level
var _spec: Dictionary
var _budget := 0

var _candidates: Array = []      # every (tool, position) worth trying
var _prefix: Array = []          # the best sequence found so far
var _queue: Array = []           # sequences still to evaluate this round
var _results: Array = []         # {sequence, standing} for this round
var _round := 1

var _sequence: Array = []
var _move_index := 0
var _ticks := 0
var _running := false
var _solution: Array = []
var _best_single := -1


func _ready() -> void:
	_spec = Levels.tower()
	_budget = _spec["moves"]
	_level = Level.new()
	add_child(_level)

	for kind in Tools.ORDER:
		for x in GRID_X:
			for y in GRID_Y:
				_candidates.append({"tool": kind, "at": Vector2(x, y)})

	print("playtest: %d blocks, %d moves, %d candidate moves per round"
		% [_spec["blocks"].size(), _budget, _candidates.size()])
	_begin_round()


func _begin_round() -> void:
	_queue = []
	_results = []
	for candidate in _candidates:
		_queue.append(_prefix + [candidate])
	_next_sequence()


func _next_sequence() -> void:
	if _queue.is_empty():
		_finish_round()
		return
	_sequence = _queue.pop_front()
	_level.build(_spec)
	_move_index = 0
	_ticks = 0
	_running = true


func _physics_process(_delta: float) -> void:
	if not _running:
		return

	# Apply the next move as soon as the world is at rest, so every candidate
	# is judged from a settled structure the way a player would meet it.
	if _move_index < _sequence.size():
		if _ticks == 0 or _level.tick_settle() or _ticks >= MAX_TICKS_PER_MOVE:
			var move: Dictionary = _sequence[_move_index]
			Tools.apply(move["tool"], _level, move["at"])
			_move_index += 1
			_level.reset_settle()
			_ticks = 0
			return
		_ticks += 1
		return

	if _level.tick_settle() or _ticks >= MAX_TICKS_PER_MOVE:
		_results.append({"sequence": _sequence.duplicate(), "standing": _level.standing()})
		_running = false
		_next_sequence()
		return
	_ticks += 1


func _finish_round() -> void:
	_results.sort_custom(func(a, b): return a["standing"] < b["standing"])
	var best: Dictionary = _results[0]

	if _round == 1:
		_best_single = best["standing"]

	print("round %d (%d moves): best leaves %d block%s above the line — %s"
		% [_round, _round, best["standing"], "" if best["standing"] == 1 else "s",
			_describe(best["sequence"])])

	if best["standing"] == 0:
		_solution = best["sequence"]
		_report()
		return

	if _round >= _budget:
		_report()
		return

	_prefix = best["sequence"]
	_round += 1
	_begin_round()


func _describe(sequence: Array) -> String:
	var parts: Array[String] = []
	for move in sequence:
		parts.append("%s@(%d,%d)" % [Tools.NAMES[move["tool"]], move["at"].x, move["at"].y])
	return " → ".join(parts)


func _report() -> void:
	var total: int = _spec["blocks"].size()
	print("")
	print("blocks                 : %d" % total)
	print("move budget            : %d" % _budget)
	print("best single move leaves: %d of %d above the line" % [_best_single, total])

	var solvable := not _solution.is_empty()
	var length := _solution.size() if solvable else 0

	# Too easy: the budget is decorative if one move ends it.
	var not_trivial := _best_single > 0
	print("")
	print("expected : one move does not clear it, and a solution exists within %d moves" % _budget)
	print("actual   : one move leaves %d standing; %s"
		% [_best_single,
			("solved in %d moves — %s" % [length, _describe(_solution)]) if solvable
			else "no solution found by greedy search"])
	print("%s  not clearable in one move" % ("PASS" if not_trivial else "FAIL"))
	print("%s  solvable within budget" % ("PASS" if solvable else "FAIL"))

	# Greedy is not exhaustive: failing to find a solution means this search
	# did not find one, not that none exists. Said out loud so a red result is
	# read correctly.
	if not solvable:
		print("note     : greedy search only — a solution may exist that it did not reach")

	print("VERDICT  : %s" % ("PASS" if (not_trivial and solvable) else "FAIL"))
	get_tree().quit(0 if (not_trivial and solvable) else 1)
