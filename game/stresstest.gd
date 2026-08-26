extends Node2D

## Load has to break things, and it has to break only the right things.
##
##   godot --headless --fixed-fps 60 --path game res://stresstest.tscn
##
## Three claims, and the first one is the one that matters most: a building
## standing on its own must not eat itself. A stress model tuned a little too
## low turns every level into one that collapses before the player touches it,
## and the failure is silent — the solver would report the level unsolvable and
## nothing would say why.
##
## The numbers this is tuned against were measured, not guessed: in a settled
## tower the worst sustained load on a pane is 29, a pane carrying a floor slab
## sees 116, and a slab landing on one spikes to 1271.

const FLOOR_Y := 540.0
const STAND_TICKS := 400        # six and a half seconds of standing still
## How far something has to drop before "it was not being held up" is a fair
## description of what happened. Settling onto a stump moves a few px.
const FALL := 40.0
const LOAD_TICKS := 400

## Long enough for a dropped pile to land and stop moving, then long enough
## again for anything that grinds down under a steady load to show it.
const REST_SETTLE := 300
const REST_HOLD := 420

## A whole collapse, then long enough for everything to come to rest.
const VELOCITY_TICKS := 1500

var _level: Level
var _failures: Array[String] = []
var _phase := "standing"
var _ticks := 0
var _pieces_before := 0
var _pane: RigidBody2D
var _pane_broke_at := -1
var _swept_before := 0
var _standing_before := 0
var _slab: RigidBody2D
var _slab_y := 0.0
var _rest_damage := 0
var _rest_watching := false
var _rest_floor: RigidBody2D
var _rest_peak := 0.0
var _velocity_plan: Array = []
var _velocity_step := 0


func _ready() -> void:
	_level = Level.new()
	_level.struck.connect(func(_at: Vector2, amount: int) -> void:
		if _rest_watching:
			_rest_damage += amount
)
	add_child(_level)
	_level.build(Levels.level(Levels.MEDIUM))
	_pieces_before = _level.live_blocks().size()


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_level.tick_settle()
	match _phase:
		"standing":
			if _ticks < STAND_TICKS:
				return
			_finish_standing()
			_phase = "load"
			_ticks = 0
			_start_load()
		"load":
			if is_instance_valid(_pane):
				if _ticks < LOAD_TICKS:
					return
			elif _pane_broke_at < 0:
				_pane_broke_at = _ticks
			_finish_load()
			_phase = "sweep"
			_ticks = 0
			_start_sweep()
		"sweep":
			if _ticks < 300:
				return
			_finish_sweep()
			_phase = "dust"
			_ticks = 0
			_start_dust()
		"dust":
			if _ticks < 240:
				return
			_finish_dust()
			_phase = "velocity"
			_ticks = 0
			_start_velocity()
		"velocity":
			_drive_velocity()
			if _ticks < VELOCITY_TICKS:
				return
			_finish_velocity()
			_phase = "resting"
			_ticks = 0
			_start_resting()
		"resting":
			if _ticks == REST_SETTLE:
				# Everything has landed. Damage from here on is damage taken
				# for standing still, which is the thing being measured.
				_rest_damage = 0
				_rest_watching = true
			if _rest_watching and is_instance_valid(_rest_floor):
				var st := PhysicsServer2D.body_get_direct_state(_rest_floor.get_rid())
				if st != null:
					var l := 0.0
					for i in st.get_contact_count():
						l += st.get_contact_impulse(i).length()
					_rest_peak = maxf(_rest_peak, l)
			if _ticks < REST_SETTLE + REST_HOLD:
				return
			_finish_resting()
			_report()
			_phase = "done"


# --- 1. a building that stands must keep standing --------------------------

func _finish_standing() -> void:
	var now := _level.live_blocks().size()
	var damaged := 0
	for body in _level.live_blocks():
		if int(body.get_meta("damage", 0)) > 0:
			damaged += 1
	print("standing    %d pieces before, %d after %d ticks untouched; %d damaged"
		% [_pieces_before, now, STAND_TICKS, damaged])
	if now != _pieces_before:
		_failures.append("the building broke itself while standing still: %d pieces became %d"
			% [_pieces_before, now])
	if damaged > 0:
		_failures.append("%d pieces took damage with nothing acting on them" % damaged)


# --- 2. weight from above breaks what is under it --------------------------

