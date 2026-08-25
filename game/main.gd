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
const BAR_HEIGHT := 14.0
const BOTTOM_PAD := BUTTON_HEIGHT + 22.0 + BAR_HEIGHT + 6.0

## Reset and help live in the top corner, not in the bottom row: they are
## rare, and one of them throws the level away. The bottom bar — the part
## under a thumb — is only the three tools.
##
## Square and past the 44 px floor, with a gap wide enough that a thumb cannot
## press both. They were 58x46 text buttons reading "reset" and "help", which
## is a word to read at 13 px and a target barely over the minimum.
const CORNER := Vector2(52.0, 52.0)
const CORNER_GAP := 10.0

## How much of the spare vertical space goes above the building rather than
## below it. A phone in portrait has far more height than the level needs, and
## split evenly it all turns into empty road under the footing.
const SKY_SHARE := 0.75

var _level: Level
var _effects: Effects
var _backdrop: Backdrop
var _camera: Camera2D
var _tool: Tools.Kind = Tools.Kind.JACKHAMMER
var _power := 0.0
var _power_full := 0.0
var _resolved := ""
var _busy := false

## Holding is how a tool is used. The jackhammer keeps chipping while held;
## the ball and the charge build up and go on release.
var _holding := false
var _hold_at := Vector2.ZERO
## Why the last hold stopped, when it stopped for a reason worth saying.
var _note := ""
var _charge := 0.0
var _blow_timer := 0.0
var _settling_ticks := 0
## How long a full hold takes. Long enough that a partial one is a real
## choice, short enough that nobody is waiting on a progress bar.
const CHARGE_TIME := 1.1

## Longest a level may sit settling before it is judged anyway. Measured: a
## full demolition takes about 20 seconds to come to rest once the pieces that
## left the world are retired, so this sits well past that and only ever fires
## if something is genuinely stuck.
const SETTLE_LIMIT := 1800

var _layer: CanvasLayer
var _root: Control
var _row: HBoxContainer
var _reset: Button
var _help: Button
var _status: Label
var _bar: ProgressBar
var _pending: ProgressBar
var _results: Results
var _buttons: Array[Button] = []
var _art: Array[Control] = []
var _intro: Intro
var _view := Rect2(-400.0, -400.0, 1600.0, 1200.0)


func _ready() -> void:
	_camera = Camera2D.new()
	add_child(_camera)

	_backdrop = Backdrop.new()
	_backdrop.floor_y = Levels.FLOOR_Y
	add_child(_backdrop)

	_level = Level.new()
	_level.struck.connect(_on_struck)
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
	# Starting a level is the other moment where switching builds is free —
	# reset and next-level both come through here, and neither has anything
	# in progress to lose. Between this and the help screen, an update lands
	# at the next natural break rather than waiting for every tab to close.
	if UI.update_ready():
		UI.apply_update()
		return
	var spec := Levels.tower()
	_level.build(spec)
	_power_full = float(spec["power"])
	_power = _power_full
	_resolved = ""
	_busy = false
	_holding = false
	_charge = 0.0
	_note = ""
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

	_reset = _corner_button(Icons.draw_reset, _start)
	_help = _corner_button(Icons.draw_help, _open_intro)

	# The power bar sits directly above the tools it is spent by, so the thing
	# being spent and the thing spending it are in the same glance.
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Styled rather than themed: the default bar is grey on grey, and this is
	# the one readout a player watches while their thumb is down.
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color(0.16, 0.17, 0.21)
	trough.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.72, 0.28)
	fill.set_corner_radius_all(4)
	# Two bars in the same place. The one underneath shows the power you have;
	# the one on top shows what would be left after letting go, so the gap
	# between them is what this hold is about to cost — visible while there is
	# still time to hold on longer or let go sooner.
	var pending := StyleBoxFlat.new()
	pending.bg_color = Color(0.93, 0.36, 0.28)
	pending.set_corner_radius_all(4)
	_pending = ProgressBar.new()
	_pending.show_percentage = false
	_pending.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pending.add_theme_stylebox_override("background", trough)
	_pending.add_theme_stylebox_override("fill", pending)
	_root.add_child(_pending)

	var clear_box := StyleBoxEmpty.new()
	_bar.add_theme_stylebox_override("background", clear_box)
	_bar.add_theme_stylebox_override("fill", fill)
	_root.add_child(_bar)

	# Controls at the bottom, where a thumb reaches, stretched across whatever
	# width the screen turns out to be.
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_root.add_child(_row)

	for i in Tools.ORDER.size():
		var kind: Tools.Kind = Tools.ORDER[i]
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Icons rather than names. A name is a word to read; a hammer, a ball
		# on a chain and a lit charge are what the tools are. The readout above
		# still names whichever is selected, so nothing is lost by not printing
		# all three at all times — and the row can never be too narrow for its
		# own labels again.
		var art := Control.new()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.draw.connect(func() -> void:
			var selected: bool = Tools.ORDER[i] == _tool
			Icons.draw_tool(art, kind, art.size * 0.5, minf(art.size.y * 0.62, 34.0),
				Color(0.12, 0.12, 0.14) if selected else Color(0.86, 0.88, 0.92)))
		button.add_child(art)
		_art.append(art)
		# Selection has to read at a glance and without hover, which a phone
		# does not have: the chosen tool is filled and outlined in the same
		# amber as the power it spends.
		button.add_theme_stylebox_override("normal", _tool_style(false))
		button.add_theme_stylebox_override("hover", _tool_style(false))
		button.add_theme_stylebox_override("pressed", _tool_style(true))
		button.add_theme_stylebox_override("hover_pressed", _tool_style(true))
		button.add_theme_color_override("font_pressed_color", Color(0.10, 0.10, 0.12))
		button.add_theme_color_override("font_hover_pressed_color", Color(0.10, 0.10, 0.12))
		button.pressed.connect(func() -> void: _select(kind))
		_row.add_child(button)
		_buttons.append(button)


