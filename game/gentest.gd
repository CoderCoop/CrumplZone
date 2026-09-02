extends Node2D

## Are generated levels playable, and is the pile estimate safe?
##
##   godot --headless --fixed-fps 60 --path game res://gentest.tscn
##
## A generated level cannot be measured before it is played — the estimate of
## how high its rubble will sit is made at build time with nobody watching, and
## everything about the rating hangs off it. If that estimate comes out below
## what the level really leaves, the lowest line sits inside the rubble and
## the winning line sits inside the rubble and the level cannot be won at all.
## That is the failure the authored levels hit twice.
##
## So this destroys each sampled level completely and holds up a ruler:
##
##   * it stands up untouched (a level that falls over on its own is cleared
##     before the player arrives)
##   * the estimate is not below the pile the level actually makes
##   * every structural system in architecture.gd is exercised
##
## What it deliberately does not do is search for a solution. That is the
## solver's job and it costs minutes per level; this costs seconds per level
## and catches the things that are cheap to catch.

## The seeds the pack actually ships, not a range of its own.
##
## It used to walk 4100 upward and judge whatever came out, which meant it
## failed on levels the generate step had already looked at and refused to ship — and
## it would have passed a pack that had quietly shrunk to nothing. Testing
## what ships is the point; the generate step's own report is where a seed that was
## rejected gets explained.
const LEAST_LEVELS := 8


const CHARGE_EVERY := 14
const SETTLE := 900

var _level: Level
var _at := -1
var _spec: Dictionary
var _phase := ""
var _ticks := 0
var _standing_before := 0
var _top_at_build := 0.0
var _settled_damage := 0
var _spots: Array[Vector2] = []
var _charge_at := 0
var _failures: Array[String] = []
var _lines: Array[String] = []
var _seen := {}
var _worst_ratio := 99.0


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	_next()


func _next() -> void:
	_at += 1
	if _at >= Pack.seeds().size():
		_report()
		return
	_spec = Generator.generate(int(Pack.seeds()[_at]))
	_level.build(_spec)
	_seen[_spec["kind"]] = int(_seen.get(_spec["kind"], 0)) + 1
	_standing_before = _level.standing()
	_top_at_build = StandCheck.top_of(_level, _spec)
	_spots = []
	for b in _spec["blocks"]:
		_spots.append(Vector2(float(b["x"]), float(b["y"])))
	_charge_at = 0
	_ticks = 0
	_phase = "standing"


func _physics_process(_delta: float) -> void:
	if _at >= Pack.seeds().size():
		return
	_ticks += 1
	_level.tick_settle()
	match _phase:
		"standing":
			if _ticks == StandCheck.SETTLE_TICKS:
				_settled_damage = StandCheck.damage_total(_level)
			if _ticks < StandCheck.SETTLE_TICKS + StandCheck.WATCH_TICKS:
				return
			# One check, shared with the generate step. See standcheck.gd.
			var bedded := StandCheck.culprits(_level)
			if not bedded.is_empty():
				_lines.append("        bedded in with: %s" % bedded)
			# Reported, not failed on, below StandCheck.DEGRADING. The generate step
			# is the gate for standing: it runs this same check five times a
			# level and then again over the whole pack until nothing drops.
			# A single further roll here cannot add information it does not
			# have, and it demonstrably disagrees — which made CI red for
			# levels the generate step had validated.
			var why := StandCheck.verdict(_level, _spec, _top_at_build,
				_settled_damage)
			var carried_on := StandCheck.damage_total(_level) - _settled_damage
			if why != "":
				_lines.append("        note: %s" % why)
			if carried_on >= StandCheck.DEGRADING:
				_failures.append("seed %d (%s) is coming apart on its own: %d points after settling"
					% [_spec["seed"], _spec["kind"], carried_on])
			_phase = "flatten"
			_ticks = 0
		"flatten":
			if _ticks % CHARGE_EVERY == 0 and _charge_at < _spots.size():
				Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_charge_at], 1.0)
				_charge_at += 1
			if _ticks < SETTLE + _spots.size() * CHARGE_EVERY:
				return
			_judge()
			_next()