func _start_load() -> void:
	_level.build({
		"centre_x": 400.0, "floor_y": FLOOR_Y, "height_line": FLOOR_Y - 400.0,
		"power": 100.0, "moves": 1,
		"blocks": [
			{"x": 360.0, "y": FLOOR_Y - 28.0, "w": 20.0, "h": 56.0,
				"material": Materials.STEEL},
			{"x": 440.0, "y": FLOOR_Y - 28.0, "w": 20.0, "h": 56.0,
				"material": Materials.STEEL},
			{"x": 400.0, "y": FLOOR_Y - 28.0, "w": 50.0, "h": 56.0,
				"material": Materials.GLASS},
			{"x": 400.0, "y": FLOOR_Y - 150.0, "w": 200.0, "h": 22.0,
				"material": Materials.CONCRETE},
		],
	})
	_pane = _level.live_blocks()[2]
	_pane_broke_at = -1


func _finish_load() -> void:
	var broke := not is_instance_valid(_pane)
	print("load        a slab dropped on a pane: %s"
		% [("broke it after %.1fs" % (float(_pane_broke_at) / 60.0)) if broke
			else "the pane is still whole after %.1fs" % (float(LOAD_TICKS) / 60.0)])
	if not broke:
		_failures.append("a concrete floor landed on a pane of glass and it held")


# --- 3. rubble below the line is swept up ----------------------------------

func _start_sweep() -> void:
	_level.build(Levels.level(Levels.MEDIUM))
	_swept_before = _level.debris_count()
	# Shatter the ground-floor glazing, which lands below the line.
	for x in [314.0, 400.0, 486.0]:
		Tools.apply(Tools.Kind.EXPLOSIVE, _level, Vector2(x, FLOOR_Y - 38.0), 1.0)
	_standing_before = _level.standing()


func _finish_sweep() -> void:
	var swept := _level.debris_count()
	print("sweep       %d pieces of rubble swept up; %d still standing above the line"
		% [swept, _level.standing()])
	if swept <= _swept_before:
		_failures.append("no rubble was ever swept up — the street fills with slivers forever")
	# Everything swept was already below the line, so sweeping can never be
	# what clears a level.
	for body in _level.live_blocks():
		if not is_instance_valid(body):
			_failures.append("a live piece went missing")


# --- 4. glass ground to slivers cannot hold anything up -------------------

func _start_dust() -> void:
	# A slab held up on nothing but a heap of the smallest glass slivers. It
	# has no business staying up there.
	var blocks: Array = []
	var size := sqrt(Materials.MIN_AREA * 2.0) * 0.8
	for i in 6:
		blocks.append({
			"x": 380.0 + float(i % 3) * size, "y": FLOOR_Y - 20.0 - float(i / 3) * size,
			"w": size, "h": size, "material": Materials.GLASS})
	blocks.append({
		"x": 400.0, "y": FLOOR_Y - 90.0, "w": 120.0, "h": 22.0,
		"material": Materials.CONCRETE})
	_level.build({
		"centre_x": 400.0, "floor_y": FLOOR_Y, "height_line": FLOOR_Y - 400.0,
		"power": 100.0, "moves": 1, "blocks": blocks,
	})
	_slab = _level.live_blocks()[6]
	_slab_y = _slab.global_position.y


func _finish_dust() -> void:
	var dropped := (_slab.global_position.y - _slab_y) if is_instance_valid(_slab) else 9999.0
	var shards := 0
	var resting_high := 0
	for body in _level.live_blocks():
		if bool(body.get_meta("dust", false)):
			shards += 1
			if body.global_position.y < FLOOR_Y - 40.0:
				resting_high += 1
	print("dust        slab on a heap of slivers fell %.0f px; %d shards left, %d of them still up high"
		% [dropped, shards, resting_high])
	if dropped < FALL:
		_failures.append(
			"a slab rested on glass slivers: it only fell %.0f px" % dropped)


# --- 5. how fast it arrives is most of what does the damage ----------------

