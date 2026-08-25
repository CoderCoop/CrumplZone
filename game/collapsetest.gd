extends Node2D

## Two claims about the physics that a screenshot cannot settle.
##
##   godot --headless --fixed-fps 60 --path game res://collapsetest.tscn
##
## 1. A broken column stops holding things up. Halving a rectangle down the
##    middle leaves two rectangles that stack as well as the original did, so
##    the building above a cut column carried on standing as if nothing had
##    happened. A real fracture parts on a sloped face and the top slides off,
##    and that is what this measures: the slab above has to actually come down.
##
## 2. The wrecking ball is an object, not an area of effect. It exists as a
##    body with mass while it swings, nothing can be judged while it is in
##    play, the damage it does comes out of the momentum it is carrying, and
##    it leaves once it has done its work.

const COLUMN := Vector2(22.0, 120.0)
const SLAB := Vector2(140.0, 22.0)
const FLOOR_Y := 540.0
const SETTLE_LIMIT := 420

## How far the slab has to drop before "the column stopped carrying it" is a
## fair description. A slab that merely settles onto the stump moves a few px.
const FALL := 40.0

var _level: Level
var _failures: Array[String] = []
var _phase := "column"
var _ticks := 0
var _slab: RigidBody2D
var _slab_y := 0.0
var _ball_seen := false
var _ball_mass := 0.0
var _ball_start := Vector2.ZERO
var _ball_travel := 0.0
var _ball_top_speed := 0.0
var _ball_blocked_settle := false
var _damage_seen := 0
var _pieces_before := 0


func _ready() -> void:
	_level = Level.new()
	_level.struck.connect(func(_at: Vector2, amount: int) -> void:
		_damage_seen = maxi(_damage_seen, amount))
	add_child(_level)
	_start_column()


# --- 1. a broken column drops what it was carrying -------------------------

func _start_column() -> void:
	_level.build({
		"centre_x": 400.0, "floor_y": FLOOR_Y, "height_line": FLOOR_Y - 200.0,
		"blocks": [
			{"x": 400.0, "y": FLOOR_Y - COLUMN.y * 0.5,
				"w": COLUMN.x, "h": COLUMN.y, "material": Materials.STEEL},
			{"x": 400.0, "y": FLOOR_Y - COLUMN.y - SLAB.y * 0.5,
				"w": SLAB.x, "h": SLAB.y, "material": Materials.CONCRETE},
		],
		"moves": 3,
	})
	_slab = _level.live_blocks()[1]
	_slab_y = _slab.global_position.y

	# Three blows at mid-height: 36 damage, exactly a steel column's durability.
	var at := Vector2(400.0, FLOOR_Y - COLUMN.y * 0.5)
	for _i in 3:
		Tools.apply(Tools.Kind.JACKHAMMER, _level, at)
	_ticks = 0


func _finish_column() -> void:
	var dropped := _slab.global_position.y - _slab_y if is_instance_valid(_slab) else 9999.0
	# The slab may itself have broken on landing; then the lowest piece of it
	# is the honest measure of where it ended up.
	var lowest := -INF
	for body in _level.live_blocks():
		lowest = maxf(lowest, body.global_position.y)
	print("column      slab started at y=%.0f, ended at y=%.0f (%.0f px down); "
		% [_slab_y, _slab_y + dropped, dropped]
		+ "lowest piece y=%.0f" % lowest)
	if dropped < FALL:
		_failures.append(
			"a column broken in half still carried the slab: it dropped %.0f px, "
			% dropped + "expected more than %.0f" % FALL)


# --- 2. the ball is a real body --------------------------------------------

