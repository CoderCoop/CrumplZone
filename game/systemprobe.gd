extends Node2D

## Why does a disabled structural system not stand up?
##
##   godot --headless --fixed-fps 60 --path game res://systemprobe.tscn -- <system> [count]
##
## Three systems are held back from Architecture.GENERATED because they damage
## themselves standing still. Which piece, and by how much, is the whole
## question — and the generate step only ever printed that a seed was dropped.
##
## Not a gate. It measures and prints, so a rebuild can be aimed rather than
## guessed at, and so the same seeds can be re-measured after a change.

var _level: Level
var _spec: Dictionary
var _queue: Array = []
var _seed := 0
var _ticks := 0
var _settled := 0
var _top_at_build := 0.0
var _system := ""
var _lines: Array[String] = []
var _where_at_build := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_system = args[0] if args.size() > 0 else Architecture.STAND
	var count := 6
	if args.size() > 1 and String(args[1]).is_valid_int():
		count = String(args[1]).to_int()
	# "pack" measures every level that actually ships, which is how a change to
	# the standing check gets priced before it is made.
	if _system == "pack":
		for id in Pack.seeds():
			_queue.append(int(id))
	elif _system.is_valid_int():
		# One seed, built first and alone. Physics carries state between builds
		# in a process, so a level measured eighth in a sequence and the same
		# level measured on its own are two different measurements, and telling
		# them apart is the whole point of having this.
		_queue.append(_system.to_int())
		_system = "pack"
	else:
		for i in count:
			_queue.append(4100 + i)
	_level = Level.new()
	add_child(_level)
	_start()


func _start() -> void:
	_seed = int(_queue.pop_front())
	_spec = Generator.generate(_seed, "" if _system == "pack"
		else _system) if _system != "pack" else Generator.generate(_seed,
		Pack.system_for(_seed))
	_level.build(_spec)
	_top_at_build = StandCheck.top_of(_level, _spec)
	_where_at_build = _tops_by_role()
	_ticks = 0
	_settled = 0


## The highest point of each role, as a height above the street. Which piece is
## moving, and which way, is the question the one summed number cannot answer.
func _tops_by_role() -> Dictionary:
	var floor_y: float = float(_spec["floor_y"])
	var found := {}
	for body in _level.live_blocks():
		var role := String(body.get_meta("role", "?"))
		var poly: PackedVector2Array = body.get_meta("poly")
		var peak := floor_y
		for point in poly:
			peak = minf(peak, body.global_position.y
				+ point.rotated(body.rotation).y)
		found[role] = maxf(float(found.get(role, -1e9)), floor_y - peak)
	return found


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_level.tick_settle()
	if _ticks == StandCheck.SETTLE_TICKS:
		_settled = StandCheck.damage_total(_level)
	if _ticks < StandCheck.SETTLE_TICKS + StandCheck.WATCH_TICKS:
		return
	_record()
	if _queue.is_empty():
		_report()
		return
	_start()


func _record() -> void:
	var verdict := StandCheck.verdict(_level, _spec, _top_at_build, _settled)
	var now := StandCheck.damage_total(_level)
	var sag := _top_at_build - StandCheck.top_of(_level, _spec)
	_lines.append("seed %d  %s" % [_seed, "HOLDS" if verdict == "" else verdict])
	_lines.append("    damage at rest %d, after watching %d (+%d), sag %.1f px"
		% [_settled, now, now - _settled, sag])
	var now_where := _tops_by_role()
	var roles: Array = _where_at_build.keys()
	roles.sort()
	for role in roles:
		var was: float = float(_where_at_build[role])
		var is_now: float = float(now_where.get(role, -1.0))
		if is_now < 0.0:
			_lines.append("    %-12s gone" % role)
			continue
		if absf(is_now - was) < 1.0:
			continue
		_lines.append("    %-12s top %6.1f -> %6.1f  (%+.1f, %s)"
			% [role, was, is_now, is_now - was,
				"rose" if is_now > was else "sank"])
	var who := StandCheck.culprits(_level)
	if who.is_empty():
		_lines.append("    nothing damaged")
		return
	var names: Array = who.keys()
	names.sort()
	for what in names:
		_lines.append("    %-28s %d pieces" % [what, who[what]])


func _report() -> void:
	print("")
	print("system: %s" % _system)
	print("")
	for line in _lines:
		print(line)
	print("")
	print("this measures, it does not gate")
	get_tree().quit()
