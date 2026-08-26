class_name Results
extends CanvasLayer

## What you get at the end of a level: whether it came down, how much of the
## bar you had left, and a rating out of three.
##
## Stars are drawn rather than typed. The default font has no star glyph and
## renders a tofu box for one — the same trap that put a box where the reset
## button's symbol was meant to be.

signal again_pressed

const STARS := 3

## What a run may spend, as a multiple of par, for three stars and for two.
##
## Rated against par — what the solver's best solution for this level costs —
## rather than against a fraction of the bar. A fraction of the bar makes three
## stars mean different things on different levels: generous on one, impossible
## on another, and neither on a level nobody has measured. Against par it means
## the same thing everywhere, which is "you played close to as well as this can
## be played", and it stays true for a level generated tomorrow.
##
## Three stars is 15% off the best known solution. That is meant to be hard:
## clearing the level at all is the floor, and the bar holds nearly twice par
## so finishing is never the challenge.

const MARGIN := 16.0
const BUTTON_HEIGHT := 56.0
const BRIGHT := Color(0.94, 0.95, 0.97)
const DIM := Color(0.62, 0.66, 0.72)
const GOLD := Color(0.97, 0.78, 0.32)
const EMPTY := Color(0.30, 0.32, 0.37)
const ACCENT := Color(0.95, 0.45, 0.35)

var cleared := false
var power_left := 0.0
var power_full := 1.0
var standing := 0

var _root: Control
var _shade: ColorRect
var _title: Label
var _line: Label
var _note: Label
var _stars: Control
var _again: Button


const THREE_STAR := 1.15
const TWO_STAR := 1.55

var par := 0.0


## How many stars a run earns, from what it spent against what the level's best
## known solution costs. Clearing at all is worth one.
static func stars_for_spend(spent: float, level_par: float) -> int:
	if level_par <= 0.0:
		return 1
	var ratio := spent / level_par
	if ratio <= THREE_STAR:
		return 3
	if ratio <= TWO_STAR:
		return 2
	return 1


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
	_title = _label("CLEARED" if cleared else "OUT OF POWER", 34,
		BRIGHT if cleared else ACCENT)
	_root.add_child(_title)

	if cleared:
		_stars = Control.new()
		_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stars.draw.connect(_draw_stars)
		_root.add_child(_stars)
		var spent := maxf(0.0, power_full - power_left)
		_line = _label("%d power spent  ·  par %d" % [int(round(spent)), int(round(par))],
			18, DIM)
		_note = _label(_advice(stars_for_spend(spent, par), spent), 15, DIM, true)
	else:
		_line = _label("%d piece%s still above the line"
			% [standing, "" if standing == 1 else "s"], 18, DIM)
		_note = _label(
			"Nothing is deleted, so everything you break still has to end up "
			+ "down there. Bringing the building down beats grinding it away.",
			15, DIM, true)
	_root.add_child(_line)
	_root.add_child(_note)

	_again = Button.new()
	_again.text = "Play again"
	_again.focus_mode = Control.FOCUS_NONE
	_again.add_theme_font_size_override("font_size", 19)
	_again.pressed.connect(func() -> void: again_pressed.emit())
	_root.add_child(_again)

	relayout()
	get_viewport().size_changed.connect(relayout)


## What to say under the stars. Nothing at all on a three-star run: a player
## who has just done the best thing available does not need advice, and the
## first version cheerfully told them they had two.
func _advice(earned: int, spent: float) -> String:
	var target := par * THREE_STAR
	match earned:
		1:
			return ("Down, but it cost %d. Par is %d — fewer, better placed uses."
				% [int(round(spent)), int(round(par))])
		2:
			return ("Three stars needs it done for %d or less. This run spent %d."
				% [int(round(target)), int(round(spent))])
	return "Nothing left standing, and done at par. There is no better rating."


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
	_again.position = Vector2(MARGIN, size.y - BUTTON_HEIGHT - MARGIN)
	_again.size = Vector2(width, BUTTON_HEIGHT)


func _draw_stars() -> void:
	var earned := stars_for_spend(maxf(0.0, power_full - power_left), par)
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
