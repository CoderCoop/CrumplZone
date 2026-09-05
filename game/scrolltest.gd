extends Node2D

## Does a touch drag on the intro screen reach the thing that scrolls it?
##
##   xvfb-run -a godot --fixed-fps 60 --resolution 390x844 \
##     --rendering-driver opengl3 --path game res://scrolltest.tscn
##
## Reported from a phone: scrolling the help screen by touch does not always
## work, and it fails when the drag starts on the level selector.
##
## A ScrollContainer drag-scrolls from events that arrive at it. A Control
## with MOUSE_FILTER_STOP ends that chain, and every Button and every bare
## Control is STOP unless somebody says otherwise — so the drag died wherever
## the finger happened to land. Measured before the fix, events arriving for
## one identical 12-step drag: 24 from over a Label, 0 from over the city map,
## a district pin, a level tile, or a spacer.
##
## What this asserts is routing, not scrolling. Godot only drag-scrolls a
## ScrollContainer where a touchscreen is available, and there is none behind
## xvfb — measured, forcing is_touchscreen_available() true does not change
## it. So a harness that watched scroll_vertical would read zero everywhere
## and prove nothing, which is what the first two attempts at this did. The
## last step — that a delivered drag actually moves the view — is real and is
## only verifiable on a device.
##
## It needs a window: headless has no screen to derive a scale from, so
## UI.units_per_css returns 12.5 and the whole overlay lays itself out for a
## 64x64 screen. Under --resolution it lays out the way a phone gets it.

## How far down the scroll column to try. Chosen to land on the things that
## were swallowing drags as well as the things that were not.
const DOWN_THE_COLUMN := [0.05, 0.15, 0.30, 0.50, 0.70, 0.90]
const STEPS := 12
const STEP_PX := 14.0

var _intro: Intro
var _scroll: ScrollContainer
var _seen := 0


func _ready() -> void:
	_intro = Intro.new()
	add_child(_intro)
	_intro.show_tab("levels")
	_run()


func _run() -> void:
	# Layout settles over a couple of frames; nothing below means anything
	# until the containers have sized themselves.
	for i in 8:
		await get_tree().physics_frame
	for node in _walk(_intro):
		if node is ScrollContainer:
			_scroll = node as ScrollContainer
	if _scroll == null:
		print("no ScrollContainer on the intro screen — harness broken")
		get_tree().quit(1)
		return
	_scroll.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenDrag:
			_seen += 1)

	var view: Vector2 = get_viewport().get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x >= view.x:
		print("this needs a window smaller than the viewport, so that the")
		print("overlay lays out the way a phone gets it — run it with")
		print("--resolution 390x844 under xvfb. Refusing to report a pass.")
		get_tree().quit(1)
		return
	var to_window: float = window.x / view.x

	var deaf: Array[String] = []
	for fraction in DOWN_THE_COLUMN:
		var local := Vector2(_scroll.size.x * 0.5, _scroll.size.y * float(fraction))
		var at: Vector2 = (_scroll.get_screen_transform() * local) * to_window
		var under := _under(_scroll.get_global_transform() * local)
		_seen = 0
		await _drag_from(at)
		print("  %2.0f%% down, over %-24s %2d of %d events arrived"
			% [float(fraction) * 100.0, under, _seen, STEPS])
		if _seen < STEPS:
			deaf.append("%.0f%% down, over %s" % [float(fraction) * 100.0, under])

	if not deaf.is_empty():
		print("")
		print("A drag starting here never reaches the scroll:")
		for line in deaf:
			print("  " + line)
		print("On a phone that is a screen that scrolls from some places and")
		print("not others. See UI.let_drags_through.")
		get_tree().quit(1)
		return
	print("every drag reaches the scroll, wherever it starts")

	# The other half of the same change. Letting drags past a button must not
	# cost the button its taps, and must not turn a scroll into a launch:
	# MOUSE_FILTER_PASS delivers the event to the control *and* to the scroll
	# behind it, so both are live at once and both are worth asserting.
	var pin := _first_pin()
	if pin == null:
		print("no district pin on the map — harness broken")
		get_tree().quit(1)
		return
	var pin_at: Vector2 = (pin.get_screen_transform() * (pin.size * 0.5)) \
		* to_window
	var fired := {"n": 0}
	pin.pressed.connect(func() -> void: fired["n"] += 1)

	fired["n"] = 0
	await _tap(pin_at)
	var on_tap: int = fired["n"]
	fired["n"] = 0
	await _drag_from(pin_at)
	var on_drag: int = fired["n"]
	print("district pin: fired %d time(s) on a tap, %d on a %d px drag"
		% [on_tap, on_drag, int(STEPS * STEP_PX)])
	if on_tap != 1:
		print("a tap on a district pin no longer picks the district")
		get_tree().quit(1)
		return
	if on_drag != 0:
		print("scrolling from a district pin also picks the district — on a")
		print("phone that means every scroll changes what you are looking at")
		get_tree().quit(1)
		return
	print("a tap still picks, and a scroll no longer does")
	get_tree().quit(0)


func _tap(at: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = at
	Input.parse_input_event(down)
	await get_tree().physics_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = at
	Input.parse_input_event(up)
	await get_tree().physics_frame


func _first_pin() -> Button:
	for node in _walk(_intro):
		if node is CityMap:
			for child in node.get_children():
				if child is Button:
					return child as Button
	return null


func _drag_from(at: Vector2) -> void:
	# Window coordinates. Measured: a click injected in viewport space misses
	# the control under it and one in window space hits, so an injected event
	# arrives the way the OS delivers one.
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = at
	Input.parse_input_event(down)
	await get_tree().physics_frame
	var here := at
	for i in STEPS:
		here += Vector2(0.0, -STEP_PX)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = here
		drag.relative = Vector2(0.0, -STEP_PX)
		Input.parse_input_event(drag)
		# Each step on its own frame, the way a finger delivers them.
		await get_tree().physics_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = here
	Input.parse_input_event(up)
	await get_tree().physics_frame


## The smallest visible Control under a point, and what it does with input —
## which is the whole of what decides whether anything above it hears.
func _under(point: Vector2) -> String:
	var best: Control = null
	for node in _walk(_scroll):
		if node == _scroll or not (node is Control):
			continue
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if not control.get_global_rect().has_point(point):
			continue
		if best == null \
				or control.get_global_rect().get_area() <= best.get_global_rect().get_area():
			best = control
	if best == null:
		return "nothing"
	var filters := ["STOP", "PASS", "IGNORE"]
	var what: String = best.get_class()
	if best.get_script() != null:
		what = String(best.get_script().get_global_name())
	return "%s/%s" % [what, filters[best.mouse_filter]]


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