## A real collapse of the real tower, judged on where its load damage landed.
##
## A synthetic single drop was tried first and thrown away: the impact spike
## lasts about two ticks and the stress pass samples every two, so whether it
## registered at all was a coin toss. That is a test that cannot be trusted in
## either direction. A whole collapse is deterministic here — two runs came
## back identical — and it measures the thing actually complained about.
##
## Measured before severity was made continuous: a sixth of all load damage
## was dealt at 8-25 px/s, by pieces barely drifting, because tolerance was a
## step at 8 px/s and anything over it was judged as harshly as a slab
## arriving at 400. Glass is exempt by design — a pane under sustained weight
## is supposed to crack — so the assertion is about everything else.
func _start_velocity() -> void:
	_level.build(Levels.level(Levels.MEDIUM))
	var cx: float = float(_level.spec["centre_x"])
	var fy: float = float(_level.spec["floor_y"])
	_velocity_plan = [
		[40, Tools.Kind.EXPLOSIVE, Vector2(cx - 90.0, fy - 60.0)],
		[120, Tools.Kind.EXPLOSIVE, Vector2(cx + 90.0, fy - 60.0)],
		[220, Tools.Kind.WRECKING_BALL, Vector2(cx, fy - 200.0)],
		[420, Tools.Kind.EXPLOSIVE, Vector2(cx, fy - 150.0)],
	]
	_velocity_step = 0


func _drive_velocity() -> void:
	while _velocity_step < _velocity_plan.size() \
			and _ticks >= int(_velocity_plan[_velocity_step][0]):
		Tools.apply(_velocity_plan[_velocity_step][1], _level,
			_velocity_plan[_velocity_step][2], 1.0)
		_velocity_step += 1


func _finish_velocity() -> void:
	var total := _level.load_damage_total
	var slow := _level.load_damage_slow
	var solid := _level.load_damage_slow_solid
	var share := 0.0 if total == 0 else float(slow) / float(total) * 100.0
	print("velocity    %d load damage over a collapse; %d of it under %.0f px/s (%.0f%%), %d of that to something other than glass"
		% [total, slow, Level.SLOW_CONTACT, share, solid])
	if total == 0:
		_failures.append("a whole collapse did no load damage at all — the model is inert")
	if solid > 0:
		_failures.append("%d damage was dealt to solid material by a contact under %.0f px/s"
			% [solid, Level.SLOW_CONTACT])


# --- 6. a piece does not grind down for holding something up ---------------

## Measured before this phase existed: over one full collapse of the tower,
## 40% of all stress damage was dealt to pieces that were standing still, the
## bulk of it concrete carrying 702-813 against a tolerance of 300 at under
## 3 px/s. That is a heap that has settled, not a blow, and a floor should
## carry it rather than being worn away by it.
func _start_resting() -> void:
	var blocks: Array = [
		{"x": 340.0, "y": FLOOR_Y - 30.0, "w": 24.0, "h": 60.0,
			"material": Materials.STEEL},
		{"x": 460.0, "y": FLOOR_Y - 30.0, "w": 24.0, "h": 60.0,
			"material": Materials.STEEL},
		{"x": 400.0, "y": FLOOR_Y - 71.0, "w": 180.0, "h": 22.0,
			"material": Materials.CONCRETE},
	]
	# A pile dropped onto the floor from just above it: enough weight to be
	# well past what the floor is rated for, landing gently enough that this
	# is a resting load and not an impact test.
	for i in 18:
		blocks.append({
			"x": 340.0 + float(i % 3) * 60.0,
			"y": FLOOR_Y - 110.0 - float(i / 3) * 34.0,
			"w": 52.0, "h": 30.0, "material": Materials.CONCRETE,
		})
	_level.build({
		"centre_x": 400.0, "floor_y": FLOOR_Y, "height_line": FLOOR_Y - 400.0,
		"power": 100.0, "moves": 1, "blocks": blocks,
	})
	_rest_floor = _level.live_blocks()[2]
	_rest_damage = 0
	_rest_watching = false


func _finish_resting() -> void:
	_rest_watching = false
	var whole := is_instance_valid(_rest_floor)
	print("resting     a loaded floor left alone for %.1fs: %d damage, floor %s, peak load %.0f vs limit %.0f"
		% [float(REST_HOLD) / 60.0, _rest_damage,
			"intact" if whole else "broke up", _rest_peak,
			Materials.stress_limit(Materials.CONCRETE)])
	if _rest_damage > 0:
		_failures.append("a settled pile did %d damage to what it was resting on"
			% _rest_damage)
	if not whole:
		_failures.append("a floor broke up under a load that had stopped moving")


func _report() -> void:
	print("")
	print("expected : an untouched building does not break itself, a floor")
	print("           landing on glass breaks it, rubble that has come to rest")
	print("           below the line stops being simulated, glass ground to")
	print("           slivers holds nothing up, how fast something arrives is")
	print("           most of the damage, and a settled pile does not wear away")
	print("           what it is sitting on")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
