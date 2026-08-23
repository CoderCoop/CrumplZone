extends Node2D

## Determinism spike for CrumplZone.
##
## Question: does Godot 4's 2D physics produce bit-identical final resting
## states when the same structure is demolished with the same impulse?
##
## CHARTER.md commits to generating and verifying levels on the player's own
## device. That guarantee is only worth anything if repeating an identical
## simulation gives an identical result. This script builds a small tower,
## blows out a support, lets it collapse and settle, and does that several
## times in one process — then compares the runs against each other.
##
## It prints a verdict and writes the raw states to JSON for cross-process
## comparison. It is a measurement harness, not game code.

const RUNS := 6
const SEED := 20260823
const IMPULSE_TICK := 60
const TOTAL_TICKS := 900

const FLOOR_Y := 600.0
const PILLAR_W := 20.0
const PILLAR_H := 80.0
const SLAB_H := 20.0
const STOREYS := 3
const PILLARS_PER_STOREY := 4
const PILLAR_SPACING := 100.0
const FIRST_PILLAR_X := 200.0

# Density in mass units per square pixel. RigidBody2D defaults to mass 1.0
# whatever its size, which makes a slab as light as a pebble.
const DENSITY := 0.001

# Which body gets the "explosive". Index into _bodies, in creation order:
# storey 0's second pillar — a load-bearing one, so the collapse is real.
# The impulse is sized to knock the pillar out and topple what it carries,
# not to launch it off the map: at these masses it imparts a few hundred
# pixels per second, which is a demolition charge rather than a railgun.
const TARGET_BODY := 1
const IMPULSE := Vector2(600.0, -120.0)

# Ticks to wait after teardown before rebuilding. Generous on purpose: if
# divergence survives a long gap, it is not leftover bodies still in the space.
const TEARDOWN_TICKS := 10

var _phase := "build"
var _tick := 0
var _run := -1  # first cooldown tick advances this to run 0
var _cooldown := 0
var _bodies: Array[RigidBody2D] = []
var _states: Array = []


func _ready() -> void:
	print("determinism spike: %d runs, %d ticks each, seed %d" % [RUNS, TOTAL_TICKS, SEED])
	# Every run, including the first, is built from inside _physics_process.
	# Building run 0 from _ready() instead would integrate it differently and
	# show up as divergence that belongs to this harness, not to the engine.
	_phase = "cooldown"
	_cooldown = 1


func _physics_process(_delta: float) -> void:
	match _phase:
		"sim":
			if _tick == IMPULSE_TICK:
				_bodies[TARGET_BODY].apply_impulse(IMPULSE)
			_tick += 1
			if _tick >= TOTAL_TICKS:
				_states.append(_capture())
				_teardown()
				_phase = "cooldown"
				_cooldown = TEARDOWN_TICKS
		"cooldown":
			_cooldown -= 1
			if _cooldown <= 0:
				_run += 1
				if _run < RUNS:
					_build()
				else:
					_report()
					get_tree().quit()


