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
## A full charge is 85 at the centre. It was 105, which is past reinforced
## concrete's 100 — and that quietly deleted the one piece a level is built to
## be brought down *around*: one charge took the core out, and one charge
## cleared the whole hard level, 176 px of rubble under a 204 px line. Eighty
## five destroys steel, concrete, brick and glass where it lands and still
## needs two goes at a reinforced core.
##
## It costs accordingly — see HOLD, where the explosive is the expensive tool.
## The bar buys about five full charges rather than eight.
const BLAST_RADIUS := 110.0
const BLAST_SHATTER := 52.0
const BLAST_DAMAGE := 85
## How gently damage falls away past the core. Below 1 keeps it high further
## out; 1.0 would be the linear falloff this replaced.
const BLAST_FALLOFF := 0.6

## What the blast throws with, per unit of the piece's area.
##
## Per area, not per piece, because that is what a blast does: the pressure
## wave pushes on the face it meets, so what it delivers is proportional to
## how much of the piece is facing it. A piece's mass is its area times its
## density, so an impulse proportional to area leaves a velocity proportional
## to 1 over density — light things fly and dense things shift, and how far a
## thing goes says what it is made of.
##
## What this replaced was `impulse * body.mass`, which cancels the mass out
## again: apply_impulse divides by mass, so every piece in the radius left at
## exactly the same speed whatever it was and whatever it weighed. A pane of
## glass and a reinforced core departed together, which is why the charge read
## as a uniform nudge rather than as an explosion.
##
## Densities run 0.0003 for sheeting to 0.0019 for reinforced concrete, so the
## lightest thing here leaves about six times faster than the heaviest. That
## is a spread you can see and it is bounded — throwing by raw mass instead
## would have spanned two orders of magnitude and put small debris through the
## far wall.
const BLAST_THROW := 1.5

## How sharply the throw falls away with distance, against BLAST_FALLOFF for
## damage. Above 1 concentrates it near the charge, which is the opposite of
## what damage wants: damage is deliberately gentle so a charge cracks what
## stands around it, while a blast that shoved everything in a 155 px circle
## equally hard would look like a bubble rather than a detonation.
const BLAST_THROW_FALLOFF := 1.5

## How far off centre the throw lands, as a share of the piece's own reach.
##
## A blast arrives at a face, not at the centre of mass, so it spins what it
## hits. Applied dead centre — which is what apply_impulse does with no
## position — nothing rotates at all, and debris travelling outward without
## tumbling reads as cards being slid rather than a building coming apart.
##
## Across the push, not along it. Written first as an offset toward the
## charge, which is where the pressure does arrive and which produces exactly
## no torque: the arm and the impulse were antiparallel, so their cross
## product was zero and the measured spin was a column of 0.0 rad/s. What
## actually spins a piece is that the face the blast lands on is not centred
## on its mass, and that is a sideways offset.
##
## The offset is drawn from the piece's own seed rather than at random. The
## solver rebuilds a level thousands of times and replaytest asserts that a
## rebuild breaks the same way; a blast that span pieces differently each run
## would make every verdict it reaches meaningless.
const BLAST_SPIN := 0.55

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
	# Damage first, throw second, in two passes over the whole radius.
	#
	# It was one pass, and the order in it is most of why a charge read as
	# damage rather than as a detonation. A blast applied to a building that
	# is still standing is applied to bodies wedged against each other, and
	# the contact solver eats nearly all of it: measured, raising the throw
	# from 0.85 to 16.0 — nineteen times — moved the median speed of a thrown
	# piece from 9 to 27 px/s. The impulse was never the limit.
	#
	# What moves is a piece that is free to move, and a piece becomes free
	# when the charge breaks it out of the structure. So everything in reach
	# is damaged and shattered first, and then the throw is applied to what is
	# there afterwards — which includes the fragments the shatter just made,
	# and they are the debris a blast is supposed to send outward.
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
		level.damage(body,
			int(round(full if distance < core else full * falloff)), at)

	if not touched:
		return false

	# Everything still in reach, fragments included, sent outward.
	#
	# The push used to be skipped for anything within the core radius — a
	# `continue` sat above it — so the pieces closest to the charge, the ones
	# that should go furthest, were the only ones the blast never moved. They
	# were shattered instead, and shatter gives its fragments a flat nudge of
	# 16 per unit mass, which next to a real blast is nothing.
	for body in level.live_blocks().duplicate():
		if not is_instance_valid(body):
			continue
		var offset: Vector2 = body.global_position - at
		var distance := offset.length()
		if distance > radius:
			continue
		# A floor on the distance keeps a charge placed on a block's centre
		# from producing a near-infinite direction vector.
		var push := offset.normalized() if distance > 1.0 else Vector2.UP
		var thrown: float = BLAST_THROW * packed \
			* pow(1.0 - distance / radius, BLAST_THROW_FALLOFF) \
			* _area_of(body)
		var lean: float = float(int(body.get_meta("seed", 0)) % 2000 - 1000) \
			/ 1000.0
		body.apply_impulse(push * thrown,
			push.orthogonal() * _reach_of(body) * BLAST_SPIN * lean)
	return touched


## How much of a piece the blast has to push on.
##
## Read back from the body rather than carried alongside it: mass is area
## times density, and both are already on the piece.
static func _area_of(body: RigidBody2D) -> float:
	var made := Materials.of(String(body.get_meta("material", Materials.CONCRETE)))
	var density := float(made["density"])
	if density <= 0.0:
		return body.mass
	return body.mass / density


## Roughly how far a piece reaches from its own centre, for deciding where off
## centre the throw lands. Taken from the area rather than the polygon so that
## a fragment of any shape gives an answer in the right order of magnitude.
static func _reach_of(body: RigidBody2D) -> float:
	return sqrt(maxf(_area_of(body), 1.0)) * 0.5
