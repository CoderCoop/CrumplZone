extends Node2D

## What does each difficulty actually cost to solve?
##
##   godot --headless --fixed-fps 60 --path game res://partest.tscn
##
## Par is the whole rating system: three stars is spending close to what the
## best solution costs, so a par that has drifted from what the solver finds
## makes three stars either free or impossible, silently. This measures it for
## every difficulty and fails if the number in levels.gd is out of date.
##
## It also fails a level that cannot be solved at all, or that one use clears —
## the two ways a difficulty can be born broken.

## How far par may drift from the measured cost before it is wrong. Physics
## changes move these by a few power either way; a real drift moves them more.
const TOLERANCE := 0.18

var _queue: Array[String] = []
var _solver: Solver
var _spec: Dictionary
var _difficulty := ""
var _failures: Array[String] = []
var _lines: Array[String] = []


func _ready() -> void:
	_queue = Levels.ORDER.duplicate()
	_next()


func _next() -> void:
	if _queue.is_empty():
		_report()
		return
	_difficulty = _queue.pop_front()
	_spec = Levels.level(_difficulty)
	_solver = Solver.new()
	_solver.max_moves = int(_spec["moves"])
	_solver.finished.connect(_on_finished)
	add_child(_solver)
	_solver.start(_spec)


func _on_finished(result: Dictionary) -> void:
	_solver.queue_free()
	var solved: bool = result["solved"]
	var spent := 0.0
	for move in result.get("solution", []):
		spent += Tools.cost(move["tool"], 1.0)
	var par := float(_spec["par"])
	var power := float(_spec["power"])
	var best_single: int = result["best_single"]
	var drift := 0.0 if par <= 0.0 else absf(spent - par) / par

	_lines.append("%-7s %2d blocks, solved in %s, costing %.0f power (par %.0f, bar %.0f); one use leaves %d standing"
		% [_difficulty, _spec["blocks"].size(),
			("%d uses" % result["moves_needed"]) if solved else "NO SOLUTION",
			spent, par, power, best_single])

	if not solved:
		_failures.append("%s has no solution within %d uses" % [_difficulty, _spec["moves"]])
	else:
		if drift > TOLERANCE:
			_failures.append("%s par is %.0f but a solution costs %.0f (%.0f%% out)"
				% [_difficulty, par, spent, drift * 100.0])
		if spent > power:
			_failures.append("%s cannot be finished inside its own bar (%.0f needed, %.0f given)"
				% [_difficulty, spent, power])
	if best_single <= 0:
		_failures.append("%s is cleared by a single use" % _difficulty)
	_next()


func _report() -> void:
	print("")
	for line in _lines:
		print(line)
	print("")
	print("expected : every difficulty is solvable, not solvable in one use, and")
	print("           its par matches what a solution actually costs")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit()
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
