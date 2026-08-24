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

## Kept so older callers and the intro's tool swatches still resolve.
const ROLE_COLOURS := {
	"pillar": Color(0.40, 0.45, 0.52),
	"slab": Color(0.66, 0.67, 0.69),
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
			b.get("material", Materials.CONCRETE), material))

	_settled_ticks = 0


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	blocks = []


func _make_block(pos: Vector2, size: Vector2, made_of: String,
		material: PhysicsMaterial, integrity := -1) -> RigidBody2D:
	var spec := Materials.of(made_of)
	var body := RigidBody2D.new()
	body.position = pos
	body.mass = size.x * size.y * spec["density"]
	body.physics_material_override = material
	# Rubble moves fast enough to tunnel through the ground without this.
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var left: int = integrity if integrity > 0 else int(spec["integrity"])
	body.add_child(_visual(size, Materials.colour_at(made_of, left)))
	body.set_meta("half", size * 0.5)
	body.set_meta("material", made_of)
	body.set_meta("integrity", left)
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


## Damages a block. When its integrity runs out it comes apart; until then it
## visibly wears. Returns true if anything happened at all.
##
## This is what makes durability legible: hitting steel twice is a decision the
## player can see the result of, rather than a silent no-op.
func damage(body: RigidBody2D, amount: int) -> bool:
	if not is_instance_valid(body) or amount <= 0:
		return false
	var left: int = int(body.get_meta("integrity", 1)) - amount
	if left > 0:
		body.set_meta("integrity", left)
		_repaint(body, left)
		return true
	return shatter(body)


## Breaks a block into fragments, the way the explosive always did to whatever
## was closest. Glass showers; concrete and steel come apart in slabs.
##
## Nothing leaves the world: demolition turns big things into smaller things.
func shatter(body: RigidBody2D) -> bool:
	if not is_instance_valid(body):
		return false
	var made_of: String = body.get_meta("material", Materials.CONCRETE)
	var wanted: int = int(Materials.of(made_of)["pieces"])
	var produced := _split(body, made_of)
	if produced.is_empty():
		return false
	# A second pass turns halves into quarters for materials that shower.
	if wanted > 2:
		var finer: Array[RigidBody2D] = []
		for piece in produced:
			var more := _split(piece, made_of)
			if more.is_empty():
				finer.append(piece)
			else:
				finer.append_array(more)
		produced = finer
	return true


## Halves a block along its longer axis. Returns the fragments, or nothing if
## the block is already too small to be worth dividing.
func _split(body: RigidBody2D, made_of: String) -> Array[RigidBody2D]:
	var empty: Array[RigidBody2D] = []
	if not is_instance_valid(body):
		return empty
	var half: Vector2 = body.get_meta("half")
	var size := half * 2.0
	var along_x := size.x >= size.y
	if (size.x if along_x else size.y) < Materials.MIN_PIECE * 2.0:
		return empty

	var piece := Vector2(size.x * 0.5, size.y) if along_x else Vector2(size.x, size.y * 0.5)
	var offset := Vector2(piece.x * 0.5, 0.0) if along_x else Vector2(0.0, piece.y * 0.5)
	var physics: PhysicsMaterial = body.physics_material_override
	var origin := body.global_position
	var facing := body.rotation
	var velocity := body.linear_velocity
	var spin := body.angular_velocity

	destroy(body)

	var made: Array[RigidBody2D] = []
	for side in [-1.0, 1.0]:
		# Fragments are rubble: they do not carry the original's toughness.
		var chunk := _make_block(
			origin + (offset * side).rotated(facing), piece, made_of, physics, 1)
		# Tracked, or the win condition never sees the pieces and a chunk left
		# above the line counts for nothing.
		blocks.append(chunk)
		chunk.rotation = facing
		chunk.linear_velocity = velocity
		chunk.angular_velocity = spin
		# A nudge apart, so a break reads as a break rather than as one block
		# quietly becoming two in the same place.
		chunk.apply_impulse(Vector2(side, 0.0).rotated(facing) * 14.0 * chunk.mass)
		made.append(chunk)
	return made


func _repaint(body: RigidBody2D, integrity_left: int) -> void:
	var made_of: String = body.get_meta("material", Materials.CONCRETE)
	for child in body.get_children():
		if child is Polygon2D:
			(child as Polygon2D).color = Materials.colour_at(made_of, integrity_left)


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


## The world rectangle worth looking at: everything the level was built from,
## plus room for rubble to spread sideways and a strip of street below the
## footing. main.gd frames the camera on this, so a level that is taller or
## wider than another one is still fully on screen — including in portrait,
## where fitting it is the whole problem.
func frame() -> Rect2:
	var floor_y: float = spec.get("floor_y", 540.0)
	var rect := Rect2(Vector2(centre_x(), floor_y), Vector2.ZERO)
	for b in spec.get("blocks", []):
		var half := Vector2(b["w"], b["h"]) * 0.5
		var centre := Vector2(b["x"], b["y"])
		rect = rect.expand(centre - half)
		rect = rect.expand(centre + half)
	return rect.grow_individual(80.0, 46.0, 80.0, 78.0)


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
## Godot's docs on RigidBody2D.sleeping: a sleeping body "will not move and
## will not calculate forces until woken up by another body through, for
## example, a collision, or by using the apply_impulse() or apply_force()
## methods." Deleting a body is not on that list — nothing collides with the
## block above it, so it never learns its support has gone and hangs in
## mid-air indefinitely. That was the reported "I remove pieces and nothing
## happens", and it is total: every body in a settled level is asleep.
##
## Setting can_sleep = false on every block would also work, at the cost of
## never letting the simulation rest. Waking on change keeps sleeping's
## benefit and pays only when something actually happens.
##
## Guarded by waketest.gd, which asserts the mechanism rather than the symptom:
## the hanging itself does not reproduce headlessly, but "blocks are still
## asleep after a tool acted" does, and that is what the bug is made of.
func wake_all() -> void:
	for body in live_blocks():
		body.sleeping = false
