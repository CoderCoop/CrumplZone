extends Node2D

## Measures how low every level can physically go, and writes pack.gd.
##
##   godot --headless --fixed-fps 60 --path game res://bakelevels.tscn
##
## This is the job that replaced a model with a measurement. It builds each
## level, checks it stands untouched, then flattens it completely several
## times and records the worst pile it left. Levels are deterministic from
## their seed, so the pack is a table of seed to measured height and the
## geometry is rebuilt from the seed wherever it is needed.
##
## It runs in CI rather than in the game: a bake is minutes of physics, and
## nothing about it belongs on a path a player waits on. The result is
## committed, so a change to the generator shows up as a reviewable diff in
## the pile heights rather than as levels quietly shifting under players.
##
## A seed that will not stand up is dropped from the pack with its reason
## printed. A level nobody could play is not one to ship, and silently
## shipping it is how the gate stops meaning anything.

const SEEDS_FROM := 4100
const SEEDS := 12
## The same level does not leave the same pile twice. Three runs and take the
## worst: the lines have to clear the unluckiest collapse, not the average one.
const REPEATS := 3
## How deep the search for a cheapest clearing goes. Five is what verify_levels
## established as the useful depth, and one level costs about two minutes at
## it — which is why this is a scheduled job and not a pull-request gate.
const SOLVE_MOVES := 5
const STAND_TICKS := 240
const CHARGE_EVERY := 14
const SETTLE := 900

var _level: Level
var _solver: Solver
var _spec: Dictionary
var _par := 0.0
var _jobs: Array = []
var _job := -1
var _run := 0
var _worst := 0.0
var _phase := ""
var _ticks := 0
var _charge_at := 0
var _spots: Array[Vector2] = []
var _top_at_build := 0.0
var _measured := {}
var _authored := {}
var _dropped: Array[String] = []
var _report_lines: Array[String] = []


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	# The same search partest uses, so par here is the number partest checks.
	_solver = Solver.new()
	_solver.max_moves = SOLVE_MOVES
	_solver.verbose = false
	_solver.finished.connect(_on_solved)
	add_child(_solver)
	for d in Levels.ORDER:
		_jobs.append({"kind": "authored", "id": d})
	for i in SEEDS:
		_jobs.append({"kind": "seed", "id": SEEDS_FROM + i})
	_next_job()


func _next_job() -> void:
	_job += 1
	if _job >= _jobs.size():
		_write()
		return
	_run = 0
	_worst = 0.0
	_start()


func _spec_for_job() -> Dictionary:
	var job: Dictionary = _jobs[_job]
	if job["kind"] == "authored":
		return Levels.level(String(job["id"]))
	return Generator.generate(int(job["id"]))


func _start() -> void:
	_spec = _spec_for_job()
	_level.build(_spec)
	_top_at_build = _top_now()
	_spots = []
	for b in _spec["blocks"]:
		_spots.append(Vector2(float(b["x"]), float(b["y"])))
	_charge_at = 0
	_ticks = 0
	_phase = "standing"


func _physics_process(_delta: float) -> void:
	if _job >= _jobs.size():
		return
	_ticks += 1
	_level.tick_settle()
	match _phase:
		"standing":
			if _ticks < STAND_TICKS:
				return
			# Only checked on the first run; if it stands once it stands.
			if _run == 0:
				var why := _why_it_will_not_do()
				if why != "":
					_dropped.append("%s: %s" % [_label(), why])
					_next_job()
					return
			_phase = "flatten"
			_ticks = 0
		"flatten":
			if _ticks % CHARGE_EVERY == 0 and _charge_at < _spots.size():
				Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_charge_at], 1.0)
				_charge_at += 1
			if _ticks < SETTLE + _spots.size() * CHARGE_EVERY:
				return
			_worst = maxf(_worst, _top_now())
			_run += 1
			if _run < REPEATS:
				_start()
			else:
				# How low it can go is measured; what it costs to get there is
				# searched for. Both are measurements, and both used to be
				# neither: the pile was modelled and par was worked out by
				# hand and went stale the next time the physics moved.
				_phase = "solving"
				_solver.start(_spec_for_job())


