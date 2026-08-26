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


## A circular arrow, for reset. Drawn as an arc with a head on it rather than
## typed as ↺, which is the character that came out as a tofu box on the first
## build that shipped it.
static func draw_reset(item: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	var unit := size / 24.0
	var radius := 8.0 * unit
	var width := 2.6 * unit
	# An arc with a gap at the top right, so it reads as going round rather
	# than as a plain ring.
	item.draw_arc(at, radius, deg_to_rad(-55.0), deg_to_rad(250.0), 32, colour, width)
	# The head, at the open end of the arc, pointing the way round it goes.
	var tip_angle := deg_to_rad(-55.0)
	var tip := at + Vector2(cos(tip_angle), sin(tip_angle)) * radius
	item.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(4.2, -1.2) * unit,
		tip + Vector2(-1.6, -3.8) * unit,
		tip + Vector2(-0.6, 2.6) * unit,
	]), colour)


## A question mark, for help — again drawn, not typed. The hook is an arc and
## a stem; the dot below it is what makes it read as a question mark rather
## than as a hook at button size.
static func draw_help(item: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	var unit := size / 24.0
	var width := 2.6 * unit
	var head := at + Vector2(0.0, -4.5 * unit)
	# The curl over the top, open at the bottom left.
	item.draw_arc(head, 4.6 * unit, deg_to_rad(160.0), deg_to_rad(400.0), 24, colour, width)
	# The stem coming down out of the curl to just above the dot.
	item.draw_line(at + Vector2(0.6 * unit, -0.6 * unit),
		at + Vector2(0.6 * unit, 4.0 * unit), colour, width)
	item.draw_circle(at + Vector2(0.6 * unit, 8.0 * unit), 1.7 * unit, colour)


## A five-pointed star, drawn rather than typed — the glyph came out as a tofu
## box on the first build that shipped it, which is why nothing here is a
## character. Used on the survey lines and on the results panel, so both are
## saying the same thing in the same shape.
static func star(item: CanvasItem, at: Vector2, size: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI * 0.5 + float(i) * PI / 5.0
		var reach := size if i % 2 == 0 else size * 0.44
		points.append(at + Vector2(cos(angle), sin(angle)) * reach)
	item.draw_colored_polygon(points, colour)
