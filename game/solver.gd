class_name Solver
extends Node2D

## Searches a level's move space for a sequence that clears it.
##
## This is what makes the charter's generated levels honest: a level is only
## shipped to a player once a solution has been found by actually playing it,
## and the move budget is that solution's length plus slack.
##
## Tick-driven rather than a blocking loop, because physics only advances on
## physics frames and because the game will eventually want to run this in the
## background without freezing. Call start(), wait for the finished signal.

signal finished(result: Dictionary)

const MAX_TICKS_PER_MOVE := 260
const SETTLE_GRID := 90.0

## How many candidate sequences survive each round. Beam rather than
## exhaustive: the move space is continuous and the point is to establish that
## a solution exists, not to prove one is optimal.
var beam := 2
var max_moves := 5
## Parity-robust verification. The determinism spike found that rebuilding an
## identical scene alternates between two outcomes, so a solution is confirmed
## by replaying it at a second rebuild and requiring both to clear.
var confirm_parity := true
## Minimum room a verified solution must leave between the highest remaining
## point and the line. A solution that clears by a hair is one the rebuild
## parity can flip, so the charter's "verify with margin" gets a number here.
var margin := 10.0
## Print each round's progress. Off by default so the game does not chatter.
var verbose := false

var _spec: Dictionary
var _level: Level
var _candidates: Array = []
var _beam_prefixes: Array = []
var _queue: Array = []
var _results: Array = []
var _round := 0
var _tried := 0

var _sequence: Array = []
var _move_index := 0
var _ticks := 0
var _running := false
var _phase := ""          # "settle_check" | "search" | "confirm"
var _self_collapses := false
var _best_single := -1
var _solution: Array = []
var _confirm_pass := 0
## Cleared candidates from the current round, best margin first. Rejecting the
## whole level because its *best* solution is fragile wastes a level that may
## have a sturdier second-best one, so they are confirmed in order.
var _to_confirm: Array = []
var _reason := ""


func _ready() -> void:
	_level = Level.new()
	add_child(_level)


func start(spec: Dictionary) -> void:
	_spec = spec
	_candidates = _build_candidates(spec)
	_beam_prefixes = [[]]
	_round = 0
	_tried = 0
	_reason = ""
	_self_collapses = false
	_best_single = -1
	_solution = []
	_confirm_pass = 0
	# Before searching, check the structure stands on its own. A generated
	# building that falls over unaided is not a puzzle, and every later result
	# would be measured against a level the player never sees.
	_phase = "settle_check"
	_begin([])


## Candidate moves are drawn from the structure's own bounding box, on a coarse
## grid. Sampling empty sky would waste most of the search.
func _build_candidates(spec: Dictionary) -> Array:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for b in spec["blocks"]:
		min_x = minf(min_x, b["x"])
		max_x = maxf(max_x, b["x"])
		min_y = minf(min_y, b["y"])
		max_y = maxf(max_y, b["y"])

	var points: Array[Vector2] = []
	var x := min_x
	while x <= max_x + 1.0:
		var y := min_y
		while y <= max_y + 1.0:
			points.append(Vector2(x, y))
			y += SETTLE_GRID
		x += SETTLE_GRID

	var out: Array = []
	for kind in Tools.ORDER:
		for point in points:
			out.append({"tool": kind, "at": point})
	return out


func _begin(sequence: Array) -> void:
	_sequence = sequence
	_level.build(_spec)
	_move_index = 0
	_ticks = 0
	_running = true


func _physics_process(_delta: float) -> void:
	if not _running:
		return

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
		_running = false
		_on_settled()
		return
	_ticks += 1


func _on_settled() -> void:
	match _phase:
		"settle_check":
			_self_collapses = _level.cleared()
			if _self_collapses:
				_reason = "structure does not stand up on its own"
				_finish(false)
				return
			_phase = "search"
			_next_round()
		"search":
			_results.append({
				"sequence": _sequence.duplicate(),
				"standing": _level.standing(),
				"clearance": _level.clearance(),
			})
			_tried += 1
			_advance_search()
		"confirm":
			# Replayed at consecutive rebuilds. The determinism spike found an
			# identical scene rebuilt in one process alternates between two
			# outcomes, so a solution has to hold on both, with room to spare
			# rather than by a hair.
			if not _level.cleared() or _level.clearance() < margin:
				if verbose:
					print("    confirmation failed (%d standing, %.0f px) — next candidate"
						% [_level.standing(), _level.clearance()])
				_try_next_confirmation()
				return
			_confirm_pass += 1
			if _confirm_pass >= 2:
				_finish(true)
			else:
				_begin(_solution)


## Takes the next cleared candidate and replays it. When none are left, the
## round produced nothing robust, so keep searching if there is depth left.
func _try_next_confirmation() -> void:
	if _to_confirm.is_empty():
		_solution = []
		if _round >= max_moves:
			_reason = "no solution survived parity confirmation within %d moves" % max_moves
			_finish(false)
			return
		_phase = "search"
		_beam_prefixes = []
		for i in mini(beam, _results.size()):
			_beam_prefixes.append(_results[i]["sequence"])
		_next_round()
		return
	_solution = _to_confirm.pop_front()
	_confirm_pass = 0
	_begin(_solution)


func _next_round() -> void:
	_round += 1
	_results = []
	_queue = []
	for prefix in _beam_prefixes:
		for candidate in _candidates:
			_queue.append(prefix + [candidate])
	_take_next()


func _take_next() -> void:
	if _queue.is_empty():
		_end_round()
		return
	_begin(_queue.pop_front())


func _advance_search() -> void:
	if _queue.is_empty():
		_end_round()
	else:
		_begin(_queue.pop_front())


func _end_round() -> void:
	_results.sort_custom(func(a, b):
		if a["standing"] != b["standing"]:
			return a["standing"] < b["standing"]
		return a["clearance"] > b["clearance"])
	if _results.is_empty():
		_finish(false)
		return

	if _round == 1:
		_best_single = _results[0]["standing"]

	if verbose:
		print("    round %d: %d sequences, best leaves %d standing (%.0f px clearance)"
			% [_round, _results.size(), _results[0]["standing"], _results[0]["clearance"]])

	_to_confirm = []
	for r in _results:
		if r["standing"] == 0 and r["clearance"] >= margin:
			_to_confirm.append(r["sequence"])

	if not _to_confirm.is_empty():
		if not confirm_parity:
			_solution = _to_confirm[0]
			_finish(true)
			return
		_phase = "confirm"
		_try_next_confirmation()
		return

	if _round >= max_moves:
		_reason = "no solution with %.0f px of margin within %d moves" % [margin, max_moves]
		_finish(false)
		return

	_beam_prefixes = []
	for i in mini(beam, _results.size()):
		_beam_prefixes.append(_results[i]["sequence"])
	_next_round()


func _finish(solved: bool) -> void:
	_running = false
	_level.clear()
	finished.emit({
		"solved": solved,
		"solution": _solution.duplicate(),
		"moves_needed": _solution.size(),
		"best_single": _best_single,
		"self_collapses": _self_collapses,
		"sequences_tried": _tried,
		"reason": _reason,
	})
