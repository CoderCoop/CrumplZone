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

## Jackhammer: shatters the one thing you point at, and nothing else. It does
## what the explosive does to whatever is closest, but precisely and with no
## collateral — the scalpel to the explosive's shortcut.
##
## Twelve damage a blow is the unit the 1-100 durability scale in materials.gd
## is written in: glass and brick go first time, a concrete slab takes two, a
## steel column three, and reinforced concrete would take nine — more than any
## level's budget, which is the point. The jackhammer is the tool you spend
## moves on when you know exactly which piece matters.
const JACKHAMMER_REACH := 30.0
const JACKHAMMER_DAMAGE := 12

## Wrecking ball: an actual mass on an actual chain. Tapping picks the point
## the bottom of its arc passes through; it is released from the side you
## tapped nearer and does whatever its momentum does when it arrives.
##
## There is no force applied to an area here and no damage number: the engine
## resolves the collisions, and the damage comes out of the momentum the ball
## is carrying at the moment it lands — see Level.swing.

## Explosive: radial impulse, and everything inside the radius takes damage
## falling off with distance. Deliberately not strong enough to flatten a
## building on its own.
##
## Sixty at the charge point takes out anything but reinforced concrete in one
## go, and two charges will do that — no piece is invincible, some are just
## a terrible use of a move.
const BLAST_RADIUS := 120.0
const BLAST_FORCE := 640.0
const BLAST_SHATTER := 30.0
const BLAST_DAMAGE := 60


## What one use of a tool does at its strongest point, on the 1-100 durability
## scale. The explosive falls off with distance, so this is what it does to
## whatever it is placed on. Used by the readout and the intro, so the numbers
## a player is shown are the numbers the game runs on.
static func damage_of(kind: Kind) -> int:
	match kind:
		Kind.JACKHAMMER:
			return JACKHAMMER_DAMAGE
		Kind.WRECKING_BALL:
			# What the ball carries at the bottom of its arc, from the swing
			# itself rather than from a constant: mass times sqrt(2 g L (1-cos)).
			var speed := sqrt(2.0 * 980.0 * Level.BALL_CHAIN
				* (1.0 - cos(Level.BALL_LIFTS[0])))
			return int(round(Level.BALL_MASS * speed / Level.BALL_MOMENTUM_PER_DAMAGE))
	return BLAST_DAMAGE


## Applies a tool at a point. Returns true if it actually did something —
## a move is only spent when the tool had an effect, so a misclick on empty
## sky costs nothing.
static func apply(kind: Kind, level: Level, at: Vector2) -> bool:
	var acted := false
	match kind:
		Kind.JACKHAMMER:
			acted = _jackhammer(level, at)
		Kind.WRECKING_BALL:
			acted = _wrecking_ball(level, at)
		Kind.EXPLOSIVE:
			acted = _explosive(level, at)
	# Waking lives here, not in each tool, so the game and the solver cannot
	# drift apart on it. A sleeping block does not notice its support is gone.
	if acted:
		level.wake_all()
	return acted


static func _jackhammer(level: Level, at: Vector2) -> bool:
	var target: RigidBody2D = level.block_at(at, JACKHAMMER_REACH)
	if target == null:
		return false
	return level.damage(target, JACKHAMMER_DAMAGE, at)


static func _wrecking_ball(level: Level, at: Vector2) -> bool:
	# Swung in from the side the tap is nearer to, so the ball travels towards
	# the structure rather than away from it.
	return level.swing(at, at.x < level.centre_x())


static func _explosive(level: Level, at: Vector2) -> bool:
	var touched := false
	for body in level.live_blocks().duplicate():
		if not is_instance_valid(body):
			continue
		var offset: Vector2 = body.global_position - at
		var distance := offset.length()
		if distance > BLAST_RADIUS:
			continue
		touched = true
		var falloff := 1.0 - distance / BLAST_RADIUS
		# Damaged, not deleted: the pieces stay and still have to end up below
		# the line. Damage falls off with distance, so a charge takes out what
		# it is placed on and cracks what stands around it.
		var force: int = BLAST_DAMAGE if distance < BLAST_SHATTER \
			else int(round(BLAST_DAMAGE * falloff))
		level.damage(body, force, at)
		if distance < BLAST_SHATTER:
			continue
		# A floor on the distance keeps a charge placed on a block's centre
		# from producing a near-infinite direction vector.
		var push := offset.normalized() if distance > 1.0 else Vector2.UP
		body.apply_impulse(push * BLAST_FORCE * falloff * body.mass)
	return touched
