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


## A breaker held upright, chisel down, with chips coming off the point.
static func _jackhammer(item: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	var unit := size / 24.0
	var tip := at + Vector2(0.0, 8.0 * unit)
	item.draw_line(tip - Vector2(0.0, 6.0 * unit), at - Vector2(0.0, 9.0 * unit),
		colour, 5.0 * unit)
	item.draw_line(at - Vector2(5.0 * unit, 7.0 * unit),
		at - Vector2(-5.0 * unit, 7.0 * unit), colour, 3.0 * unit)
	item.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-3.5 * unit, -6.0 * unit), tip + Vector2(3.5 * unit, -6.0 * unit),
		tip]), colour)
	for side in [-1.0, 1.0]:
		item.draw_line(tip + Vector2(side * 4.0 * unit, -1.0 * unit),
			tip + Vector2(side * 8.0 * unit, 2.0 * unit), colour, 2.0 * unit)


## A ball on a chain, hanging from the corner.
static func _ball(item: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	var unit := size / 24.0
	var pivot := at + Vector2(-9.0 * unit, -10.0 * unit)
	var ball := at + Vector2(3.0 * unit, 4.0 * unit)
	item.draw_line(pivot, ball, colour, 2.0 * unit)
	item.draw_circle(ball, 6.0 * unit, colour)
	item.draw_line(pivot + Vector2(-2.0 * unit, 0.0), pivot + Vector2(4.0 * unit, 0.0),
		colour, 2.0 * unit)


## A charge with a lit fuse.
static func _explosive(item: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	var unit := size / 24.0
	var body := at + Vector2(0.0, 3.0 * unit)
	item.draw_circle(body, 7.0 * unit, colour)
	item.draw_line(body + Vector2(3.0 * unit, -6.0 * unit),
		body + Vector2(8.0 * unit, -11.0 * unit), colour, 2.0 * unit)
	# The spark: four short rays, so it reads as lit rather than as a handle.
	var spark := body + Vector2(8.0 * unit, -11.0 * unit)
	for i in 4:
		var angle := PI * 0.25 * float(i * 2)
		item.draw_line(spark + Vector2(cos(angle), sin(angle)) * 2.0 * unit,
			spark + Vector2(cos(angle), sin(angle)) * 5.0 * unit, colour, 1.6 * unit)
