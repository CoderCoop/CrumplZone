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
## How many seeds a system may be offered before the bake gives up on filling
## its quota. Seeds are laid out in blocks of this size, one block per system,
## so a system needing a fourth attempt cannot collide with the next system's
## range and every seed number stays stable as systems come and go.
const ATTEMPTS_PER_SYSTEM := 9
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


## Frames a single job may take before the bake calls itself stalled. The
## longest honest job is REPEATS runs of a standing check plus a flatten that
## reaches its ceiling — around ten thousand frames on the biggest level — so
## this is roughly three times the worst legitimate case.
const STALL_FRAMES := 30000

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
var _current := {}
var _frames := 0
var _progress_frame := 0
var _system_at := 0
var _attempt := 0
var _accepted := {}
## Systems that ran out of seeds before filling their quota.
var _short: Array[String] = []
var _dropped: Array[String] = []
## Runs that hit the ceiling still moving, so the pile came off a collapse
## that had not finished.
var _restless: Array[String] = []
var _report_lines: Array[String] = []


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	for d in Levels.ORDER:
		_jobs.append({"kind": "authored", "id": d})
	_next_job()


## The next level to measure, backfilling a system that has lost one.
##
## It used to offer each system exactly PER_SYSTEM seeds and ship whatever
## survived. That is a quota in name only: a system whose seeds happen to fail
## ends up under-represented in the city, and the districts built on it go
## thin. Measured on the pack this replaces — masonry shipped one level of
## three, flat slabs and houses two of three, while chimneys and grandstands
## got all three. The player sees that as one part of town with nothing in it.
##
## So a dropped seed is replaced rather than mourned: the system is offered
## the next seed in its block until it has PER_SYSTEM accepted or the block
## runs out, and a system that cannot fill its quota says so.
func _next_job() -> void:
	_job += 1
	if _job < _jobs.size():
		_begin(_jobs[_job])
		return
	_offer_seed()


## Offer the current system its next seed, moving on once its quota is full or
## its block of seeds is spent.
func _offer_seed() -> void:
	while _system_at < Architecture.GENERATED.size():
		var system: String = String(Architecture.GENERATED[_system_at])
		var taken: int = int(_accepted.get(system, 0))
		if taken < PER_SYSTEM and _attempt < ATTEMPTS_PER_SYSTEM:
			var id: int = SEEDS_FROM + _system_at * ATTEMPTS_PER_SYSTEM \
				+ _attempt
			_attempt += 1
			_begin({"kind": "seed", "id": id, "system": system})
			return
		if taken < PER_SYSTEM:
			_short.append("%s filled %d of %d in %d attempts"
				% [system, taken, PER_SYSTEM, _attempt])
		_system_at += 1
		_attempt = 0
	_begin_validation()


func _begin(job: Dictionary) -> void:
	_current = job
	_run = 0
	_worst = 0.0
	# Printed as it goes. The measure phase used to say nothing at all until
	# it had finished, so a bake that was working and a bake that had hung
	# looked identical for minutes at a time — which is how a two-hour stall
	# went unnoticed once already, and it was the validation phase that got
	# the fix rather than this one.
	_progress_frame = _frames
	print("measuring %s%s" % [_label(),
		"" if job["kind"] == "authored" else " (%s, attempt %d)"
			% [job["system"], _attempt]])
	_start()


