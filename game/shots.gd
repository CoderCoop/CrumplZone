extends Node2D

## Renders one picture of each structural system, so a change to how a
## building is drawn can be looked at instead of guessed at.
##
## Not part of the gate and not shipped: it needs a real renderer, which the
## harnesses deliberately do without. Run it with
##
##     xvfb-run -a godot --path game res://shots.tscn -- <out-dir>
##
## and open the PNGs. The framing matches main.gd's camera, so what comes out
## is what a player sees, at a phone's aspect ratio.

const SHOT := Vector2i(430, 780)

var _level: Level
var _cam: Camera2D
var _out := "shots"
var _queue: Array = []
var _waited := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = SHOT
	_level = Level.new()
	add_child(_level)
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	for kind in Architecture.TYPES:
		_queue.append(kind)


func _process(_delta: float) -> void:
	if _waited == 0:
		if _queue.is_empty():
			print("wrote %d pictures to %s" % [Architecture.TYPES.size(), _out])
			get_tree().quit()
			return
		var kind: String = _queue.pop_front()
		var spec := Generator.generate(hash(kind), kind)
		_level.build(spec)
		var want: Rect2 = _level.frame()
		# The project stretches canvas items from an 800x600 base, so the
		# units the camera works in are the visible rect's, not the window's.
		var avail: Vector2 = get_viewport().get_visible_rect().size
		_cam.position = want.get_center()
		_cam.zoom = Vector2.ONE * minf(
			avail.x / want.size.x, avail.y / want.size.y)
		_waited = 1
		return
	_waited += 1
	# Two frames of physics before the picture, so nothing is caught mid-drop,
	# and one after the camera moved so the frame is not the previous shot.
	if _waited < 6:
		return
	var image := get_viewport().get_texture().get_image()
	var name := String(_level.spec.get("kind", "level"))
	image.save_png("%s/%s.png" % [_out, name])
	print("  %s  %d blocks" % [name, _level.spec["blocks"].size()])
	_waited = 0