func _start_ball() -> void:
	var blocks: Array = []
	for i in 3:
		blocks.append({
			"x": 340.0 + i * 60.0, "y": FLOOR_Y - COLUMN.y * 0.5,
			"w": COLUMN.x, "h": COLUMN.y, "material": Materials.CONCRETE})
	var spec := {
		"centre_x": 400.0, "floor_y": FLOOR_Y, "height_line": FLOOR_Y - 200.0,
		"blocks": blocks, "moves": 3,
	}
	var at := Vector2(400.0, FLOOR_Y - COLUMN.y * 0.5)

	# Swing, then rebuild with the ball still in play and swing again without
	# ticking in between — exactly what the solver does between candidate
	# sequences. A rebuild frees the ball's node but leaves the reference
	# pointing at a freed instance rather than at null, and the next swing then
	# refuses because it believes one is already out there. That cost the first
	# move of every searched sequence that opened with the ball, silently.
	_level.build(spec)
	var first := Tools.apply(Tools.Kind.WRECKING_BALL, _level, at)
	_level.build(spec)
	var second := Tools.apply(Tools.Kind.WRECKING_BALL, _level, at)
	print("ball        swing on a fresh level: %s, again after a rebuild: %s"
		% [first, second])
	if not first:
		_failures.append("the ball refused to swing at a standing building")
	if not second:
		_failures.append("the ball would not swing as the first move after a rebuild")

	_pieces_before = _level.live_blocks().size()
	_damage_seen = 0

	# It has to be a body, with a mass, in the level — not a force applied to
	# an area and forgotten.
	for child in _level.get_children():
		if child is RigidBody2D and String(child.name) == "WreckingBall":
			_ball_seen = true
			_ball_mass = (child as RigidBody2D).mass
			_ball_start = (child as RigidBody2D).global_position
	_ball_blocked_settle = not _level.tick_settle()
	_ball_travel = 0.0
	_ball_top_speed = 0.0
	_ticks = 0


func _finish_ball() -> void:
	var still_there := false
	for child in _level.get_children():
		if child is RigidBody2D and String(child.name) == "WreckingBall":
			still_there = true
	var pieces := _level.live_blocks().size()
	print("ball        mass %.0f, swung %.0f px reaching %.0f px/s, damage dealt %d, "
		% [_ball_mass, _ball_travel, _ball_top_speed, _damage_seen]
		+ "pieces %d → %d, cleared away: %s" % [_pieces_before, pieces, not still_there])

	if not _ball_seen:
		_failures.append("no wrecking ball body existed after swinging one")
	if _ball_mass < 10.0:
		_failures.append("the ball weighs %.0f — it is meant to be a heavy object"
			% _ball_mass)
	if not _ball_blocked_settle:
		_failures.append("the level reported itself settled with the ball still swinging")
	if _ball_travel < 60.0:
		_failures.append("the ball travelled %.0f px — it is stuck, not swinging"
			% _ball_travel)
	if _ball_top_speed < 200.0:
		_failures.append("the ball only reached %.0f px/s — it never got up any momentum"
			% _ball_top_speed)
	if _damage_seen <= 0:
		_failures.append("the ball swung through the building without damaging anything")
	if pieces <= _pieces_before:
		_failures.append("the ball broke nothing: %d pieces before, %d after"
			% [_pieces_before, pieces])
	if still_there:
		_failures.append("the ball never left, so the level can never settle")


func _physics_process(_delta: float) -> void:
	if _phase == "done":
		return
	_ticks += 1
	if _phase == "ball":
		# The first version of the swing released the ball 134 px from the tap,
		# which for a central tap is inside the building: it jammed on a pane,
		# never swung, and delivered 1 damage at 3 px/s while still looking
		# like a working tool from the outside. This is what would have caught
		# that.
		for child in _level.get_children():
			if child is RigidBody2D and String(child.name) == "WreckingBall":
				var ball := child as RigidBody2D
				_ball_travel = maxf(_ball_travel, _ball_start.distance_to(ball.global_position))
				_ball_top_speed = maxf(_ball_top_speed, ball.linear_velocity.length())
	var settled := _level.tick_settle()
	if not settled and _ticks < SETTLE_LIMIT:
		return

	match _phase:
		"column":
			_finish_column()
			_phase = "ball"
			_start_ball()
		"ball":
			_finish_ball()
			_phase = "done"
			_report()


func _report() -> void:
	print("")
	print("expected : a column broken in half drops what it was carrying, and")
	print("           the wrecking ball is a body with mass that damages what")
	print("           it hits and then leaves")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