func _spec_for_job() -> Dictionary:
	if _current["kind"] == "authored":
		return Levels.level(String(_current["id"]))
	return Generator.generate(int(_current["id"]),
		String(_current.get("system", "")))


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
	_frames += 1
	# Guarded on the phase, not on the job index.
	#
	# This read `_job >= _jobs.size() and not _validating`, which was correct
	# only while _jobs held every job there would ever be. Once seeds were
	# issued on demand rather than listed up front, _jobs held the three
	# authored levels alone — so the moment the first seed came round, this
	# returned on every tick and the bake sat doing nothing.
	#
	# That is the second time this exact loop has hung, and the comment
	# describing the first was sitting directly above it. The phase is the
	# honest condition: it is empty only before the first job starts, and the
	# run quits from _write.
	if _phase == "":
		return
	# ...and a watchdog, because "did nothing, silently, for hours" is now a
	# thing this file has done twice. The first cost two hours locally; the
	# second cost six on a runner before the job timeout noticed. A stall is
	# a bug either way, and a bug should fail in minutes and say so.
	if _frames - _progress_frame > STALL_FRAMES:
		print("")
		print("stalled: %d frames without finishing a job, in phase \"%s\", on %s"
			% [_frames - _progress_frame, _phase,
				_label() if not _current.is_empty() else "no job"])
		print("that is a bug in the bake, not a slow level")
		get_tree().quit(1)
		return
	_ticks += 1
	var at_rest: bool = _level.tick_settle()
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
			# Stop when the rubble has stopped, not when a counter runs out.
			#
			# Level.tick_settle() has always returned whether everything has
			# come to rest, and this loop has always thrown that away and
			# counted to SETTLE instead. Measured across the pack, 49% of the
			# budget was spent watching a pile that had already stopped
			# moving — 14,528 ticks of 29,408, and up to 78% on a chimney.
			#
			# SETTLE stays, as a ceiling rather than a target. A level that
			# reaches it still moving has not been measured at rest, and the
			# pile taken from it is a snapshot of something mid-collapse, so
			# it is worth saying so.
			var ceiling: int = SETTLE + _spots.size() * CHARGE_EVERY
			var flattened: bool = _charge_at >= _spots.size() and at_rest
			if not flattened and _ticks < ceiling:
				return
			if not flattened:
				_restless.append("%s (%s) on run %d"
					% [_label(), _spec.get("kind", "?"), _run + 1])
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
	# Printed as it goes, not at the end. A job that reports only on success
	# is indistinguishable from a job that has hung, which is exactly how the
	# loop above went unnoticed.
	print("validation round %d over %d levels" % [_round, _measured.size()])
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
	_progress_frame = _frames
	print("  checking %d of %d" % [_check_at + 1, _order.size()])
	# The system comes from what was just measured, not from Pack.system_for.
	#
	# That reads the pack committed in the repository, which by definition does
	# not know about a seed this run has only just added — it returns "" and
	# the generator then draws whatever that seed happens to pick. Measured on
	# the run that first shipped grandstands: seed 4121 was validated as an
	# overpass, 4122 as a chimney, and only 4123 as the grandstand it is. 4122
	# was then dropped for sagging 345 px, which is something a chimney did.
	#
	# So the pass that this file calls "the last word" was checking different
	# buildings than the ones it ships, for every seed the pack did not already
	# carry — the newest ones, which are exactly the ones worth validating.
	var level_seed: int = int(_order[_check_at])
	_spec = Generator.generate(level_seed,
		String(_measured[level_seed]["system"]))
	_level.build(_spec)
	_top_at_build = StandCheck.top_of(_level, _spec)
	_ticks = 0
	_phase = "validating"


func _label() -> String:
	return "%s %s" % [_current["kind"], _current["id"]]


func _record() -> void:
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
	if _current["kind"] == "authored":
		_authored[String(_current["id"])] = entry
	else:
		_measured[int(_current["id"])] = entry
		var system := String(_current["system"])
		_accepted[system] = int(_accepted.get(system, 0)) + 1
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
	if not _short.is_empty():
		print("")
		print("systems that could not fill their quota:")
		for line in _short:
			print("  " + line)
	if not _restless.is_empty():
		print("")
		print("still moving when the budget ran out, so measured mid-collapse:")
		for r in _restless:
			print("  " + r)
	print("")
	print("%d levels measured over %d runs each, worst kept" % [_report_lines.size(), REPEATS])
	print("pack.gd written")
	get_tree().quit()
