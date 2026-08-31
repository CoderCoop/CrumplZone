extends Node2D

## Renders one picture of every backdrop setting, so a horizon can be looked at
## rather than reasoned about.
##
## Not part of the gate and not shipped: it needs a real renderer, which the
## harnesses deliberately do without. Run it with
##
##     xvfb-run -a godot --path game res://skyshot.tscn -- <out-dir>
##
## The building in front is the same one in every shot, on purpose. The
## question this answers is whether the seven districts look like seven
## different places, and the only way to see that is to change nothing else.

const SHOT := Vector2i(430, 780)
## How far back from the game's own framing to stand.
const WIDER := 0.42

var _level: Level
var _sky: Backdrop
var _cam: Camera2D
var _out := "skies"
var _queue: Array = []
var _now := ""
var _waited := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = SHOT
	_sky = Backdrop.new()
	add_child(_sky)
	_level = Level.new()
	add_child(_level)
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	for name in Backdrop.SETTINGS:
		_queue.append(String(name))


func _process(_delta: float) -> void:
	if _waited == 0:
		if _queue.is_empty():
			print("wrote %d skies to %s" % [Backdrop.SETTINGS.size(), _out])
			get_tree().quit()
			return
		_now = String(_queue.pop_front())
		var spec := Generator.generate(4102, Architecture.HOUSE)
		_level.build(spec)
		var want: Rect2 = _level.frame()
		var avail: Vector2 = get_viewport().get_visible_rect().size
		# Framed wider than the game frames it. main.gd fills the screen with
		# the building, which is right for playing and useless for judging a
		# horizon — at that zoom a crane is three posts running off the top of
		# the picture. This is the tool for looking at what is behind.
		_cam.position = want.get_center() - Vector2(0.0, 40.0)
		_cam.zoom = Vector2.ONE * minf(
			avail.x / want.size.x, avail.y / want.size.y) * WIDER
		_sky.setting = _now
		_sky.floor_y = float(spec["floor_y"])
		# The same rectangle main.gd hands it: whatever the camera can see.
		_sky.cover(Rect2(_cam.position - avail * 0.5 / _cam.zoom,
			avail / _cam.zoom))
		_waited = 1
		return
	_waited += 1
	if _waited < 6:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/sky-%s.png" % [_out, _now])
	print("  " + _now)
	_waited = 0
