class_name Tools
extends RefCounted

## The three demolition verbs. Each one is a distinct way of acting on the
## structure, not a damage number with a different label — see CHARTER.md.
##
## Every tool costs one move regardless of which it is. They differ in what
## they do, not what they cost: the jackhammer is the scalpel, the wrecking
## ball converts height into sideways disaster, and explosives are the blunt
## shortcut that spends a move to do roughly what a well-placed cut would.

enum Kind { JACKHAMMER, WRECKING_BALL, EXPLOSIVE }

const ORDER: Array[Kind] = [Kind.JACKHAMMER, Kind.WRECKING_BALL, Kind.EXPLOSIVE]

const NAMES := {
	Kind.JACKHAMMER: "jackhammer",
	Kind.WRECKING_BALL: "wrecking ball",
	Kind.EXPLOSIVE: "explosive",
}

## Jackhammer: takes out the one block you point at, and nothing else.
const JACKHAMMER_REACH := 26.0

## Wrecking ball: a lateral shove through a horizontal band, swung in from
## whichever side you clicked nearer. Falls off with distance so it topples the
## near side rather than shunting the whole building sideways.
const BALL_BAND := 70.0
const BALL_RANGE := 420.0
const BALL_FORCE := 780.0
const BALL_LIFT := 0.18

## Explosive: radial impulse, and blocks very close to the charge are destroyed
## outright. Deliberately not strong enough to flatten a building on its own.
const BLAST_RADIUS := 120.0
const BLAST_FORCE := 640.0
const BLAST_SHATTER := 26.0


## Applies a tool at a point. Returns true if it actually did something —
## a move is only spent when the tool had an effect, so a misclick on empty
## sky costs nothing.
static func apply(kind: Kind, level: Level, at: Vector2) -> bool:
	match kind:
		Kind.JACKHAMMER:
			return _jackhammer(level, at)
		Kind.WRECKING_BALL:
			return _wrecking_ball(level, at)
		Kind.EXPLOSIVE:
			return _explosive(level, at)
	return false


static func _jackhammer(level: Level, at: Vector2) -> bool:
	var target: RigidBody2D = level.block_at(at, JACKHAMMER_REACH)
	if target == null:
		return false
	level.destroy(target)
	return true


static func _wrecking_ball(level: Level, at: Vector2) -> bool:
	# Swing in from the side the click is nearer to, so the ball travels
	# towards the structure rather than away from it.
	var centre := level.centre_x()
	var direction := 1.0 if at.x < centre else -1.0
	var hit := false
	for body in level.live_blocks():
		if absf(body.global_position.y - at.y) > BALL_BAND:
			continue
		var reach := absf(body.global_position.x - at.x)
		if reach > BALL_RANGE:
			continue
		var falloff := 1.0 - reach / BALL_RANGE
		var push := Vector2(direction, -BALL_LIFT).normalized()
		body.apply_impulse(push * BALL_FORCE * falloff * body.mass)
		hit = true
	return hit


static func _explosive(level: Level, at: Vector2) -> bool:
	var touched := false
	for body in level.live_blocks():
		var offset: Vector2 = body.global_position - at
		var distance := offset.length()
		if distance > BLAST_RADIUS:
			continue
		touched = true
		if distance < BLAST_SHATTER:
			level.destroy(body)
			continue
		var falloff := 1.0 - distance / BLAST_RADIUS
		# A floor on the distance keeps a charge placed on a block's centre
		# from producing a near-infinite direction vector.
		var push := offset.normalized() if distance > 1.0 else Vector2.UP
		body.apply_impulse(push * BLAST_FORCE * falloff * body.mass)
	return touched
