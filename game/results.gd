class_name Results
extends CanvasLayer

## What you get at the end of a level: whether it came down, how much of the
## bar you had left, and a rating out of three.
##
## Stars are drawn rather than typed. The default font has no star glyph and
## renders a tofu box for one — the same trap that put a box where the reset
## button's symbol was meant to be.

signal again_pressed
signal next_level_pressed

const STARS := 3

## The rating is what the run cost: a third of the bar or less is three stars,
## under two thirds is two, and clearing it at all is one.
##
## Against the bar rather than against par, because the par the solver
## measured could not be trusted — see Levels.THREE_STAR_SHARE.

const MARGIN := 16.0
const BUTTON_HEIGHT := 56.0
const BRIGHT := Color(0.94, 0.95, 0.97)
const DIM := Color(0.62, 0.66, 0.72)
const GOLD := Color(0.97, 0.78, 0.32)
const EMPTY := Color(0.30, 0.32, 0.37)
const ACCENT := Color(0.95, 0.45, 0.35)

var cleared := false
var stars := 0
var power_left := 0.0
var power_full := 1.0
var standing := 0
## What the run cost, and what it had to spend. A rating means nothing
## without the number it was measured against.
var spent := 0.0
var bar := 1.0

var _root: Control
var _shade: ColorRect
var _title: Label
var _line: Label
var _note: Label
var _stars: Control
var _again: Button
var _next: Button


func _ready() -> void:
	layer = 12

	_root = Control.new()
	add_child(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shade = ColorRect.new()
	_shade.color = Color(0.07, 0.08, 0.11, 0.88)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_shade)

	# Positioned by hand rather than stacked in a container. Every container
	# in this project has at some point collapsed to its content's minimum
	# size and taken its contents off the screen with it — the intro's Play
	# button, the tool row, and this panel, which showed nothing but its own
	# button the first time it ran.
	_title = _label(_headline(), 34, BRIGHT if cleared else ACCENT)
	_root.add_child(_title)

	if cleared:
		_stars = Control.new()
		_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stars.draw.connect(_draw_stars)
		_root.add_child(_stars)
		_line = _label("%d%% of the bar left"
			% int(round(power_left / maxf(1.0, power_full) * 100.0)), 18, DIM)
		_note = _label(_advice(), 15, DIM, true)
	else:
		_line = _label("%d piece%s still standing"
			% [standing, "" if standing == 1 else "s"], 18, DIM)
		_note = _label(
			"Nothing is deleted, so everything you break still has to end up "
			+ "down there. Bringing the building down beats grinding it away.",
			15, DIM, true)
	_root.add_child(_line)
	_root.add_child(_note)

	if cleared:
		_next = _button("Next level", true)
		_next.pressed.connect(func() -> void: next_level_pressed.emit())
		_root.add_child(_next)
	_again = _button("Play again", false)
	_again.pressed.connect(func() -> void: again_pressed.emit())
	_root.add_child(_again)

	relayout()
	get_viewport().size_changed.connect(relayout)


## What to say under the stars. Nothing at all on a three-star run: a player
## who has just done the best thing available does not need advice, and the
## first version cheerfully told them they had two.
func _headline() -> String:
	if not cleared:
		return "OUT OF POWER"
	match stars:
		3:
			return "FLATTENED"
		2:
			return "DOWN"
	return "CLEARED"


## What to say under the stars — and on anything but a three-star run, that is
## how much further the building has to come down for the next one. A distance
## is something a player can look at the level and act on.
func _advice() -> String:
	if not cleared:
		return ""
	var share := 0 if bar <= 0.0 else int(round(spent / bar * 100.0))
	if stars >= 3:
		return "Brought down on %d%% of the bar. There is no better rating." % share
	return "Brought down on %d%% of the bar. Three stars needs %d%% or less." % [
		share, int(round(Levels.THREE_STAR_SHARE * 100.0))]


## A button, styled like the rest of the game's controls.
func _button(text: String, lit: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 19)
	var box := StyleBoxFlat.new()
	box.bg_color = GOLD if lit else Color(0.20, 0.22, 0.27)
	box.set_corner_radius_all(10)
	box.set_border_width_all(2)
	box.border_color = GOLD.lightened(0.3) if lit else Color(0.32, 0.35, 0.42)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("hover_pressed", box)
	if lit:
		button.add_theme_color_override("font_color", Color(0.10, 0.10, 0.12))
	return button


func relayout() -> void:
	var k := UI.units_per_css(get_viewport())
	var size := get_viewport().get_visible_rect().size / k
	scale = Vector2(k, k)
	_root.position = Vector2.ZERO
	_root.size = size
	_shade.position = Vector2.ZERO
	_shade.size = size

	var width := maxf(size.x - MARGIN * 2.0, 60.0)
	var middle := size.y * 0.42
	_title.position = Vector2(MARGIN, middle - 150.0)
	_title.size = Vector2(width, 44.0)
	if _stars != null:
		_stars.position = Vector2(MARGIN, middle - 96.0)
		_stars.size = Vector2(width, 80.0)
		_stars.queue_redraw()
	_line.position = Vector2(MARGIN, middle - (0.0 if _stars != null else 90.0))
	_line.size = Vector2(width, 26.0)
	_note.position = Vector2(MARGIN, _line.position.y + 36.0)
	_note.size = Vector2(width, 80.0)
	# Stacked upwards from the bottom, so whichever buttons exist sit in thumb
	# reach and the most interesting one is lowest.
	var stack: Array[Button] = []
	if _next != null:
		stack.append(_next)
	stack.append(_again)
	var gap := 10.0
	for i in stack.size():
		var from_bottom := float(stack.size() - 1 - i)
		stack[i].position = Vector2(MARGIN,
			size.y - MARGIN - (from_bottom + 1.0) * BUTTON_HEIGHT - from_bottom * gap)
		stack[i].size = Vector2(width, BUTTON_HEIGHT)


func _draw_stars() -> void:
	var earned := stars
	var span := _stars.size.x
	var middle := Vector2(span * 0.5, _stars.size.y * 0.5)
	var step := 74.0
	for i in STARS:
		var at := middle + Vector2((float(i) - 1.0) * step, 0.0)
		var colour := GOLD if i < earned else EMPTY
		_stars.draw_colored_polygon(_star(at, 30.0), colour)


## A five-pointed star, points out.
static func _star(at: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var reach := radius if i % 2 == 0 else radius * 0.42
		var angle := -PI * 0.5 + TAU * float(i) / 10.0
		points.append(at + Vector2(cos(angle), sin(angle)) * reach)
	return points


func _label(text: String, size: int, colour: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
