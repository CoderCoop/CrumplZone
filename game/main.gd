extends Node2D

## The playable wrapper: input, tool selection, and the readout. All the rules
## live in level.gd, which this drives and does not duplicate.

const TOOL_KEYS := [KEY_1, KEY_2, KEY_3]

var _level: Level
var _tool: Tools.Kind = Tools.Kind.JACKHAMMER
var _moves_left := 0
var _resolved := ""
var _busy := false

var _status: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(400.0, 300.0)
	add_child(camera)

	_level = Level.new()
	add_child(_level)

	_build_ui()
	_start()


func _start() -> void:
	var spec := Levels.tower()
	_level.build(spec)
	_moves_left = spec["moves"]
	_resolved = ""
	_busy = false
	_refresh()
	queue_redraw()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_status = Label.new()
	_status.position = Vector2(16.0, 10.0)
	_status.add_theme_font_size_override("font_size", 17)
	layer.add_child(_status)

	# On-screen buttons because the charter targets phones, where there is no
	# number row to press.
	var row := HBoxContainer.new()
	row.position = Vector2(16.0, 552.0)
	row.add_theme_constant_override("separation", 8)
	layer.add_child(row)

	for i in Tools.ORDER.size():
		var kind: Tools.Kind = Tools.ORDER[i]
		var button := Button.new()
		button.text = "%d  %s" % [i + 1, Tools.NAMES[kind]]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150.0, 34.0)
		button.pressed.connect(func() -> void: _select(kind))
		row.add_child(button)
		_buttons.append(button)

	var reset := Button.new()
	reset.text = "reset  (R)"
	reset.focus_mode = Control.FOCUS_NONE
	reset.custom_minimum_size = Vector2(110.0, 34.0)
	reset.pressed.connect(_start)
	row.add_child(reset)


func _select(kind: Tools.Kind) -> void:
	_tool = kind
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_start()
			return
		var index := TOOL_KEYS.find(event.keycode)
		if index != -1:
			_select(Tools.ORDER[index])
			return

	if _busy or _resolved != "" or _moves_left <= 0:
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
		_resolved = "OUT OF MOVES — %d block%s still above the line" \
			% [left, "" if left == 1 else "s"]


func _refresh() -> void:
	for i in _buttons.size():
		_buttons[i].disabled = (Tools.ORDER[i] == _tool)
	if _status == null:
		return
	var state := _resolved
	if state == "":
		state = "settling…" if _busy else "%d above the line" % _level.standing()
	_status.text = "CrumplZone   moves left: %d   tool: %s   %s" \
		% [_moves_left, Tools.NAMES[_tool], state]


func _draw() -> void:
	var line := _level.height_line()
	draw_dashed_line(Vector2(0.0, line), Vector2(800.0, line),
		Color(0.95, 0.35, 0.35, 0.85), 2.0, 10.0)