func _tool_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.95, 0.72, 0.28) if selected else Color(0.17, 0.18, 0.22)
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = Color(1.0, 0.86, 0.52) if selected else Color(0.26, 0.28, 0.33)
	return box


## An icon button, drawn rather than labelled, styled like the tool row so the
## whole interface reads as one set of controls.
func _corner_button(icon: Callable, on_press: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.draw.connect(func() -> void:
		icon.call(art, art.size * 0.5, minf(art.size.y * 0.58, 30.0),
			Color(0.86, 0.88, 0.92)))
	button.add_child(art)
	button.add_theme_stylebox_override("normal", _tool_style(false))
	button.add_theme_stylebox_override("hover", _tool_style(false))
	button.add_theme_stylebox_override("pressed", _tool_style(true))
	button.add_theme_stylebox_override("hover_pressed", _tool_style(true))
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
	var corners := CORNER.x * 2.0 + CORNER_GAP
	_status.position = Vector2(SIDE_MARGIN, 8.0)
	_status.size = Vector2(maxf(width - corners - 8.0, 40.0), TOP_PAD - 8.0)
	_reset.position = Vector2(size.x - SIDE_MARGIN - corners, 8.0)
	_reset.size = CORNER
	_help.position = Vector2(size.x - SIDE_MARGIN - CORNER.x, 8.0)
	_help.size = CORNER
	_bar.position = Vector2(SIDE_MARGIN, size.y - BOTTOM_PAD - BAR_HEIGHT - 6.0)
	_bar.size = Vector2(width, BAR_HEIGHT)
	_pending.position = _bar.position
	_pending.size = _bar.size
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
	_note = ""
	if _holding:
		_holding = false
		_effects.stop_aim()
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

	if _intro != null or _results != null or _resolved != "":
		return

	var down: bool = (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	var up: bool = (event is InputEventMouseButton and not event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not event.pressed)
	var moved: bool = (event is InputEventMouseMotion and _holding) \
		or (event is InputEventScreenDrag and _holding)

	if down and _power >= _cheapest():
		_holding = true
		_charge = 0.0
		_blow_timer = 0.0
		_hold_at = get_global_mouse_position()
		if event is InputEventScreenTouch:
			_hold_at = (event as InputEventScreenTouch).position
			_hold_at = get_canvas_transform().affine_inverse() * _hold_at
		# The jackhammer starts working the moment it is put down.
		if _tool == Tools.Kind.JACKHAMMER and not _strike(_hold_at, 1.0):
			_stop_hold("nothing to break there")
	elif moved:
		_hold_at = get_global_mouse_position()
	elif up and _holding:
		_release()


## Aiming keeps working while held, so a thumb can slide onto the right piece
## rather than having to land on it.
func _process(delta: float) -> void:
	if not _holding:
		return
	if _resolved != "":
		_holding = false
		return
	_charge = minf(1.0, _charge + delta / CHARGE_TIME)
	if _tool == Tools.Kind.JACKHAMMER:
		_blow_timer += delta
		while _blow_timer >= Tools.JACKHAMMER_INTERVAL:
			_blow_timer -= Tools.JACKHAMMER_INTERVAL
			if _power < Tools.cost(Tools.Kind.JACKHAMMER):
				_stop_hold("out of power")
				break
			# A blow that finds nothing costs nothing, which is right — but
			# holding on while it silently does nothing is not. Measured on
			# the shipped build: four seconds of holding on shattered glazing
			# spent 12 power, drew nothing, and said nothing. Lift the tool
			# and say why instead.
			if not _strike(_hold_at, 1.0):
				_stop_hold("nothing left to break there")
				break
	else:
		_effects.aim(_tool, _hold_at, _charge, _hold_at.x < _level.centre_x())
	_refresh()


func _release() -> void:
	_holding = false
	_effects.stop_aim()
	_note = ""
	if _tool == Tools.Kind.JACKHAMMER:
		return
	# A hold that outran the power left buys what is left, not what was asked
	# for: the bar is the limit, and it is visible the whole time.
	var wanted := _charge
	while wanted > 0.0 and Tools.cost(_tool, wanted) > _power:
		wanted -= 0.05
	if wanted <= 0.0:
		return
	if not _strike(_hold_at, wanted):
		_note = "nothing there to catch it"
		_refresh()


## One application of the current tool. Power is spent only if it did
## something, so a misfire into empty sky is free.
func _strike(at: Vector2, charge: float) -> bool:
	if not Tools.apply(_tool, _level, at, charge):
		return false
	_note = ""
	_power = maxf(0.0, _power - Tools.cost(_tool, charge))
	_effects.play(_tool, at)
	_busy = true
	_level.reset_settle()
	_refresh()
	queue_redraw()
	return true


func _stop_hold(why: String) -> void:
	_holding = false
	_effects.stop_aim()
	_note = why
	_refresh()


## What the hold in progress would cost if it ended now. Zero when nothing is
## being held.
func _pending_cost() -> float:
	if not _holding or _resolved != "":
		return 0.0
	if _tool == Tools.Kind.JACKHAMMER:
		return Tools.cost(Tools.Kind.JACKHAMMER)      # the next blow
	return Tools.cost(_tool, _charge)


func _cheapest() -> float:
	return minf(Tools.cost(Tools.Kind.JACKHAMMER), Tools.cost(_tool, 0.0))


## Damage lands where the tool actually reached, which for the wrecking ball is
## wherever its swing took it rather than where the tap was.
func _on_struck(at: Vector2, amount: int) -> void:
	_effects.number(at, amount)


func _physics_process(_delta: float) -> void:
	if _resolved != "":
		return
	# A settling world that never settles would hang the level for ever with
	# no way out but a reload. The level retires pieces that leave the world,
	# which is the real fix; this is the belt to that pair of braces.
	if _busy:
		_settling_ticks += 1
		if _settling_ticks > SETTLE_LIMIT:
			_settling_ticks = 0
			_busy = false
			_judge()
			return
	if _level.tick_settle():
		if _busy:
			_busy = false
			_settling_ticks = 0
			_judge()
		elif _level.cleared():
			_judge()
	_refresh()
	queue_redraw()


func _judge() -> void:
	if _level.cleared():
		_resolved = "CLEARED with %d%% of the bar left" % int(round(_power / _power_full * 100.0))
		_show_results(true)
	elif _power < _cheapest():
		var left := _level.standing()
		_resolved = "OUT OF POWER — %d piece%s still above the line" \
			% [left, "" if left == 1 else "s"]
		_show_results(false)


func _show_results(won: bool) -> void:
	if _results != null:
		return
	_holding = false
	_effects.stop_aim()
	_results = Results.new()
	_results.cleared = won
	_results.power_left = _power
	_results.power_full = _power_full
	_results.standing = _level.standing()
	_results.again_pressed.connect(_restart)
	add_child(_results)


func _restart() -> void:
	if _results != null:
		_results.queue_free()
		_results = null
	_start()


func _refresh() -> void:
	for i in _buttons.size():
		_buttons[i].button_pressed = (Tools.ORDER[i] == _tool)
		if i < _art.size():
			_art[i].queue_redraw()
	if _status == null:
		return
	if _bar != null:
		_bar.max_value = maxf(1.0, _power_full)
		_pending.max_value = _bar.max_value
		_pending.value = _power
		_bar.value = maxf(0.0, _power - _pending_cost())
	var state := _resolved
	if state == "":
		if _note != "":
			state = _note
		elif _holding and _tool != Tools.Kind.JACKHAMMER:
			state = "hold to build — %d power" % int(round(Tools.cost(_tool, _charge)))
		elif _busy:
			state = "settling…"
		else:
			state = "%d above the line" % _level.standing()
	_status.text = "power %d   ·   %s\n%s" % [int(round(_power)), Tools.NAMES[_tool], state]


func _draw() -> void:
	# The survey line the level is judged against, spanning whatever the camera
	# can see.
	var line := _level.height_line()
	draw_dashed_line(Vector2(_view.position.x, line), Vector2(_view.end.x, line),
		Color(0.95, 0.32, 0.30, 0.9), 3.0, 12.0)
