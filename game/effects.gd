class_name Effects
extends Node2D

## Shows what a tool just did.
##
## Purely cosmetic. Nothing here applies a force, moves a body or delays a
## move: the tool has already resolved by the time an effect starts drawing.
## That is deliberate and load-bearing — Solver replays this game thousands of
## times headlessly to verify levels, and an animation that changed the
## simulation would make every one of those verdicts a lie about the game the
## player gets.

const JACKHAMMER_TIME := 0.45
const EXPLOSIVE_TIME := 0.50
## How long a damage number hangs in the air after the blow that earned it.
const NUMBER_TIME := 0.70

## How the jackhammer reads: three blows, and how long the tool body is.
const JACKHAMMER_BLOWS := 3.0
const JACKHAMMER_BODY := 46.0

var _live: Array = []
var _numbers: Array = []
var _aim: Dictionary = {}


## Tool art, for the tools that are not objects in the world. The wrecking
## ball has none: it is a real body on a real chain, and drawing a second one
## over it would be a picture of a tool competing with the tool.
func play(kind: Tools.Kind, at: Vector2) -> void:
	if kind == Tools.Kind.WRECKING_BALL:
		return
	_live.append({"kind": kind, "at": at, "t": 0.0})
	queue_redraw()


## What a held tool would do if released now. The point of a hold is choosing
## how much to spend, which is only a choice if the difference is visible
## before letting go.
func aim(kind: Tools.Kind, at: Vector2, charge: float, from_left: bool) -> void:
	_aim = {"kind": kind, "at": at, "charge": charge, "left": from_left}
	queue_redraw()


func stop_aim() -> void:
	_aim = {}
	queue_redraw()


## Damage, floating up from wherever it actually landed. The ball decides that
## point by hitting something, so this is driven by Level's struck signal
## rather than by where the player tapped.
func number(at: Vector2, amount: int) -> void:
	# A held jackhammer lands a blow every fifth of a second on the same spot,
	# and separate numbers there overprint into an unreadable smear. Blows in
	# the same place add up into one number that climbs instead.
	for shown in _numbers:
		if shown["at"].distance_to(at) < 26.0 and shown["t"] < NUMBER_TIME * 0.7:
			shown["amount"] = int(shown["amount"]) + amount
			shown["t"] = 0.0
			queue_redraw()
			return
	# Several pieces struck at once — a charge, or a ball ploughing through a
	# bay — get their own numbers, stacked so they do not overprint either.
	_numbers.append({"at": at, "amount": amount, "t": 0.0, "row": _numbers.size()})
	queue_redraw()


