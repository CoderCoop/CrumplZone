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
##
## Pieces are convex polygons, not rectangles. A level spec still describes
## rectangles because that is what a building is made of, but the moment
## something breaks it stops being one — see fracture.gd for why that matters
## more than it sounds.

## A level is a plain dictionary so a generator can emit one without touching
## this file:
##   {
##     "centre_x": float, "floor_y": float, "height_line": float,
##     "blocks": [ {"x","y","w","h","role","material"} ],
##     "moves": int,
##   }
## Emitted whenever a piece takes damage, at the point it was struck. The
## wrecking ball decides that point by hitting something, not by being told
## where the player tapped, so the readout has to hear about it rather than
## assume it.
signal struck(at: Vector2, amount: int)

var spec: Dictionary = {}
var blocks: Array[RigidBody2D] = []

var _rubble: PhysicsMaterial

var _settled_ticks := 0
const SETTLE_SPEED := 6.0
const SETTLE_TICKS := 24

## The wrecking ball: a real mass on a real chain, not a force applied to an
## area. It is spawned at the top of its arc, released, and does whatever its
## momentum does when it arrives — the collisions are the engine's, and so is
## everything the building does about them.
const BALL_RADIUS := 24.0
const BALL_MASS := 42.0
## A long chain swung from well over to the side. The first version used a
## short one, and the ball was released 134 px from the point tapped — which
## for anything but an edge tap is *inside the building*. It jammed against a
## pane the instant it appeared, never swung, and delivered 1 damage at 3 px/s.
## The arc has to start outside the structure to be an arc at all.
const BALL_CHAIN := 300.0
## Release angles from vertical, tried in order until the ball has somewhere to
## start. Steeper means further out and faster.
const BALL_LIFTS: Array[float] = [0.85, 1.05, 1.25]

## Damage per unit of momentum, and nothing else — how hard the ball is going
## when it arrives is the whole reason for swinging it from a height. A 42 kg
## ball reaches about 400 px/s at the bottom of its arc, which is 39 damage:
## through a concrete slab or a steel column in one, and never through the
## reinforced core. Clip something early in the swing and it lands at maybe
## 280 px/s for 27, which cracks a column without taking it out. Where in the
## arc you catch the building is a real difference, because the arc is real.
const BALL_MOMENTUM_PER_DAMAGE := 430.0
## How long the crane keeps the ball in play, and how long it lingers after it
## has done its work. Long enough for a full swing, short enough that a level
## still settles inside the solver's budget for one move.
const BALL_TICKS := 130
const BALL_LINGER := 26

var _ball: RigidBody2D
var _ball_pivot: StaticBody2D
var _ball_chain: Line2D
var _ball_life := 0
var _ball_struck: Array = []
var _ball_hit_once := {}


func build(level_spec: Dictionary) -> void:
	clear()
	spec = level_spec

	var material := PhysicsMaterial.new()
	material.friction = 0.85
	material.bounce = 0.0
	_rubble = PhysicsMaterial.new()
	# Broken faces are irregular and unbonded: they meet on a few points rather
	# than across a cast surface, and they slide over each other far more
	# readily than the intact member did. Without this a fracture that happened
	# to come out shallow would lock, and a broken column would carry its load
	# as if it were whole.
	_rubble.friction = 0.45
	_rubble.bounce = 0.0

	var ground := StaticBody2D.new()
	ground.name = "Ground"
	ground.position = Vector2(spec.get("centre_x", 480.0), spec["floor_y"] + 24.0)
	var ground_shape := CollisionShape2D.new()
	var ground_rect := RectangleShape2D.new()
	ground_rect.size = Vector2(2400.0, 48.0)
	ground_shape.shape = ground_rect
	ground.add_child(ground_shape)
	ground.add_child(_visual(Fracture.rectangle(Vector2(2400.0, 48.0)),
		Color(0.20, 0.22, 0.26)))
	add_child(ground)

	for b in spec["blocks"]:
		blocks.append(_make_piece(
			Vector2(b["x"], b["y"]),
			Fracture.rectangle(Vector2(b["w"], b["h"])),
			b.get("material", Materials.CONCRETE), material))

	_settled_ticks = 0


