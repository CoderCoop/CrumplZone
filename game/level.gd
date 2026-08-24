class_name Level
extends Node2D

## A structure, the rule it is judged by, and the physics that decides. No
## input, no UI, no scoring — main.gd wraps this for a player and playtest.gd
## drives it headlessly.
##
## That seam is deliberate. The charter's levels are generated and verified
## solvable before anyone plays them, which means a solver has to run this
## exact code thousands of times with nobody watching. Anything that assumes a
## human is present belongs in the wrapper, not here.

const DENSITY := 0.001

## A level is a plain dictionary so a generator can emit one later without
## touching this file:
##   {
##     "floor_y": float, "height_line": float,
##     "blocks": [ {"x","y","w","h","role"} ],   # role: "pillar" | "slab"
##     "moves": int,
##   }
var spec: Dictionary = {}
var blocks: Array[RigidBody2D] = []

const ROLE_COLOURS := {
	"pillar": Color(0.79, 0.45, 0.29),
	"slab": Color(0.62, 0.65, 0.71),
}

var _settled_ticks := 0
const SETTLE_SPEED := 6.0
const SETTLE_TICKS := 24


func build(level_spec: Dictionary) -> void:
	clear()
	spec = level_spec

	var material := PhysicsMaterial.new()
	material.friction = 0.85
	material.bounce = 0.0

	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.position = Vector2(spec.get("centre_x", 480.0), spec["floor_y"] + 24.0)
	var ground_shape := CollisionShape2D.new()
	var ground_rect := RectangleShape2D.new()
	ground_rect.size = Vector2(2400.0, 48.0)
	ground_shape.shape = ground_rect
	ground.add_child(ground_shape)
	ground.add_child(_visual(Vector2(2400.0, 48.0), Color(0.20, 0.22, 0.26)))
	add_child(ground)

	for b in spec["blocks"]:
		blocks.append(_make_block(
			Vector2(b["x"], b["y"]), Vector2(b["w"], b["h"]),
			ROLE_COLOURS.get(b.get("role", "pillar"), Color.WHITE), material))

	_settled_ticks = 0


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	blocks = []


func _make_block(pos: Vector2, size: Vector2, colour: Color,
		material: PhysicsMaterial) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.position = pos
	body.mass = size.x * size.y * DENSITY
	body.physics_material_override = material
	# Rubble moves fast enough to tunnel through the ground without this.
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.add_child(_visual(size, colour))
	body.set_meta("half", size * 0.5)
	add_child(body)
	return body


func _visual(size: Vector2, colour: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var half := size * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	poly.color = colour
	return poly


func live_blocks() -> Array[RigidBody2D]:
	var out: Array[RigidBody2D] = []
	for body in blocks:
		if is_instance_valid(body):
			out.append(body)
	return out


func destroy(body: RigidBody2D) -> void:
	if not is_instance_valid(body):
		return
	blocks.erase(body)
	remove_child(body)
	body.queue_free()


## The block under a point, in the body's own rotated frame so a toppled block
## is still hit where it actually lies. `slack` widens the target a little so
## a fingertip on a 22 px pillar is not a precision test — pillar 2 of the
## charter: reward insight, forgive imprecision.
func block_at(point: Vector2, slack: float) -> RigidBody2D:
	var best: RigidBody2D = null
	var best_distance := INF
	for body in live_blocks():
		var half: Vector2 = body.get_meta("half")
		var local: Vector2 = (point - body.global_position).rotated(-body.rotation)
		var overflow := Vector2(
			absf(local.x) - half.x - slack,
			absf(local.y) - half.y - slack)
		if overflow.x > 0.0 or overflow.y > 0.0:
			continue
		var distance := point.distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


func centre_x() -> float:
	return spec.get("centre_x", 480.0)


func height_line() -> float:
	return spec["height_line"]


## Blocks with any part still above the line. Measured from the block's
## extent, not its centre: a slab resting exactly on the line should not pass
## because its middle happens to sit below it.
func standing() -> int:
	var line: float = spec["height_line"]
	var count := 0
	for body in live_blocks():
		if _top_of(body) < line:
			count += 1
	return count


func _top_of(body: RigidBody2D) -> float:
	var half: Vector2 = body.get_meta("half")
	# Rotated half-extent: how far the corner reaches above the centre.
	var reach := absf(half.x * sin(body.rotation)) + absf(half.y * cos(body.rotation))
	return body.global_position.y - reach


func cleared() -> bool:
	return standing() == 0


## How far the highest remaining point sits below the line, in pixels.
## Positive means clear with room to spare; negative means something is above
## it. The solver ranks by this rather than by a bare pass/fail, because a
## result that clears by a hair is exactly the one physics can flip — see
## spikes/determinism/.
func clearance() -> float:
	var highest := INF
	for body in live_blocks():
		highest = minf(highest, _top_of(body))
	if highest == INF:
		return 9999.0
	return highest - spec["height_line"]


## True once nothing is moving meaningfully any more. Tracked over several
## ticks so a block at the top of a bounce does not read as at rest.
func tick_settle() -> bool:
	var moving := false
	for body in live_blocks():
		if body.linear_velocity.length() > SETTLE_SPEED:
			moving = true
			break
	if moving:
		_settled_ticks = 0
	else:
		_settled_ticks += 1
	return _settled_ticks >= SETTLE_TICKS


func reset_settle() -> void:
	_settled_ticks = 0


## Wakes every remaining block. Called whenever a tool changes the world.
##
## Godot's rigid bodies sleep once they settle, and deleting the body holding a
## sleeping one up does not reliably wake it: the stack above a cut block hung
## in mid-air indefinitely. That was the reported "I remove pieces and nothing
## happens".
##
## DO NOT remove this as dead code. No headless harness reproduces the bug —
## they drive physics directly and always see a normal collapse. It was found,
## and the fix confirmed, by clicking the exported web build in a real browser
## and watching for thirty seconds: without this the stack hangs and the count
## never changes; with it the building comes down.
func wake_all() -> void:
	for body in live_blocks():
		body.sleeping = false
