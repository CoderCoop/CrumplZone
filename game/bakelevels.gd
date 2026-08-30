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
## How many levels of each structural system the pack carries.
##
## Deliberate coverage, not a random draw. Twenty-four random seeds produced
## six curtain walls, six strip malls and not a single grandstand — a system
## can be written, gated and shipped and still never appear, and nobody would
## know. The districts a player picks levels from need every kind of building
## to exist reliably, so the pack asks for each by name.
const PER_SYSTEM := 3
## The same level does not leave the same pile twice. Five runs and take the
## worst: the lines have to clear the unluckiest collapse, not the average one.
##
## Five rather than three because the standing check rides on the same runs,
## and three was letting levels through that gentest then failed. Measured on
## the pack, a level either accrues nothing at all after settling — twenty of
## twenty-two do — or it accrues two to six points. There is no marginal band
## in between, so the levels slipping through are genuinely degrading and the
## only question was how many rolls it takes to see it.
const REPEATS := 5
## How many validation passes to try before giving up and saying so.
const MAX_ROUNDS := 4


const CHARGE_EVERY := 14
const SETTLE := 900

var _level: Level
var _spec: Dictionary
var _jobs: Array = []
var _job := -1
var _run := 0
var _worst := 0.0
var _phase := ""
var _ticks := 0
var _charge_at := 0
var _spots: Array[Vector2] = []
var _top_at_build := 0.0
var _settled_damage := 0
var _validating := false
var _round := 0
var _check_at := -1
var _dropped_this_round := 0
var _order: Array = []
var _measured := {}
var _authored := {}
var _dropped: Array[String] = []
var _report_lines: Array[String] = []


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	for d in Levels.ORDER:
		_jobs.append({"kind": "authored", "id": d})
	var at := SEEDS_FROM
	for system in Architecture.GENERATED:
		for i in PER_SYSTEM:
			_jobs.append({"kind": "seed", "id": at, "system": system})
			at += 1
	_next_job()


func _next_job() -> void:
	_job += 1
	if _job >= _jobs.size():
		_begin_validation()
		return
	_run = 0
	_worst = 0.0
	_start()


func _spec_for_job() -> Dictionary:
	var job: Dictionary = _jobs[_job]
	if job["kind"] == "authored":
		return Levels.level(String(job["id"]))
	return Generator.generate(int(job["id"]), String(job.get("system", "")))


func _start() -> void:
	_spec = _spec_for_job()
	_level.build(_spec)
	_top_at_build = StandCheck.top_of(_level, _spec)
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
			if _ticks == StandCheck.SETTLE_TICKS:
				_settled_damage = StandCheck.damage_total(_level)
			if _ticks < StandCheck.SETTLE_TICKS + StandCheck.WATCH_TICKS:
				return
			# Checked on every run, not just the first.
			#
			# "If it stands once it stands" is not true here. Physics does not
			# reproduce across runs, and a marginal building stands on one
			# roll and crushes a piece on the next — measured, three levels
			# the bake had passed and shipped were then failed by gentest on
			# its own roll of the same level. The pack promises these stand,
			# so it has to check that as often as it checks anything else.
			var why := StandCheck.verdict(_level, _spec, _top_at_build,
				_settled_damage)
			if why != "":
				_dropped.append("%s (%s): %s on run %d of %d"
					% [_label(), _spec.get("kind", "?"), why, _run + 1, REPEATS])
				_next_job()
				return
			_phase = "flatten"
			_ticks = 0
		"validating":
			if _ticks == StandCheck.SETTLE_TICKS:
				_settled_damage = StandCheck.damage_total(_level)
			if _ticks < StandCheck.SETTLE_TICKS + StandCheck.WATCH_TICKS:
				return
			var verdict := StandCheck.verdict(_level, _spec, _top_at_build,
				_settled_damage)
			if verdict != "":
				_measured.erase(_order[_check_at])
				_dropped_this_round += 1
				_dropped.append("%d (%s): %s — failed validation in round %d"
					% [_order[_check_at], _spec.get("kind", "?"), verdict, _round])
			_next_check()
		"flatten":
			if _ticks % CHARGE_EVERY == 0 and _charge_at < _spots.size():
				Tools.apply(Tools.Kind.EXPLOSIVE, _level, _spots[_charge_at], 1.0)
				_charge_at += 1
			if _ticks < SETTLE + _spots.size() * CHARGE_EVERY:
				return
			_worst = maxf(_worst, StandCheck.top_of(_level, _spec))
			_run += 1
			if _run < REPEATS:
				_start()
			else:
				_record()
				_next_job()


