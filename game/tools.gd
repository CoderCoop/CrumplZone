class_name Tools
extends RefCounted

## The three demolition verbs. Each one is a distinct way of acting on the
## structure, not a damage number with a different label — see CHARTER.md.
##
## Tools are used by holding: the jackhammer keeps chipping for as long as you
## hold it, and the ball and the charge build up while held and go on release.
## What they spend is power, not moves — a bar that drains as you work, so
## fifteen seconds of jackhammering and one big charge cost what they cost
## rather than counting as one thing each.
##
## `charge` runs 0 to 1 and is how long the hold lasted. It does nothing to the
## jackhammer, whose blows are blows; it hauls the ball further back, and it
## packs more into the charge.

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
## Power a single blow costs, and how often blows land while held.
const JACKHAMMER_POWER := 6.0
const JACKHAMMER_INTERVAL := 0.22

## Wrecking ball: an actual mass on an actual chain. Tapping picks the point
## the bottom of its arc passes through; it is released from the side you
## tapped nearer and does whatever its momentum does when it arrives.
##
## There is no force applied to an area here and no damage number: the engine
## resolves the collisions, and the damage comes out of the momentum the ball
## is carrying at the moment it lands — see Level.swing.

## Explosive: radial impulse, and everything inside the radius takes damage
## falling off with distance.
##
## A real shot charge does not politely crack what stands near it — it takes
## out a region. So the charge is severe inside a core that is a third of its
## reach, and falls off gently rather than linearly past that: at half the
## radius a linear falloff left half damage, and this leaves about two thirds.
## A full charge is 105 at the centre, which is past reinforced concrete's 100,
## so nothing survives being sat on.
##
## It costs accordingly — see HOLD, where the explosive is the expensive tool.
## The bar buys about five full charges rather than eight.
const BLAST_RADIUS := 155.0
const BLAST_FORCE := 950.0
const BLAST_SHATTER := 52.0
const BLAST_DAMAGE := 105
## How gently damage falls away past the core. Below 1 keeps it high further
## out; 1.0 would be the linear falloff this replaced.
const BLAST_FALLOFF := 0.6

## What a held tool costs: something for reaching for it at all, and the rest
## for how long you held. A tap is cheap and weak, a full hold is neither.
##
## Per tool, because they are not worth the same. The explosive takes out a
## region and everything in it; the ball takes out what it swings through. One
## full charge costs what nearly two full swings do.
const HOLD := {
	Kind.WRECKING_BALL: {"base": 10.0, "full": 20.0},
	Kind.EXPLOSIVE: {"base": 17.0, "full": 35.0},
}
const HOLD_BASE := 10.0
const HOLD_FULL := 20.0
## The weakest a charged tool gets. A tap is not nothing.
const CHARGE_FLOOR := 0.45


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


## What one use costs, at a given hold. Power is only actually spent when the
## tool did something, so a misfire into empty sky is free.
static func cost(kind: Kind, charge := 1.0) -> float:
	if kind == Kind.JACKHAMMER:
		return JACKHAMMER_POWER
	var held: Dictionary = HOLD.get(kind, {"base": HOLD_BASE, "full": HOLD_FULL})
	return float(held["base"]) + float(held["full"]) * clampf(charge, 0.0, 1.0)


## How much of a charged tool a hold delivers: never nothing, never more than
## all of it.
static func strength(charge: float) -> float:
	return CHARGE_FLOOR + (1.0 - CHARGE_FLOOR) * clampf(charge, 0.0, 1.0)


## Applies a tool at a point. Returns true if it actually did something —
## power is only spent when the tool had an effect, so a misfire on empty
## sky costs nothing.
static func apply(kind: Kind, level: Level, at: Vector2, charge := 1.0) -> bool:
	var acted := false
	match kind:
		Kind.JACKHAMMER:
			acted = _jackhammer(level, at)
		Kind.WRECKING_BALL:
			acted = _wrecking_ball(level, at, charge)
		Kind.EXPLOSIVE:
			acted = _explosive(level, at, charge)
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


static func _wrecking_ball(level: Level, at: Vector2, charge: float) -> bool:
	# Swung in from the side the tap is nearer to, so the ball travels towards
	# the structure rather than away from it. Holding hauls it further back,
	# which is more height, which is more speed at the bottom — the charge is
	# spent on the arc rather than on a damage multiplier.
	return level.swing(at, at.x < level.centre_x(), strength(charge))


static func _explosive(level: Level, at: Vector2, charge: float) -> bool:
	# A held charge is a bigger charge: more of it goes in, so it reaches
	# further and hits harder.
	var packed := strength(charge)
	var radius := BLAST_RADIUS * packed
	var core := BLAST_SHATTER * packed
	var touched := false
	for body in level.live_blocks().duplicate():
		if not is_instance_valid(body):
			continue
		var offset: Vector2 = body.global_position - at
		var distance := offset.length()
		if distance > radius:
			continue
		touched = true
		# Gentle rather than linear, so the charge does real damage across its
		# whole reach instead of only where it was placed.
		var falloff := pow(1.0 - distance / radius, BLAST_FALLOFF)
		# Damaged, not deleted: the pieces stay and still have to end up below
		# the line. Damage falls off with distance, so a charge takes out what
		# it is placed on and cracks what stands around it.
		var full := BLAST_DAMAGE * packed
		var force: int = int(round(full if distance < core else full * falloff))
		level.damage(body, force, at)
		if distance < core:
			continue
		# A floor on the distance keeps a charge placed on a block's centre
		# from producing a near-infinite direction vector.
		var push := offset.normalized() if distance > 1.0 else Vector2.UP
		body.apply_impulse(push * BLAST_FORCE * packed * falloff * body.mass)
	return touched
