extends Node2D

## What does the stress model's "load" actually measure?
##
##   godot --headless --fixed-fps 60 --path game res://stackprobe.tscn
##
## level.gd judges a piece by the sum of the magnitudes of every contact
## impulse on it. That number is used as "what this piece is carrying" and
## compared against a per-material tolerance. Whether those are the same thing
## has never been checked, and 27.7% of all pieces in all buildings currently
## read over tolerance standing still — including buildings that have shipped
## for weeks.
##
## So: a plain stack of identical blocks, where what each one carries is known
## exactly. Block 0 is on top and carries nothing but itself. Block k carries k
## blocks above it. If the metric measures load, it should track that. If it
## sums both sides of a piece in equilibrium, it should read about twice it.
## Either way the answer is arithmetic, not opinion.

const BLOCKS := 8
const BLOCK := Vector2(40.0, 20.0)
const SETTLE := 240

var _level: Level
var _ticks := 0


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	var blocks: Array = []
	# Stacked from the street up, a hair apart so they settle into contact
	# rather than starting interpenetrated.
	for i in BLOCKS:
		blocks.append({
			"x": 400.0, "y": 540.0 - BLOCK.y * 0.5 - float(i) * (BLOCK.y + 0.5),
			"w": BLOCK.x, "h": BLOCK.y,
			"material": Materials.CONCRETE, "role": "post",
		})
	_level.build({
		"centre_x": 400.0, "floor_y": 540.0, "height_line": 100.0,
		"power": 100.0, "moves": 1, "blocks": blocks,
	})


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_level.tick_settle()
	if _ticks < SETTLE:
		return
	_report()


func _report() -> void:
	var gravity := float(ProjectSettings.get_setting(
		"physics/2d/default_gravity", 980.0))
	var step := 1.0 / 60.0
	var bodies := _level.live_blocks()
	# Top of the stack first, so "blocks above" counts up with the row number.
	bodies.sort_custom(func(a: RigidBody2D, b: RigidBody2D) -> bool:
		return a.global_position.y < b.global_position.y)
	var one_weight := 0.0
	if not bodies.is_empty():
		one_weight = bodies[0].mass * gravity * step
	print("")
	print("a stack of %d identical blocks, %dx%d concrete" % [
		BLOCKS, int(BLOCK.x), int(BLOCK.y)])
	print("one block's weight as a per-step impulse: %.2f" % one_weight)
	print("")
	print("row  above  expected carried  measured sum  contacts  ratio to carried")
	for i in bodies.size():
		var body := bodies[i]
		var state := PhysicsServer2D.body_get_direct_state(body.get_rid())
		if state == null:
			continue
		var total := 0.0
		for c in state.get_contact_count():
			total += state.get_contact_impulse(c).length()
		# What it holds up: everything above it, plus itself where it bears.
		var carried := float(i) * one_weight
		var ratio := 0.0 if carried <= 0.0 else total / carried
		print("%3d  %5d  %16.1f  %12.1f  %8d  %s" % [
			i, i, carried, total, state.get_contact_count(),
			"n/a (carries nothing)" if carried <= 0.0 else "%.2fx" % ratio])
	print("")
	print("concrete tolerates %.0f standing still (STRESS %.0f x REST %.1f)" % [
		Materials.rest_limit(Materials.CONCRETE),
		Materials.STRESS[Materials.CONCRETE],
		Materials.REST_TOLERANCE[Materials.CONCRETE]])
	print("measurement only — no verdict")
	get_tree().quit()
