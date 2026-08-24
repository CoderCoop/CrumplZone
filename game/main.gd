extends Node2D

## The playable wrapper: input, tool selection, the readout and the effects.
## All the rules live in level.gd, which this drives and does not duplicate.
##
## Two things here are mobile-first rather than incidental (see AGENTS.md):
##
## The camera frames the level rather than sitting at a fixed point, so the
## building fills whatever shape of screen it is given — a phone in portrait
## sees the same building as a laptop, not a letterboxed slice of one.
##
## The UI is laid out in CSS pixels and the layer scaled by UI.units_per_css(),
## so a 56-unit button really is 56 px under a thumb. Laid out in raw viewport
## units it measured 28 px on a 2x phone, which is well under the 44 px floor.

const TOOL_KEYS := [KEY_1, KEY_2, KEY_3]

## All in CSS pixels. The bar is taller than the 44 px minimum because it is
## the control played with most, and it sits at the bottom where a thumb is.
const BUTTON_HEIGHT := 56.0
const SIDE_MARGIN := 10.0
const TOP_PAD := 84.0
const BOTTOM_PAD := BUTTON_HEIGHT + 22.0

## Reset and help live in the top corner, not in the bottom row: they are
## rare, and one of them throws the level away. The bottom bar — the part
## under a thumb — is only the three tools.
const CORNER := Vector2(58.0, 46.0)

## How much of the spare vertical space goes above the building rather than
## below it. A phone in portrait has far more height than the level needs, and
## split evenly it all turns into empty road under the footing.
const SKY_SHARE := 0.75

var _level: Level
var _effects: Effects
var _backdrop: Backdrop
var _camera: Camera2D
var _tool: Tools.Kind = Tools.Kind.JACKHAMMER
var _moves_left := 0
var _resolved := ""
var _busy := false

var _layer: CanvasLayer
var _root: Control
var _row: HBoxContainer
var _reset: Button
var _help: Button
var _status: Label
var _buttons: Array[Button] = []
var _intro: Intro
var _view := Rect2(-400.0, -400.0, 1600.0, 1200.0)


func _ready() -> void:
	_camera = Camera2D.new()
	add_child(_camera)

	_backdrop = Backdrop.new()
	_backdrop.floor_y = Levels.FLOOR_Y
	add_child(_backdrop)

	_level = Level.new()
	add_child(_level)

	_effects = Effects.new()
	_effects.z_index = 50
	add_child(_effects)

	_build_ui()
	_start()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_open_intro()


func _start() -> void:
	var spec := Levels.tower()
	_level.build(spec)
	_moves_left = spec["moves"]
	_resolved = ""
	_busy = false
	_relayout()
	_refresh()
	queue_redraw()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)

	_root = Control.new()
	_layer.add_child(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Information at the top, out from under the hand. Positioned directly
	# rather than in a container — see _relayout.
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 17)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_status)

	_reset = _corner_button("reset", _start)
	_help = _corner_button("help", _open_intro)

	# Controls at the bottom, where a thumb reaches, stretched across whatever
	# width the screen turns out to be.
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_root.add_child(_row)

	for i in Tools.ORDER.size():
		var kind: Tools.Kind = Tools.ORDER[i]
		var button := Button.new()
		button.text = Tools.NAMES[kind]
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		# Clipped, so a long tool name cannot widen the row past the screen.
		# Unclipped, the row measured 423 px on a 390 px phone and the last
		# button hung off the edge.
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(func() -> void: _select(kind))
		_row.add_child(button)
		_buttons.append(button)


func _corner_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(on_press)
	_root.add_child(button)
	return button


## Rects are set by hand rather than by anchor preset. A preset applied to a
## container that has not laid out yet keeps its zero size, and the whole
## control row was invisible on every screen because of it — the first web
## build of this layout shipped with no tool buttons at all.
func _relayout() -> void:
	var k := UI.units_per_css(get_viewport())
	var size := get_viewport_rect().size / k
	_layer.scale = Vector2(k, k)
	_root.position = Vector2.ZERO
	_root.size = size

	var width := maxf(size.x - SIDE_MARGIN * 2.0, 40.0)
	var corners := CORNER.x * 2.0 + 8.0
	_status.position = Vector2(SIDE_MARGIN, 8.0)
	_status.size = Vector2(maxf(width - corners - 8.0, 40.0), TOP_PAD - 8.0)
	_reset.position = Vector2(size.x - SIDE_MARGIN - corners, 8.0)
	_reset.size = CORNER
	_help.position = Vector2(size.x - SIDE_MARGIN - CORNER.x, 8.0)
	_help.size = CORNER
	_row.position = Vector2(SIDE_MARGIN, size.y - BOTTOM_PAD)
	_row.size = Vector2(width, BUTTON_HEIGHT)

	_frame_camera(k)
	if _intro != null:
		_intro.relayout()


