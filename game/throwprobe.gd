extends Node2D

## What does one charge actually throw, and how differently by material?
##
##   godot --headless --fixed-fps 60 --path game res://throwprobe.tscn
##
## The blast used to multiply its impulse by the body's mass, which cancels
## the mass straight back out — apply_impulse divides by it — so every piece
## in the radius left at the same speed whatever it was made of. This measures
## the replacement rather than trusting it: one full charge at the foot of one
## generated building of each system, and for every piece inside the radius,
## the speed it is carrying one frame later against what it is and what it
## weighs.
##
## Not a gate. It prints a distribution so a constant can be chosen from a
## measurement instead of from how it looked once.

const SEED := 4100

var _level: Level
var _queue: Array = []
var _system := ""
var _phase := ""
var _ticks := 0
var _before := {}
var _rows: Array = []
var _by_material := {}
var _peak := {}
var _spin := {}
var _fired_at := 0


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	_queue = Architecture.GENERATED.duplicate()
	_next()


func _next() -> void:
	if _queue.is_empty():
		_report()
		return
	_system = String(_queue.pop_front())
	var spec := Generator.generate(SEED, _system)
	_level.build(spec)
	_ticks = 0
	_peak = {}
	_spin = {}
	_phase = "settling"


func _physics_process(_delta: float) -> void:
	if _phase == "":
		return
	_ticks += 1
	var at_rest: bool = _level.tick_settle()
	match _phase:
		"settling":
			# Fired only once everything is still, so what is measured is the
			# blast and not whatever the building was already doing.
			if not at_rest and _ticks < 600:
				return
			_before = {}
			for body in _level.live_blocks():
				_before[body.get_instance_id()] = body.global_position
			var spec: Dictionary = _level.spec
			Tools.apply(Tools.Kind.EXPLOSIVE, _level,
				Vector2(float(spec["centre_x"]), float(spec["floor_y"]) - 60.0),
				1.0)
			_fired_at = _ticks
			_phase = "thrown"
		"thrown":
			# The peak over a short window, not the speed one frame later.
			# A piece is still wedged against its neighbours on the frame the
			# impulse lands, so reading it there measures the contact solver
			# rather than the blast — measured, that reported dense steel
			# columns moving faster than light roof sheeting, which is the
			# opposite of the model and was an artefact of where each of them
			# happened to be standing.
			for body in _level.live_blocks():
				var id := body.get_instance_id()
				if not _before.has(id):
					continue
				_peak[id] = maxf(float(_peak.get(id, 0.0)),
					body.linear_velocity.length())
				_spin[id] = maxf(float(_spin.get(id, 0.0)),
					absf(body.angular_velocity))
			if _ticks < _fired_at + 12:
				return
			for body in _level.live_blocks():
				var id := body.get_instance_id()
				if not _before.has(id):
					continue
				var speed: float = float(_peak.get(id, 0.0))
				if speed < 1.0:
					continue
				var made: String = String(body.get_meta("material", "?"))
				if not _by_material.has(made):
					_by_material[made] = []
				_by_material[made].append(speed)
				_rows.append([_system, made, body.mass, speed,
					float(_spin.get(id, 0.0))])
			_phase = ""
			_next()


func _report() -> void:
	print("")
	print("one full charge, %d pieces moved" % _rows.size())
	print("")
	print("%-12s %8s %8s %8s %8s %6s" % ["material", "density", "pieces",
		"slowest", "fastest", "median"])
	var names: Array = _by_material.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return float(Materials.of(a)["density"]) < float(Materials.of(b)["density"]))
	for made in names:
		var speeds: Array = _by_material[made]
		speeds.sort()
		print("%-12s %8.4f %8d %8.0f %8.0f %6.0f" % [made,
			float(Materials.of(String(made))["density"]), speeds.size(),
			speeds[0], speeds[speeds.size() - 1],
			speeds[speeds.size() / 2]])
	print("")
	print("Expected shape: speed goes as 1/density, so the lightest here")
	print("should leave about six times faster than the heaviest. A flat")
	print("column means the mass is being cancelled out again.")
	var spins: Array = []
	for row in _rows:
		spins.append(float(row[4]))
	spins.sort()
	print("")
	print("spin, rad/s: median %.1f, fastest %.1f — a column of zeroes means"
		% [spins[spins.size() / 2], spins[spins.size() - 1]])
	print("the throw is landing on the centre of mass and nothing tumbles.")
	get_tree().quit(0)
