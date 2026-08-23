extends Node2D

## Generates levels, verifies each by solving it, and reports what the process
## actually costs.
##
##   godot --headless --fixed-fps 60 --path game res://verify_levels.tscn
##
## Two questions. Does generate-and-verify produce playable levels at a useful
## rate — or does the generator mostly emit rubbish the solver has to reject?
## And how long does verifying one take, which decides whether it can happen
## while a player waits or has to run in the background.

const FIRST_SEED := 1000
const DEFAULT_LEVELS := 8
const MAX_MOVES := 5
const SLACK := 2

## How many levels to verify. Override for a quicker look:
##   godot --headless --fixed-fps 60 --path game res://verify_levels.tscn -- 3
var levels := DEFAULT_LEVELS

var _solver: Solver
var _seed := FIRST_SEED
var _done := 0
var _accepted: Array = []
var _rejected: Array = []
var _started_ms := 0
var _level_started_ms := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		levels = maxi(1, args[0].to_int())

	_solver = Solver.new()
	_solver.max_moves = MAX_MOVES
	_solver.verbose = false
	_solver.finished.connect(_on_finished)
	add_child(_solver)
	_started_ms = Time.get_ticks_msec()
	print("verifying %d generated levels, budget %d moves\n" % [levels, MAX_MOVES])
	_next()


func _next() -> void:
	if _done >= levels:
		_report()
		return
	_level_started_ms = Time.get_ticks_msec()
	_solver.start(Generator.generate(_seed))


func _on_finished(result: Dictionary) -> void:
	var elapsed := Time.get_ticks_msec() - _level_started_ms
	var record := {
		"seed": _seed,
		"ms": elapsed,
		"tried": result["sequences_tried"],
		"moves_needed": result["moves_needed"],
		"best_single": result["best_single"],
	}

	var reason := ""
	if not result["solved"]:
		reason = result["reason"]
	elif result["best_single"] == 0:
		reason = "clearable in one move"

	if reason == "":
		record["budget"] = result["moves_needed"] + SLACK
		_accepted.append(record)
		print("seed %d  ACCEPT  solved in %d, budget %d, %d above line after best single move  (%d seqs, %.1fs)"
			% [_seed, result["moves_needed"], record["budget"], result["best_single"],
				result["sequences_tried"], elapsed / 1000.0])
	else:
		record["reason"] = reason
		_rejected.append(record)
		print("seed %d  REJECT  %s  (%d seqs, %.1fs)"
			% [_seed, reason, result["sequences_tried"], elapsed / 1000.0])

	_seed += 1
	_done += 1
	_next()


func _report() -> void:
	var total_ms := Time.get_ticks_msec() - _started_ms
	var accept_rate := float(_accepted.size()) / float(levels)

	var moves_total := 0
	var slowest := 0
	for r in _accepted:
		moves_total += int(r["moves_needed"])
	for r in _accepted + _rejected:
		slowest = maxi(slowest, int(r["ms"]))

	print("")
	print("generated            : %d" % levels)
	print("accepted             : %d (%.0f%%)" % [_accepted.size(), accept_rate * 100.0])
	print("rejected             : %d" % _rejected.size())
	for r in _rejected:
		print("    seed %d — %s" % [r["seed"], r["reason"]])
	if not _accepted.is_empty():
		print("mean solution length : %.1f moves" % (float(moves_total) / _accepted.size()))
	print("mean time per level  : %.1fs" % (total_ms / 1000.0 / levels))
	print("slowest level        : %.1fs" % (slowest / 1000.0))
	print("")

	# The bar is deliberately low. This is asking whether the approach works at
	# all, not whether it is tuned — a generator that produced one playable
	# level in ten would still prove the pipeline while being useless.
	var usable := accept_rate >= 0.5
	print("expected : at least half of generated levels are playable")
	print("actual   : %.0f%% accepted" % (accept_rate * 100.0))
	print("%s  generator produces playable levels" % ("PASS" if usable else "FAIL"))
	print("VERDICT  : %s" % ("PASS" if usable else "FAIL"))

	# Said plainly because it decides the next design step rather than this one.
	if slowest > 3000:
		print("note     : slowest verification took %.1fs — too slow to run while a"
			% (slowest / 1000.0))
		print("           player waits, so generation has to happen in the background")

	get_tree().quit(0 if usable else 1)