## Fits the level between the two bars, whatever shape the screen is.
func _frame_camera(k: float) -> void:
	var view := get_viewport_rect().size
	var want := _level.frame()
	var top := TOP_PAD * k
	var bottom := BOTTOM_PAD * k
	var side := SIDE_MARGIN * k
	var avail := Vector2(
		maxf(view.x - side * 2.0, 80.0),
		maxf(view.y - top - bottom, 80.0))
	var zoom := minf(avail.x / want.size.x, avail.y / want.size.y)
	_camera.zoom = Vector2(zoom, zoom)
	# The level centres in the band between the bars, not in the whole screen,
	# so neither the readout nor the thumb rests on top of the building. Spare
	# height goes mostly above it: sky reads as a skyline, the same space below
	# reads as an empty car park.
	var slack := maxf(avail.y / zoom - want.size.y, 0.0)
	var centre := want.get_center() - Vector2(0.0, slack * (SKY_SHARE - 0.5))
	_camera.position = centre - Vector2(0.0, (top - bottom) * 0.5 / zoom)

	# Whatever the camera can see has to be painted, or the sky stops partway
	# up a tall portrait screen.
	_view = Rect2(_camera.position - view / (2.0 * zoom), view / zoom).grow(80.0)
	_backdrop.cover(_view)
	queue_redraw()


func _open_intro() -> void:
	if _intro != null:
		return
	_intro = Intro.new()
	_intro.play_pressed.connect(_close_intro)
	add_child(_intro)


func _close_intro() -> void:
	if _intro == null:
		return
	_intro.queue_free()
	_intro = null


func _select(kind: Tools.Kind) -> void:
	_tool = kind
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _intro != null:
			return
		if event.keycode == KEY_R:
			_start()
			return
		var index := TOOL_KEYS.find(event.keycode)
		if index != -1:
			_select(Tools.ORDER[index])
			return

	if _intro != null or _busy or _resolved != "" or _moves_left <= 0:
		return

	var pressed: bool = (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_use(get_global_mouse_position())


func _use(at: Vector2) -> void:
	# A tool that found nothing to act on costs nothing. Spending a move on a
	# misclick would punish imprecision, which the charter's second pillar
	# says not to do.
	if not Tools.apply(_tool, _level, at):
		return
	_effects.play(_tool, at, at.x < _level.centre_x())
	_moves_left -= 1
	_busy = true
	_level.reset_settle()
	_refresh()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _resolved != "":
		return
	if _level.tick_settle():
		if _busy:
			_busy = false
			_judge()
		elif _level.cleared():
			_judge()
	_refresh()
	queue_redraw()


func _judge() -> void:
	if _level.cleared():
		var spare := _moves_left
		_resolved = "CLEARED with %d move%s to spare" % [spare, "" if spare == 1 else "s"]
	elif _moves_left <= 0:
		var left := _level.standing()
		_resolved = "OUT OF MOVES — %d piece%s still above the line" \
			% [left, "" if left == 1 else "s"]


func _refresh() -> void:
	for i in _buttons.size():
		_buttons[i].button_pressed = (Tools.ORDER[i] == _tool)
	if _status == null:
		return
	var state := _resolved
	if state == "":
		state = "settling…" if _busy else "%d above the line" % _level.standing()
	_status.text = "moves %d   ·   %s\n%s" % [_moves_left, Tools.NAMES[_tool], state]


func _draw() -> void:
	# The survey line the level is judged against, spanning whatever the camera
	# can see.
	var line := _level.height_line()
	draw_dashed_line(Vector2(_view.position.x, line), Vector2(_view.end.x, line),
		Color(0.95, 0.32, 0.30, 0.9), 3.0, 12.0)
