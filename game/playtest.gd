extends Node2D

## Is the hand-built level still worth playing?
##
##   godot --headless --fixed-fps 60 --path game res://playtest.tscn
##
## Two questions a designer answers by eye and gets wrong. Can one move clear
## it — in which case the move budget is decoration? And is it solvable at all
## within that budget?
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
	print("playtest: %d blocks, %d moves" % [_spec["blocks"].size(), _budget])
	_started_ms = Time.get_ticks_msec()
	_solver.start(_spec)


func _on_finished(result: Dictionary) -> void:
	var elapsed := (Time.get_ticks_msec() - _started_ms) / 1000.0
	var total: int = _spec["blocks"].size()
	var solvable: bool = result["solved"]
	var best_single: int = result["best_single"]

	print("")
	print("blocks                 : %d" % total)
	print("move budget            : %d" % _budget)
	print("best single move leaves: %d of %d above the line" % [best_single, total])
	print("sequences simulated    : %d in %.0fs" % [result["sequences_tried"], elapsed])
	print("")

	# A budget nobody has to spend is decoration.
	var not_trivial := best_single > 0
	print("expected : a solution exists within %d moves, and one move does not clear it"
		% _budget)
	print("actual   : %s; one move leaves %d standing"
		% [("solved in %d moves" % result["moves_needed"]) if solvable
			else ("no solution — " + str(result["reason"])), best_single])
	print("%s  solvable within budget" % ("PASS" if solvable else "FAIL"))
	print("%s  not clearable in one move" % ("PASS" if not_trivial else "FAIL"))

	if not solvable:
		print("note     : beam search, not exhaustive — a solution may exist that it")
		print("           did not reach")

	var ok := solvable and not_trivial
	print("VERDICT  : %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