## The last word, and the reason there is only one check.
##
## Measuring each level five times in isolation is not the same exam gentest
## sits: it builds every shipped level once, in pack order, after every
## earlier level has been demolished in the same process. Physics carries
## state between builds, so a level near the edge can pass one and fail the
## other — and dropping the culprit only promotes the next borderline level,
## which is exactly what happened when masonry was benched and a house and a
## stack took its place.
##
## So the bake finishes by sitting gentest's exam. Every accepted level, once,
## in order, and anything that fails is dropped. Then again, because dropping
## a level changes the sequence for the ones after it, until a pass drops
## nothing. What ships is what passed the check that gates it.
func _begin_validation() -> void:
	_validating = true
	_round += 1
	_check_at = -1
	_dropped_this_round = 0
	_order = []
	for level_seed in _measured.keys():
		_order.append(int(level_seed))
	_order.sort()
	_next_check()


func _next_check() -> void:
	_check_at += 1
	if _check_at >= _order.size():
		if _dropped_this_round > 0 and _round < MAX_ROUNDS:
			_report_lines.append("validation round %d dropped %d; going again"
				% [_round, _dropped_this_round])
			_begin_validation()
			return
		if _dropped_this_round > 0:
			_report_lines.append("validation gave up after %d rounds with %d still dropping"
				% [_round, _dropped_this_round])
		else:
			_report_lines.append("validation round %d: every level held" % _round)
		_write()
		return
	_spec = Generator.generate(_order[_check_at],
		Pack.system_for(_order[_check_at]))
	_level.build(_spec)
	_top_at_build = StandCheck.top_of(_level, _spec)
	_ticks = 0
	_phase = "validating"


func _label() -> String:
	var job: Dictionary = _jobs[_job]
	return "%s %s" % [job["kind"], job["id"]]


func _record() -> void:
	var job: Dictionary = _jobs[_job]
	var fy: float = float(_spec["floor_y"])
	var third: float = fy - float(_spec["height_line"])
	if third < _worst:
		_dropped.append("%s (%s): the winning line sits at %.0f px inside a %.0f px pile"
			% [_label(), _spec.get("kind", "?"), third, _worst])
		return
	# The solver used to run here too, to price the level. It was taken out:
	# it rejected six of twelve levels that gentest shows are winnable, and
	# priced the medium authored level at more than twice the hard one. A
	# search that cannot clear half the levels is not one to gate on or rate
	# against. See Levels.THREE_STAR_SHARE.
	# The system goes in the pack with the measurement, because the pack is
	# what the game rebuilds from. The bake asks for a system by name; if the
	# game then regenerated from the seed alone it would draw whatever that
	# seed happens to pick and build a different building than the one that
	# was measured — same seed, different level, and every number in the pack
	# describing something else.
	var entry := {"pile": _worst, "system": String(_spec.get("kind", ""))}
	if job["kind"] == "authored":
		_authored[String(job["id"])] = entry
	else:
		_measured[int(job["id"])] = entry
	var headroom := 99.0 if _worst <= 0.0 else third / _worst
	var note := "" if headroom >= Levels.MEASURED_MARGIN else "   TIGHT"
	_report_lines.append("%-16s %-13s pile %3.0f  line %3.0f  headroom %.2fx%s"
		% [_label(), _spec.get("kind", ""), _worst, third, headroom, note])


func _write() -> void:
	var source := FileAccess.get_file_as_string("res://pack.gd")
	var measured := "const MEASURED := {\n"
	var keys: Array = _measured.keys()
	keys.sort()
	for k in keys:
		measured += "\t%d: {\"pile\": %.0f, \"system\": \"%s\"},\n" % [
			k, _measured[k]["pile"], _measured[k]["system"]]
	measured += "}"
	var authored := "const AUTHORED := {\n"
	for d in Levels.ORDER:
		if _authored.has(d):
			authored += "\t\"%s\": {\"pile\": %.0f},\n" % [d, _authored[d]["pile"]]
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