func _on_solved(result: Dictionary) -> void:
	_par = 0.0
	if bool(result["solved"]):
		for move in result["solution"]:
			_par += Tools.cost(move["tool"], 1.0)
	_record()
	_next_job()


## Why this level is not fit to ship, or "" if it is.
func _why_it_will_not_do() -> String:
	var damaged := 0
	for body in _level.live_blocks():
		if int(body.get_meta("damage", 0)) > 0:
			damaged += 1
	if damaged > 0:
		return "%d pieces damage themselves standing still" % damaged
	var dropped := _top_now() - _top_at_build
	var allowed: float = maxf(12.0, _top_at_build * 0.06)
	if dropped > allowed:
		return "sags %.0f px untouched, over %.0f allowed for its height" % [dropped, allowed]
	return ""


func _top_now() -> float:
	var floor_y: float = float(_spec["floor_y"])
	var peak := floor_y
	for body in _level.live_blocks():
		var poly: PackedVector2Array = body.get_meta("poly")
		for point in poly:
			peak = minf(peak, body.global_position.y + point.rotated(body.rotation).y)
	return floor_y - peak


func _label() -> String:
	var job: Dictionary = _jobs[_job]
	return "%s %s" % [job["kind"], job["id"]]


func _record() -> void:
	var job: Dictionary = _jobs[_job]
	var fy: float = float(_spec["floor_y"])
	var third: float = fy - float(_spec["height_line"])
	if third < _worst:
		_dropped.append("%s: the winning line sits at %.0f px inside a %.0f px pile"
			% [_label(), third, _worst])
		return
	# A level nobody can clear is not a level. The solver searching to its
	# depth and finding nothing is the strongest statement available about
	# that, and it is worth more than any check on the shape of the building.
	if _par <= 0.0:
		_dropped.append("%s: no clearing found within %d moves" % [_label(), SOLVE_MOVES])
		return
	var entry := {"pile": _worst, "par": _par}
	if job["kind"] == "authored":
		_authored[String(job["id"])] = entry
	else:
		_measured[int(job["id"])] = entry
	var headroom := 99.0 if _worst <= 0.0 else third / _worst
	var note := "" if headroom >= Levels.MEASURED_MARGIN else "   TIGHT"
	_report_lines.append("%-16s %-13s pile %3.0f  line %3.0f  headroom %.2fx  par %3.0f of %3.0f bar%s"
		% [_label(), _spec.get("kind", ""), _worst, third, headroom, _par,
			float(_spec["power"]), note])


func _write() -> void:
	var source := FileAccess.get_file_as_string("res://pack.gd")
	var measured := "const MEASURED := {\n"
	var keys: Array = _measured.keys()
	keys.sort()
	for k in keys:
		measured += "\t%d: {\"pile\": %.0f, \"par\": %.0f},\n" % [
			k, _measured[k]["pile"], _measured[k]["par"]]
	measured += "}"
	var authored := "const AUTHORED := {\n"
	for d in Levels.ORDER:
		if _authored.has(d):
			authored += "\t\"%s\": {\"pile\": %.0f, \"par\": %.0f},\n" % [
				d, _authored[d]["pile"], _authored[d]["par"]]
	authored += "}"

	var out := ""
	var skipping := false
	for line in source.split("\n"):
		if line.begins_with("const MEASURED :="):
			out += measured + "\n"
			skipping = true
			continue
		if line.begins_with("const AUTHORED :="):
			out += authored + "\n"
			skipping = true
			continue
		if skipping:
			# The old table ran to its closing brace; skip to past it.
			if line.begins_with("}") or line.strip_edges() == "":
				skipping = false
			continue
		out += line + "\n"
	# split() on a trailing newline leaves an empty last element, so the
	# rebuild gains one blank line per pass without this.
	while out.ends_with("\n\n\n"):
		out = out.substr(0, out.length() - 1)
	var f := FileAccess.open("res://pack.gd", FileAccess.WRITE)
	f.store_string(out)
	f.close()

	print("")
	for line in _report_lines:
		print(line)
	if not _dropped.is_empty():
		print("")
		print("dropped, and not in the pack:")
		for d in _dropped:
			print("  " + d)
	print("")
	print("%d levels measured over %d runs each, worst kept" % [_report_lines.size(), REPEATS])
	print("pack.gd written")
	get_tree().quit()