func clear() -> void:
	# The crane first, and by name rather than by freeing the node and hoping.
	# A rebuild frees every child, which leaves the ball reference pointing at
	# a freed instance — not null — so the next swing sees "one already in
	# play" and refuses. The solver rebuilds between every candidate sequence
	# and applies the first move before it ticks anything, so that refusal
	# landed on the first move of every sequence that opened with the ball.
	_clear_ball()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	blocks = []


func _make_piece(pos: Vector2, polygon: PackedVector2Array, made_of: String,
		material: PhysicsMaterial, durability := -1) -> RigidBody2D:
	var made := Materials.of(made_of)
	var body := RigidBody2D.new()
	body.position = pos
	body.mass = maxf(0.01, Fracture.area(polygon) * float(made["density"]))
	body.physics_material_override = material
	# Rubble moves fast enough to tunnel through the ground without this.
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	var shape := CollisionShape2D.new()
	var convex := ConvexPolygonShape2D.new()
	convex.points = polygon
	shape.shape = convex
	body.add_child(shape)
	body.add_child(_visual(polygon, Materials.colour_at(made_of, 0.0)))

	body.set_meta("poly", polygon)
	body.set_meta("material", made_of)
	body.set_meta("durability",
		durability if durability > 0 else Materials.durability(made_of))
	body.set_meta("damage", 0)
	add_child(body)
	return body


