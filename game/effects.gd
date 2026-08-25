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
const BALL_TIME := 0.45

## How the jackhammer reads: three blows, and how long the tool body is.
const JACKHAMMER_BLOWS := 3.0
const JACKHAMMER_BODY := 46.0

## Where the wrecking ball swings from, relative to the point struck.
const BALL_ARC := 190.0
const BALL_RADIUS := 26.0

var _live: Array = []


func play(kind: Tools.Kind, at: Vector2, from_left: bool) -> void:
	_live.append({"kind": kind, "at": at, "t": 0.0, "left": from_left})
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
	if _live.is_empty():
		return
	for effect in _live:
		effect["t"] += delta
	_live = _live.filter(func(e): return e["t"] < _duration(e["kind"]))
	queue_redraw()


func _duration(kind: Tools.Kind) -> float:
	match kind:
		Tools.Kind.JACKHAMMER:
			return JACKHAMMER_TIME
		Tools.Kind.EXPLOSIVE:
			return EXPLOSIVE_TIME
	return BALL_TIME


func _draw() -> void:
	for effect in _live:
		var progress: float = clampf(effect["t"] / _duration(effect["kind"]), 0.0, 1.0)
		match effect["kind"]:
			Tools.Kind.JACKHAMMER:
				_draw_jackhammer(effect["at"], progress)
			Tools.Kind.WRECKING_BALL:
				_draw_ball(effect["at"], progress, effect["left"])
			Tools.Kind.EXPLOSIVE:
				_draw_explosive(effect["at"], progress)
		# Last, so the number is never drawn under the tool that made it.
		_draw_damage(effect["at"], Tools.damage_of(effect["kind"]), progress)


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


## The ball swings in along an arc and stops where it struck.
func _draw_ball(at: Vector2, progress: float, from_left: bool) -> void:
	var side := -1.0 if from_left else 1.0
	# Eased so it accelerates into the hit rather than gliding at one speed.
	var swing := 1.0 - pow(1.0 - progress, 3.0)
	var angle := lerpf(PI * 0.55, 0.0, swing)
	var pivot := at + Vector2(side * BALL_ARC * 0.35, -BALL_ARC)
	var ball := pivot + Vector2(side * sin(angle) * BALL_ARC * 0.9, cos(angle) * BALL_ARC)
	var fade: float = 1.0 if progress < 0.75 else 1.0 - (progress - 0.75) / 0.25

	draw_line(pivot, ball, Color(0.55, 0.57, 0.60, fade), 3.0)
	draw_circle(ball, BALL_RADIUS, Color(0.22, 0.24, 0.28, fade))
	draw_arc(ball, BALL_RADIUS, 0.0, TAU, 28, Color(0.62, 0.65, 0.70, fade), 2.0, true)
	# A flash at the point of contact once the swing lands.
	if progress > 0.62:
		var flash := (progress - 0.62) / 0.38
		draw_arc(at, 10.0 + flash * 40.0, 0.0, TAU, 28,
			Color(1.0, 0.85, 0.55, (1.0 - flash) * 0.8), 3.0, true)


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
