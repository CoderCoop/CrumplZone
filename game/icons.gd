class_name Icons
extends RefCounted

## Tool icons, drawn rather than typed.
##
## Not a font: the default font has no jackhammer in it, and the two symbols
## this game did try to type — a reset arrow and a star — both came out as tofu
## boxes on the first build that shipped them. Vector art costs a few draw
## calls and renders the same everywhere.
##
## Each icon is drawn to fit a box, so the same code serves a 66 px button on a
## phone and a bigger one on a desktop.


static func draw_tool(item: CanvasItem, kind: Tools.Kind, at: Vector2,
		size: float, colour: Color) -> void:
	match kind:
		Tools.Kind.JACKHAMMER:
			_jackhammer(item, at, size, colour)
		Tools.Kind.WRECKING_BALL:
			_ball(item, at, size, colour)
		Tools.Kind.EXPLOSIVE:
			_explosive(item, at, size, colour)


## A pneumatic breaker: T-handle at the top, body, chisel at the point, and
## chips coming off it. The first version was a stick with a triangle on the
## end and read as a nail.
static func _jackhammer(item: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	var unit := size / 24.0
	var top := at + Vector2(0.0, -11.0 * unit)
	var tip := at + Vector2(0.0, 9.0 * unit)

	# Handle bar and the two grips coming down from it.
	item.draw_line(top + Vector2(-7.0 * unit, 0.0), top + Vector2(7.0 * unit, 0.0),
		colour, 2.6 * unit)
	for side in [-1.0, 1.0]:
		item.draw_line(top + Vector2(side * 6.0 * unit, 0.0),
			top + Vector2(side * 4.0 * unit, 4.0 * unit), colour, 2.0 * unit)
	# Body, tapering to the chisel.
	item.draw_line(top + Vector2(0.0, 1.0 * unit), tip - Vector2(0.0, 5.0 * unit),
		colour, 6.5 * unit)
	item.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-3.0 * unit, -5.0 * unit), tip + Vector2(3.0 * unit, -5.0 * unit),
		tip]), colour)
	# Chips, so it reads as working rather than as parked.
	for side in [-1.0, 1.0]:
		item.draw_line(tip + Vector2(side * 5.0 * unit, -1.0 * unit),
			tip + Vector2(side * 9.0 * unit, 1.5 * unit), colour, 1.8 * unit)


## A wrecking ball on a real chain: links rather than a line, hung from a hook,
## with the ball heavy at the bottom of it.
static func _ball(item: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	var unit := size / 24.0
	var hook := at + Vector2(-8.0 * unit, -12.0 * unit)
	var ball := at + Vector2(4.0 * unit, 5.0 * unit)

	# The hook the chain hangs from.
	item.draw_line(hook + Vector2(-3.0 * unit, 0.0), hook + Vector2(3.0 * unit, 0.0),
		colour, 2.0 * unit)
	# Chain links, drawn as a run of short segments so it reads as chain.
	var links := 4
	for i in links:
		var from := hook.lerp(ball, float(i) / float(links))
		var to := hook.lerp(ball, (float(i) + 0.62) / float(links))
		item.draw_line(from, to, colour, 2.2 * unit)
	item.draw_circle(ball, 7.0 * unit, colour)


## A bundle of dynamite with a lit fuse — three sticks bound together, which
## reads at button size where a plain sphere reads as a full stop.
static func _explosive(item: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	var unit := size / 24.0
	var base := at + Vector2(-1.0 * unit, 4.0 * unit)
	# Three sticks, the middle one standing proudest.
	for i in 3:
		var offset := (float(i) - 1.0) * 5.2 * unit
		var height := 15.0 * unit if i == 1 else 12.5 * unit
		item.draw_line(base + Vector2(offset, 0.0),
			base + Vector2(offset, -height), colour, 4.2 * unit)
	# The band around them.
	item.draw_line(base + Vector2(-8.0 * unit, -5.0 * unit),
		base + Vector2(8.0 * unit, -5.0 * unit), colour.darkened(0.35), 2.4 * unit)
	# Fuse, curling up and away, and the spark on the end of it.
	var fuse := base + Vector2(0.0, -15.0 * unit)
	item.draw_line(fuse, fuse + Vector2(4.0 * unit, -4.0 * unit), colour, 1.8 * unit)
	var spark := fuse + Vector2(5.0 * unit, -5.5 * unit)
	for i in 4:
		var angle := PI * 0.25 * float(i * 2)
		item.draw_line(spark + Vector2(cos(angle), sin(angle)) * 1.6 * unit,
			spark + Vector2(cos(angle), sin(angle)) * 4.2 * unit, colour, 1.5 * unit)
