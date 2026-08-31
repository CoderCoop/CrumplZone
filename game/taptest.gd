extends Node2D

## Does a tap on the building actually do something?
##
##   xvfb-run -a godot --path game res://taptest.tscn -- [WxH]
##
## The Pages deploy has been failing since #37 on one check —
## verify-web-export's "responds to input" — while "no page errors" and
## "canvas rendered" both pass. Five releases have not reached the site
## because of it, which is what a player sees as the game not updating.
##
## That check drives a real browser, which cannot be run against a web export
## here. This drives the same path natively instead: build Main at the same
## viewport the browser uses, press Play where the browser presses it, then
## send the same five clicks down the middle and report whether the level took
## any damage at all. If the answer is no, the bug is in the game and not in
## the check.
##
## Not a gate. It is a reproduction.

var _main: Node2D
var _step := 0
var _shot := Vector2i(900, 700)
var _spots: Array[Vector2] = []
var _at := 0
var _damage_before := 0
var _lines: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var parts := args[0].split("x")
		if parts.size() == 2:
			_shot = Vector2i(int(parts[0]), int(parts[1]))
	get_window().size = _shot
	_main = load("res://main.tscn").instantiate()
	add_child(_main)


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)


func _damage() -> int:
	var level = _main.get("_level")
	if level == null:
		return -1
	var total := 0
	for body in level.live_blocks():
		total += int(body.get_meta("damage", 0))
	return total


func _process(_delta: float) -> void:
	_step += 1
	# Godot boots and the intro lays out; the browser waits 8 s for the same.
	if _step == 60:
		_lines.append("intro present   : %s" % [_main.get("_intro") != null])
		# Where the browser clicks Play: PLAY_HEIGHT/2 + MARGIN above the
		# bottom, in the CSS pixels boundingBox reports.
		var play := Vector2(float(_shot.x) * 0.5, float(_shot.y) - (52.0 / 2.0 + 16.0))
		_lines.append("play tapped at  : %s" % play)
		_tap(play)
		return
	if _step == 120:
		_lines.append("intro after tap : %s" % [_main.get("_intro") != null])
		_lines.append("level id        : %s" % [_main.get("_level_id")])
		_lines.append("tool            : %s" % [_main.get("_tool")])
		_damage_before = _damage()
		_lines.append("damage before   : %d" % _damage_before)
		for fy in [0.45, 0.52, 0.59, 0.66, 0.73]:
			_spots.append(Vector2(float(_shot.x) * 0.5, float(_shot.y) * fy))
		return
	if _step > 120 and _at < _spots.size() and _step % 40 == 0:
		_tap(_spots[_at])
		_lines.append("tapped %s -> damage %d, note %s" % [_spots[_at],
			_damage(), _main.get("_note")])
		_at += 1
		return
	if _at >= _spots.size() and _step > 120 + 40 * _spots.size() + 120:
		_report()


func _report() -> void:
	print("")
	for line in _lines:
		print(line)
	var after := _damage()
	print("")
	print("damage after    : %d (was %d)" % [after, _damage_before])
	print("expected : a tap on the building damages it")
	print("VERDICT  : %s" % ["FAIL — nothing happened" if after <= _damage_before
		else "PASS"])
	get_tree().quit()
