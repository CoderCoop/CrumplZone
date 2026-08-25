extends Node2D

## Is the hand-built level still worth playing?
##
##   godot --headless --fixed-fps 60 --path game res://playtest.tscn
##
## Three questions a designer answers by eye and gets wrong. Can one use of one
## tool clear it — in which case the budget is decoration? Is it solvable at
## all within the search depth? And does the solution fit in the power bar the
## player is given?
##
## The solver works in full-strength uses, which is the most expensive way to
## play: a player who taps rather than holds, or chips with the jackhammer,
## buys more uses out of the same bar. So a solution that fits at full strength
## fits, full stop.
##
## The search is Solver, the same one that verifies generated levels, rather
## than a second implementation living here. That is not only less code: the
## greedy search this used to carry kept a single best prefix, so it walked
## into dead ends and reported a level unsolvable at seven moves that it had
## solved at five. A beam, a margin and parity confirmation are exactly the
## things that stop that, and they were already written.

var _solver: Solver
var _spec: Dictionary
var _budget := 0
var _started_ms := 0


func _ready() -> void:
	_spec = Levels.tower()
	_budget = _spec["moves"]
	_solver = Solver.new()
	_solver.max_moves = _budget
	_solver.verbose = true
	_solver.finished.connect(_on_finished)
	add_child(_solver)
	print("playtest: %d blocks, depth %d, power %.0f"
		% [_spec["blocks"].size(), _budget, float(_spec["power"])])
	_started_ms = Time.get_ticks_msec()
	_solver.start(_spec)


func _on_finished(result: Dictionary) -> void:
	var elapsed := (Time.get_ticks_msec() - _started_ms) / 1000.0
	var total: int = _spec["blocks"].size()
	var solvable: bool = result["solved"]
	var best_single: int = result["best_single"]

	# What the solution would cost a player, at the most expensive way to play.
	var spent := 0.0
	for move in result.get("solution", []):
		spent += Tools.cost(move["tool"], 1.0)
	var power: float = float(_spec["power"])

	print("")
	print("blocks                 : %d" % total)
	print("search depth           : %d uses" % _budget)
	print("power bar              : %.0f" % power)
	print("best single use leaves : %d of %d above the line" % [best_single, total])
	print("sequences simulated    : %d in %.0fs" % [result["sequences_tried"], elapsed])
	print("")

	# A budget nobody has to spend is decoration.
	var not_trivial := best_single > 0
	var affordable := solvable and spent <= power
	print("expected : a solution exists within %d uses and fits in %.0f power," % [_budget, power])
	print("           and one use does not clear it")
	print("actual   : %s; one use leaves %d standing"
		% [("solved in %d uses costing %.0f power" % [result["moves_needed"], spent])
			if solvable else ("no solution — " + str(result["reason"])), best_single])
	print("%s  solvable within the search depth" % ("PASS" if solvable else "FAIL"))
	print("%s  the solution fits in the power bar" % ("PASS" if affordable else "FAIL"))
	print("%s  not clearable in one use" % ("PASS" if not_trivial else "FAIL"))

	if not solvable:
		print("note     : beam search, not exhaustive — a solution may exist that it")
		print("           did not reach")

	var ok := solvable and affordable and not_trivial
	print("VERDICT  : %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