func _visual(polygon: PackedVector2Array, colour: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = polygon
	poly.color = colour
	return poly


func live_blocks() -> Array[RigidBody2D]:
	var out: Array[RigidBody2D] = []
	for body in blocks:
		if is_instance_valid(body):
			out.append(body)
	return out


## Damages a piece at a point. Once it has taken its durability in damage it
## comes apart; until then it cracks and darkens. Returns true if anything
## happened.
##
## Every blow lands visibly. A hit that only decremented a hidden counter is
## how this game has twice ended up telling a player nothing happened, so wear
## is drawn — see _repaint — and a blow on rubble that cannot be divided
## refuses instead of quietly charging a move for it.
func damage(body: RigidBody2D, amount: int, at: Vector2) -> bool:
	if not is_instance_valid(body) or amount <= 0:
		return false
	if not _divisible(body):
		# Rubble takes damage but has nothing left to break into, so a blow on
		# it would be a move spent on a colour change. Refuse it instead.
		return false
	struck.emit(at, amount)
	var taken: int = int(body.get_meta("damage", 0)) + amount
	var durability: int = int(body.get_meta("durability", 1))
	if taken < durability:
		body.set_meta("damage", taken)
		_repaint(body, float(taken) / float(maxi(1, durability)))
		return true
	return shatter(body, at)


## Breaks a piece apart around the point struck. Brittle material comes apart
## in slivers radiating from the impact; structural material parts on a sloped
## face, so the piece above slides off its own stump instead of standing on it.
##
## Nothing leaves the world: the fragments are the piece, and their areas add
## up to what it was.
func shatter(body: RigidBody2D, at: Vector2) -> bool:
	if not is_instance_valid(body) or not _divisible(body):
		return false
	var made_of: String = body.get_meta("material", Materials.CONCRETE)
	var made := Materials.of(made_of)
	var polygon: PackedVector2Array = body.get_meta("poly")

	# The impact in the piece's own frame, so the shards point at where the
	# blow actually landed rather than at where the piece happens to be.
	var local := (at - body.global_position).rotated(-body.rotation)
	var pieces := Fracture.fragments(polygon, local, int(made["pieces"]),
		bool(made.get("brittle", false)), Materials.MIN_AREA, _seed_for(body))
	if pieces.size() < 2:
		return false

	var origin := body.global_position
	var facing := body.rotation
	var velocity := body.linear_velocity
	var spin := body.angular_velocity
	# Half the piece, half the toughness. A fragment of steel is still steel,
	# but breaking a smaller piece of it is less work.
	var toughness: int = maxi(1, int(body.get_meta("durability", 1)) / 2)

	destroy(body)

	for shard in pieces:
		var middle := Fracture.centroid(shard)
		var centred := PackedVector2Array()
		for point in shard:
			centred.append(point - middle)
		var chunk := _make_piece(
			origin + middle.rotated(facing), centred, made_of, _rubble, toughness)
		# Tracked, or the win condition never sees the pieces and a fragment
		# left above the line counts for nothing.
		blocks.append(chunk)
		chunk.rotation = facing
		chunk.linear_velocity = velocity
		chunk.angular_velocity = spin
		# A nudge away from the break, so it reads as a break rather than as
		# one piece quietly becoming several in the same place.
		var away := middle.rotated(facing)
		if away.length() < 0.001:
			away = Vector2.UP
		chunk.apply_impulse(away.normalized() * 16.0 * chunk.mass)
	return true


## Deterministic per piece, so the same level rebuilt breaks the same way. The
## solver replays a level thousands of times; a fracture seeded from an
## instance id would differ on every rebuild and make its verdicts meaningless.
func _seed_for(body: RigidBody2D) -> int:
	var polygon: PackedVector2Array = body.get_meta("poly")
	var at := body.global_position
	return hash([
		String(body.get_meta("material", "")),
		int(round(at.x)), int(round(at.y)),
		int(round(Fracture.area(polygon)))])


## Is there anything left to break this into? False only for rubble already at
## the smallest size worth simulating.
func _divisible(body: RigidBody2D) -> bool:
	return Fracture.area(body.get_meta("poly")) >= Materials.MIN_AREA * 2.0


## Wear, drawn rather than counted: the piece darkens and gains cracks in
## proportion to the damage it has taken. A player has to be able to see that a
## blow landed on something that did not break, or the durability model reads
## as a broken game.
func _repaint(body: RigidBody2D, wear: float) -> void:
	var made_of: String = body.get_meta("material", Materials.CONCRETE)
	var polygon: PackedVector2Array = body.get_meta("poly")
	for child in body.get_children():
		if String(child.name).begins_with("crack"):
			body.remove_child(child)
			child.queue_free()
		elif child is Polygon2D:
			(child as Polygon2D).color = Materials.colour_at(made_of, wear)

	# A crack from the first blow, and more as it nears failing — the point is
	# that a blow never reads as nothing happening.
	var cracks := 1 + int(clampf(wear, 0.0, 1.0) * 4.0)
	for i in cracks:
		body.add_child(_crack(polygon, _seed_for(body) + i, i))


## A thin dark split running in from the edge towards the middle. Both ends lie
## inside a convex piece, so a crack never draws outside the shape it belongs
## to, and it is deterministic in the piece so it does not wander when redrawn.
func _crack(polygon: PackedVector2Array, salt: int, index: int) -> Polygon2D:
	var angle := float(absi(salt * 37 + index * 911) % 360) * (PI / 180.0)
	var out := Vector2(cos(angle), sin(angle))
	var span := Fracture.reach(polygon)
	# Walk in from beyond the edge until inside: the boundary along that
	# direction, without solving for it.
	var start := out * span
	for _step in 12:
		if Fracture._contains(polygon, start):
			break
		start *= 0.85
	var end := out.rotated(PI * 0.7) * span * 0.25
	var width: float = clampf(span * 0.09, 0.7, 2.6)
	var across := (end - start).orthogonal().normalized() * width

	var crack := Polygon2D.new()
	crack.name = "crack_%d" % index
	crack.polygon = PackedVector2Array([
		start + across, end + across * 0.35, end - across * 0.35, start - across])
	crack.color = Color(0.06, 0.06, 0.07, 0.75)
	return crack


func destroy(body: RigidBody2D) -> void:
	if not is_instance_valid(body):
		return
	blocks.erase(body)
	remove_child(body)
	body.queue_free()


## Swings a wrecking ball through a point: a heavy body on a pinned chain,
## released from the top of its arc so that the bottom of the swing is the
## point tapped. Everything after that is the physics engine's — what it hits,
## how hard, and what that does to the building.
##
## Returns false when there is nothing within reach of the arc. You cannot
## swing at empty sky, and a move is not spent trying.
func swing(at: Vector2, from_left: bool) -> bool:
	if _ball != null:
		return false
	if _nearest_distance(at) > BALL_CHAIN * 0.5:
		return false

	var pivot_at := at + Vector2(0.0, -BALL_CHAIN)
	var side := -1.0 if from_left else 1.0
	# Release from the first angle that leaves the ball somewhere to start.
	# Swinging from inside the building is not swinging.
	var start := Vector2.ZERO
	var clear := false
	for lift in BALL_LIFTS:
		start = pivot_at + Vector2(side * sin(lift), cos(lift)) * BALL_CHAIN
		if block_at(start, BALL_RADIUS + 6.0) == null:
			clear = true
			break
	if not clear:
		return false

	_ball_pivot = StaticBody2D.new()
	_ball_pivot.name = "CranePivot"
	_ball_pivot.position = pivot_at
	add_child(_ball_pivot)

	_ball_chain = Line2D.new()
	_ball_chain.width = 3.0
	_ball_chain.default_color = Color(0.55, 0.57, 0.60)
	_ball_chain.points = PackedVector2Array([pivot_at, start])
	add_child(_ball_chain)

	_ball = RigidBody2D.new()
	_ball.name = "WreckingBall"
	_ball.position = start
	_ball.mass = BALL_MASS
	_ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	_ball.contact_monitor = true
	_ball.max_contacts_reported = 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BALL_RADIUS
	shape.shape = circle
	_ball.add_child(shape)
	_ball.add_child(_ball_visual())
	add_child(_ball)

	var joint := PinJoint2D.new()
	joint.position = pivot_at
	add_child(joint)
	joint.node_a = _ball_pivot.get_path()
	joint.node_b = _ball.get_path()

	_ball.body_entered.connect(_on_ball_hit)
	_ball_life = BALL_TICKS
	_ball_struck = []
	_ball_hit_once = {}
	return true


func ball_in_play() -> bool:
	return _ball != null and is_instance_valid(_ball)


func _ball_visual() -> Node2D:
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 20:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 20.0) * BALL_RADIUS)
	circle.polygon = points
	circle.color = Color(0.22, 0.24, 0.28)
	var rim := Line2D.new()
	rim.width = 2.0
	rim.default_color = Color(0.62, 0.65, 0.70)
	rim.closed = true
	rim.points = points
	circle.add_child(rim)
	return circle