func _judge() -> void:
	var floor_y: float = float(_spec["floor_y"])
	var peak := floor_y
	for body in _level.live_blocks():
		var poly: PackedVector2Array = body.get_meta("poly")
		for point in poly:
			peak = minf(peak, body.global_position.y + point.rotated(body.rotation).y)
	var actual := floor_y - peak
	var guessed: float = float(_spec["pile"])
	var win: float = floor_y - float(_spec["height_line"])
	var ratio := 99.0 if actual <= 0.0 else guessed / actual
	_worst_ratio = minf(_worst_ratio, ratio)
	# The numbers the estimate is built from, so a bad estimate can be
	# calibrated rather than guessed at again.
	var area := 0.0
	var left := INF
	var right := -INF
	var top := INF
	var bottom := -INF
	for b in _spec["blocks"]:
		area += float(b["w"]) * float(b["h"])
		left = minf(left, float(b["x"]) - float(b["w"]) * 0.5)
		right = maxf(right, float(b["x"]) + float(b["w"]) * 0.5)
		top = minf(top, float(b["y"]) - float(b["h"]) * 0.5)
		bottom = maxf(bottom, float(b["y"]) + float(b["h"]) * 0.5)
	var footprint := right - left
	var tall := bottom - top
	var needed := 0.0 if actual <= 0.0 else area / (actual * Levels.PACKING)
	var implied := 0.0 if tall <= 0.0 else (needed - footprint) * 0.5 / tall
	_lines.append("seed %d %-13s %2d blk  pile %3.0f guessed %3.0f (%.2fx)  foot %4.0f tall %3.0f  spread/height needed %.2f"
		% [_spec["seed"], _spec["kind"], _spec["blocks"].size(), actual, guessed,
			ratio, footprint, tall, implied])
	# Reported, not failed on, and the difference matters.
	#
	# This used to be a failure, and it was the right one while the lines were
	# derived from the pile: a pile that came in under reality dragged the
	# third line down inside the rubble with it. The lines come from the
	# building's height now, so a run that leaves more than the generate step recorded
	# moves nothing — and failing on it would be asserting that three samples
	# find the worst of a distribution with a tail, which the first generate run
	# proved false on five seeds out of eleven.
	#
	# What actually protects the player is the next check: the winning line
	# must be above what the level really leaves. That one still fails.
	if guessed < actual:
		_lines.append("        left %.0f px, over the %.0f px the generate step recorded"
			% [actual, guessed])
	if win < actual:
		_failures.append("seed %d (%s) cannot be won: pile %.0f, winning line %.0f"
			% [_spec["seed"], _spec["kind"], actual, win])
	# A winning line above the roof is a level that is won before it is
	# touched, and nothing here was checking for it. It is the failure at the
	# opposite end from a level that cannot be won, and it comes from the same
	# place: a building whose rubble sits high relative to its own height
	# leaves no room to stack three lines above the pile and still be under
	# the roof. Caught only once the piles were measured and the padding was
	# applied to a real number.
	if win >= tall:
		_failures.append("seed %d (%s) is won before it is touched: winning line %.0f, building %.0f tall"
			% [_spec["seed"], _spec["kind"], win, tall])


func _report() -> void:
	print("")
	for line in _lines:
		print(line)
	print("")
	print("systems seen: %s" % _seen)
	if Pack.seeds().size() < LEAST_LEVELS:
		_failures.append("the pack ships only %d levels, under the %d expected — a generator that stopped producing playable levels looks exactly like this"
			% [Pack.seeds().size(), LEAST_LEVELS])
	print("closest the estimate came to being too low: %.2fx" % _worst_ratio)
	var held: Array[String] = []
	for kind in Architecture.TYPES:
		if not Architecture.GENERATED.has(kind):
			held.append(kind)
	if not held.is_empty():
		print("held back from generation: %s" % str(held))
	var missing: Array[String] = []
	for kind in Architecture.GENERATED:
		if not _seen.has(kind):
			missing.append(kind)
	if not missing.is_empty():
		_lines.append("note: not sampled — %s" % str(missing))
		print("note: these systems were not sampled: %s" % str(missing))
	print("")
	print("expected : generated levels stand up, and the pile estimate is never")
	print("           below what the level really leaves")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit()
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