## Builds the same tower every time: a floor, then storeys of pillars carrying
## a slab. Positions carry a small seeded jitter so the structure is not
## perfectly symmetric — symmetry can hide divergence that a real generated
## level would expose.
func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.0

	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(400.0, FLOOR_Y + 20.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(1200.0, 40.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	_bodies = []
	var y := FLOOR_Y
	for storey in STOREYS:
		for i in PILLARS_PER_STOREY:
			var jitter := rng.randf_range(-0.35, 0.35)
			var x := FIRST_PILLAR_X + i * PILLAR_SPACING + jitter
			_bodies.append(_make_block(
				Vector2(x, y - PILLAR_H * 0.5),
				Vector2(PILLAR_W, PILLAR_H),
				material))
		y -= PILLAR_H
		var slab_x := FIRST_PILLAR_X + (PILLARS_PER_STOREY - 1) * PILLAR_SPACING * 0.5
		var slab_w := (PILLARS_PER_STOREY - 1) * PILLAR_SPACING + PILLAR_W * 2.0
		_bodies.append(_make_block(
			Vector2(slab_x, y - SLAB_H * 0.5),
			Vector2(slab_w, SLAB_H),
			material))
		y -= SLAB_H

	_tick = 0
	_phase = "sim"


func _make_block(pos: Vector2, size: Vector2, material: PhysicsMaterial) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.position = pos
	body.physics_material_override = material
	body.mass = size.x * size.y * DENSITY
	# Rubble moves fast enough to tunnel through the floor without this, and a
	# body that escapes the level swamps every other difference in the compare.
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	return body


## Groups run indices by identical final state.
func _equivalence_classes() -> Array:
	var classes := []
	for i in _states.size():
		var placed := false
		for c in classes:
			if _same(_states[c[0]], _states[i]):
				c.append(i)
				placed = true
				break
		if not placed:
			classes.append([i])
	return classes


func _same(a: Array, b: Array) -> bool:
	for i in a.size():
		for key in ["x", "y", "rot"]:
			if a[i][key] != b[i][key]:
				return false
	return true


## Spread of the highest resting body across runs. The win condition is a
## height line, so this is the divergence that can actually flip a verdict.
func _top_spread() -> float:
	var tops := []
	for state in _states:
		var top: float = INF
		for body in state:
			top = minf(top, float(body["y"]))
		tops.append(top)
	var lo: float = tops[0]
	var hi: float = tops[0]
	for t in tops:
		lo = minf(lo, t)
		hi = maxf(hi, t)
	return hi - lo


func _pairs() -> Array:
	var out := []
	for i in _states.size():
		for j in range(i + 1, _states.size()):
			out.append([i, j])
	return out


func _capture() -> Array:
	var state := []
	for body in _bodies:
		state.append({
			"x": body.position.x,
			"y": body.position.y,
			"rot": body.rotation,
			"sleeping": body.sleeping,
		})
	return state


func _teardown() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_bodies = []


## Compares every pair of runs and prints expected-versus-actual rather than
## output to eyeball. Comparing all pairs, not just against run 0, keeps a
## first-run artifact distinguishable from genuine engine non-determinism.
func _report() -> void:
	var worst := 0.0
	var identical := true

	for pair in _pairs():
		var baseline: Array = _states[pair[0]]
		var other: Array = _states[pair[1]]
		var run_worst := 0.0
		var run_identical := true
		for i in baseline.size():
			var a: Dictionary = baseline[i]
			var b: Dictionary = other[i]
			for key in ["x", "y", "rot"]:
				var delta: float = absf(float(a[key]) - float(b[key]))
				run_worst = maxf(run_worst, delta)
				if a[key] != b[key]:
					run_identical = false
		worst = maxf(worst, run_worst)
		identical = identical and run_identical
		print("run %d vs run %d: %s, max delta %s"
			% [pair[0], pair[1], "bit-identical" if run_identical else "DIVERGED",
				String.num(run_worst, 17)])

	# Group runs by identical outcome. "Non-deterministic" would be the wrong
	# word if the outcomes repeat on a fixed cycle — that is reproducible
	# behaviour that happens to depend on how many times the scene was rebuilt,
	# and it calls for a different fix than randomness would.
	var classes := _equivalence_classes()
	var top_spread := _top_spread()

	print("bodies per run     : %d" % (_states[0] as Array).size())
	print("expected           : every pair bit-identical, max delta 0")
	print("actual             : %s, max delta %s"
		% ["all bit-identical" if identical else "DIVERGENCE FOUND", String.num(worst, 17)])
	print("distinct outcomes  : %d across %d runs" % [classes.size(), _states.size()])
	for c in classes:
		print("  runs %s" % str(c))
	print("highest-body spread: %s px  (this is what a height-line rule reads)"
		% String.num(top_spread, 6))
	if identical:
		print("VERDICT            : DETERMINISTIC across scene rebuilds")
	elif classes.size() < _states.size():
		print("VERDICT            : REPRODUCIBLE but rebuild-order dependent — "
			+ "%d outcomes on a fixed cycle, not randomness" % classes.size())
	else:
		print("VERDICT            : NON-DETERMINISTIC — every run differs")

	var out_path := "user://determinism.json"
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		out_path = user_args[0]
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s" % out_path)
		return
	file.store_string(JSON.stringify({
		"seed": SEED,
		"runs": RUNS,
		"ticks": TOTAL_TICKS,
		"godot": Engine.get_version_info(),
		"identical_in_process": identical,
		"max_delta_in_process": worst,
		"distinct_outcomes": classes.size(),
		"equivalence_classes": classes,
		"top_spread": top_spread,
		"states": _states,
	}, "  "))
	file.close()
	print("wrote %s" % out_path)