## Contacts arrive mid-step, while the physics server is flushing queries, so
## breaking a body here would be changing the world it is still reading.
## They are queued and applied on the next tick instead.
func _on_ball_hit(body: Node) -> void:
	if not (body is RigidBody2D) or _ball == null:
		return
	var piece := body as RigidBody2D
	if not blocks.has(piece) or _ball_hit_once.has(piece.get_instance_id()):
		return
	_ball_hit_once[piece.get_instance_id()] = true
	# Momentum, not a damage constant: how hard the ball is going when it
	# arrives is the whole point of swinging it from a height.
	var momentum := _ball.linear_velocity.length() * _ball.mass
	var amount: int = maxi(1, int(round(momentum / BALL_MOMENTUM_PER_DAMAGE)))
	_ball_struck.append({"body": piece, "amount": amount, "at": _ball.global_position})


func _advance_ball() -> void:
	if _ball == null:
		return
	if not is_instance_valid(_ball):
		_clear_ball()
		return

	for hit in _ball_struck:
		var piece: RigidBody2D = hit["body"]
		if is_instance_valid(piece):
			damage(piece, int(hit["amount"]), hit["at"])
	if not _ball_struck.is_empty():
		# It has done what it came for; let the contact play out, then lift it
		# clear so the level can settle.
		_ball_life = mini(_ball_life, BALL_LINGER)
		_ball_struck = []

	_ball_chain.points = PackedVector2Array([_ball_pivot.global_position, _ball.global_position])
	_ball_life -= 1
	if _ball_life <= 0:
		_clear_ball()