## The damage that blow did, floating up from the impact. Durability is the
## number the whole game turns on, so a player should see it being spent
## rather than infer it from a colour.
func _draw_damage(at: Vector2, amount: int, progress: float) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var rise := 14.0 + 26.0 * progress
	var fade: float = 1.0 if progress < 0.5 else 1.0 - (progress - 0.5) / 0.5
	var text := "-%d" % amount
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x
	# Up and to the side: above the touch, because a fingertip covers what it
	# just hit, and clear of the tool art drawn straight above it.
	var origin := at + Vector2(30.0 - width * 0.5, -rise - 10.0)
	font.draw_string(get_canvas_item(), origin + Vector2(1.0, 1.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(0.0, 0.0, 0.0, fade * 0.6))
	font.draw_string(get_canvas_item(), origin, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(1.0, 0.88, 0.55, fade))


func _process(delta: float) -> void:
	if not _aim.is_empty():
		queue_redraw()
	if _live.is_empty() and _numbers.is_empty():
		return
	for effect in _live:
		effect["t"] += delta
	for number_shown in _numbers:
		number_shown["t"] += delta
	_live = _live.filter(func(e): return e["t"] < _duration(e["kind"]))
	_numbers = _numbers.filter(func(n): return n["t"] < NUMBER_TIME)
	queue_redraw()


func _duration(kind: Tools.Kind) -> float:
	match kind:
		Tools.Kind.JACKHAMMER:
			return JACKHAMMER_TIME
	return EXPLOSIVE_TIME


func _draw() -> void:
	if not _aim.is_empty():
		_draw_aim()
	for effect in _live:
		var progress: float = clampf(effect["t"] / _duration(effect["kind"]), 0.0, 1.0)
		match effect["kind"]:
			Tools.Kind.JACKHAMMER:
				_draw_jackhammer(effect["at"], progress)
			Tools.Kind.EXPLOSIVE:
				_draw_explosive(effect["at"], progress)
	# Last, so a number is never drawn under the tool art that earned it.
	for number_shown in _numbers:
		_draw_damage(
			number_shown["at"] - Vector2(0.0, float(number_shown["row"]) * 22.0),
			int(number_shown["amount"]),
			clampf(number_shown["t"] / NUMBER_TIME, 0.0, 1.0))


## The charge as it builds: how far the ball would be hauled back, or how far
## the blast would reach. Drawn as the thing itself rather than as a meter,
## because what a player wants to know is where it lands.
func _draw_aim() -> void:
	var at: Vector2 = _aim["at"]
	var strength := Tools.strength(float(_aim["charge"]))
	if _aim["kind"] == Tools.Kind.EXPLOSIVE:
		var radius := Tools.BLAST_RADIUS * strength
		draw_circle(at, radius, Color(1.0, 0.55, 0.20, 0.10))
		draw_arc(at, radius, 0.0, TAU, 40, Color(1.0, 0.72, 0.32, 0.75), 2.0, true)
		return

	# The ball: where the crane would haul it to, and the arc it would take.
	var side := -1.0 if _aim["left"] else 1.0
	var pivot := at + Vector2(0.0, -Level.BALL_CHAIN)
	var lift: float = Level.BALL_LIFTS[0] * clampf(strength, 0.2, 1.0)
	var start := pivot + Vector2(side * sin(lift), cos(lift)) * Level.BALL_CHAIN
	draw_line(pivot, start, Color(0.55, 0.57, 0.60, 0.55), 2.0)
	draw_arc(start, Level.BALL_RADIUS, 0.0, TAU, 20, Color(0.72, 0.75, 0.80, 0.8), 2.0, true)
	draw_arc(pivot, Level.BALL_CHAIN, PI * 0.5, PI * 0.5 + side * lift, 24,
		Color(0.72, 0.75, 0.80, 0.30), 2.0, true)


## The tool itself, hammering. Three blows into the point tapped, with the
## chisel visible above it and chips coming off the impact.
##
## Drawn above the touch rather than under it: a fingertip covers roughly a
## 50 px circle, and feedback hidden beneath it is feedback nobody sees — see
## the mobile-first module in AGENTS.md.
func _draw_jackhammer(at: Vector2, progress: float) -> void:
	var fade := 1.0 - pow(progress, 2.0)
	var punch: float = absf(sin(progress * PI * JACKHAMMER_BLOWS))
	var tip := at - Vector2(0.0, 6.0 + 16.0 * (1.0 - punch))
	var top := tip - Vector2(0.0, JACKHAMMER_BODY)

	# Chisel and body, straight down onto the block.
	draw_line(tip, top, Color(0.86, 0.62, 0.16, fade), 13.0)
	draw_line(tip, top + Vector2(0.0, 6.0), Color(1.0, 0.82, 0.35, fade), 5.0)
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-7.0, -2.0), tip + Vector2(7.0, -2.0), tip]),
		Color(0.78, 0.80, 0.84, fade))

	# The impact itself: a ring per blow, brightest at the moment of contact.
	var hit: float = 1.0 - punch
	var ring := 8.0 + 34.0 * progress
	draw_arc(at, ring, 0.0, TAU, 28, Color(1.0, 0.86, 0.45, fade * 0.9 * hit), 4.0, true)
	for i in 9:
		var angle := TAU * float(i) / 9.0 + progress * 0.7
		var inner := Vector2.RIGHT.rotated(angle) * (ring * 0.65)
		var outer := Vector2.RIGHT.rotated(angle) * (ring + 16.0 * progress)
		draw_line(at + inner, at + outer, Color(1.0, 0.93, 0.72, fade * hit), 2.5)


## A blast front expanding to the radius the charge actually reaches.
func _draw_explosive(at: Vector2, progress: float) -> void:
	var fade := 1.0 - progress
	var radius := Tools.BLAST_RADIUS * ease(progress, 0.35)
	draw_circle(at, radius, Color(1.0, 0.55, 0.20, fade * 0.22))
	draw_arc(at, radius, 0.0, TAU, 40, Color(1.0, 0.72, 0.32, fade), 4.0, true)
	draw_arc(at, radius * 0.6, 0.0, TAU, 32, Color(1.0, 0.93, 0.75, fade * 0.8), 2.0, true)
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var tip := at + Vector2.RIGHT.rotated(angle) * radius * (0.8 + 0.25 * progress)
		draw_line(at + Vector2.RIGHT.rotated(angle) * radius * 0.5, tip,
			Color(1.0, 0.80, 0.45, fade * 0.7), 2.0)
