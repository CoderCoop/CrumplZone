extends Node2D

## What does each difficulty actually cost to solve?
##
##   godot --headless --fixed-fps 60 --path game res://partest.tscn
##
## Every difficulty has to be solvable, and its bar has to be big enough to
## solve it with. Those are the two ways a level can be born broken and the two
## the solver is the only thing that can answer.
##
## It used to also check par against what a solution costs. Par is gone: the
## rating is drawn on the level as lines now, and the bar is sized from how
## much building there is, so there is no solver-derived number left to drift.

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
	var solved: bool = result["solved"]
	var spent := 0.0
	for move in result.get("solution", []):
		spent += Tools.cost(move["tool"], 1.0)
	var power := float(_spec["power"])
	var best_single: int = result["best_single"]

	_lines.append("%-7s %2d blocks, solved in %s, costing %.0f of a %.0f bar; one use leaves %d standing"
		% [_difficulty, _spec["blocks"].size(),
			("%d uses" % result["moves_needed"]) if solved else "NO SOLUTION",
			spent, power, best_single])

	if not solved:
		_failures.append("%s has no solution within %d uses" % [_difficulty, _spec["moves"]])
	else:
		if spent > power:
			_failures.append("%s cannot be finished inside its own bar (%.0f needed, %.0f given)"
				% [_difficulty, spent, power])
	# Reported, not asserted. For the hard level this field said a single use
	# leaves nothing standing, while simulating a charge at twenty positions on
	# that same level directly — oneshottest.gd — leaves the rubble 390 px
	# high, which is the building very nearly untouched. The two cannot both be
	# right and the disagreement is not explained. The direct simulation is the
	# one that can be read end to end, so that is what gates "is this a
	# puzzle"; this is left visible so the discrepancy is not lost.
	if best_single <= 0:
		_lines.append("        note: the search reports one use clears %s, which"
			% _difficulty)
		_lines.append("        oneshottest contradicts — see the comment in partest.gd")
	# Not straight on to the next level. Solver.finish clears its level with
	# queue_free, which is deferred, so building the next one in this frame
	# puts two levels' worth of bodies in the same physics space — the new
	# building goes up inside the old one's collapsing rubble. That is not a
	# subtle effect: it reported a forty-block tower cleared by a single use,
	# and the same level solvable in one run and unsolvable in the next.
	_solver.queue_free()
	_solver = null
	_cooldown = COOLDOWN
	set_physics_process(true)


## Long enough for every deferred free from the level just finished to land.
const COOLDOWN := 30

var _cooldown := 0


func _physics_process(_delta: float) -> void:
	if _cooldown <= 0:
		return
	_cooldown -= 1
	if _cooldown > 0:
		return
	set_physics_process(false)
	var left := _bodies_left()
	if left > 0:
		_failures.append("%d bodies from the previous level were still in the world"
			% left)
	_next()


## Nothing from the last level may still exist when the next one is built.
func _bodies_left() -> int:
	var count := 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is RigidBody2D:
			count += 1
		for child in node.get_children():
			stack.append(child)
	return count


func _report() -> void:
	print("")
	for line in _lines:
		print(line)
	print("")
	print("expected : every difficulty is solvable inside its own bar")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit()
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