func _clear_ball() -> void:
	for node in [_ball, _ball_pivot, _ball_chain]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	for child in get_children():
		if child is PinJoint2D:
			remove_child(child)
			child.queue_free()
	_ball = null
	_ball_pivot = null
	_ball_chain = null
	_ball_struck = []
	_ball_hit_once = {}


func _nearest_distance(point: Vector2) -> float:
	var nearest := INF
	for body in live_blocks():
		nearest = minf(nearest, point.distance_to(body.global_position))
	return nearest


## The piece under a point, in its own rotated frame so a toppled piece is
## still hit where it actually lies. `slack` widens the target a little so a
## fingertip on a 22 px column is not a precision test — pillar 2 of the
## charter: reward insight, forgive imprecision.
func block_at(point: Vector2, slack: float) -> RigidBody2D:
	var best: RigidBody2D = null
	var best_distance := INF
	for body in live_blocks():
		var local: Vector2 = (point - body.global_position).rotated(-body.rotation)
		var polygon: PackedVector2Array = body.get_meta("poly")
		if not Fracture._contains(polygon, local) and _edge_distance(polygon, local) > slack:
			continue
		var distance := point.distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


func _edge_distance(polygon: PackedVector2Array, point: Vector2) -> float:
	var nearest := INF
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return nearest


func centre_x() -> float:
	return spec.get("centre_x", 480.0)


func height_line() -> float:
	return spec["height_line"]


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


## Pieces with any part still above the line. Measured from the piece's own
## outline, not its centre: a slab resting exactly on the line should not pass
## because its middle happens to sit below it.
func standing() -> int:
	var line: float = spec["height_line"]
	var count := 0
	for body in live_blocks():
		if _top_of(body) < line:
			count += 1
	return count


## The highest point of a piece, from its actual outline in its actual
## orientation.
func _top_of(body: RigidBody2D) -> float:
	var polygon: PackedVector2Array = body.get_meta("poly")
	var facing := body.rotation
	var highest := INF
	for point in polygon:
		highest = minf(highest, body.global_position.y + point.rotated(facing).y)
	return highest


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
## ticks so a piece at the top of a bounce does not read as at rest.
func tick_settle() -> bool:
	# The ball is a tool, not part of the structure, so it does not count
	# towards "everything has come to rest" — but nothing can be judged while
	# it is still on its way in either.
	_advance_ball()
	if _ball != null:
		_settled_ticks = 0
		return false

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


## Wakes every remaining piece. Called whenever a tool changes the world.
##
## Godot's docs on RigidBody2D.sleeping: a sleeping body "will not move and
## will not calculate forces until woken up by another body through, for
## example, a collision, or by using the apply_impulse() or apply_force()
## methods." Deleting a body is not on that list — nothing collides with the
## piece above it, so it never learns its support has gone and hangs in
## mid-air indefinitely. That was the reported "I remove pieces and nothing
## happens", and it is total: every body in a settled level is asleep.
##
## Setting can_sleep = false on every piece would also work, at the cost of
## never letting the simulation rest. Waking on change keeps sleeping's
## benefit and pays only when something actually happens.
##
## Guarded by waketest.gd, which asserts the mechanism rather than the symptom:
## the hanging itself does not reproduce headlessly, but "pieces are still
## asleep after a tool acted" does, and that is what the bug is made of.
func wake_all() -> void:
	for body in live_blocks():
		body.sleeping = false
