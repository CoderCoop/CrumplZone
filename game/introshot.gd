extends Node2D

## A picture of the intro screen at a phone's proportions.
##
##   xvfb-run -a godot --path game res://introshot.tscn -- <out-dir> [tab] [WxH]
##
## The mobile-first rules in AGENTS.md are written in CSS pixels and say to
## check a UI change at a real aspect ratio before calling it done. This is
## how that check gets made rather than asserted.

const SHOT := Vector2i(430, 880)

var _intro: Intro
var _waited := 0
var _out := "shots"
var _tab := ""
var _shot := SHOT


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_tab = args[1]
	if args.size() > 2:
		var parts := args[2].split("x")
		if parts.size() == 2:
			_shot = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = _shot
	_intro = Intro.new()
	add_child(_intro)


func _process(_delta: float) -> void:
	_waited += 1
	if _waited == 2 and _tab != "":
		_intro.show_tab(_tab)
	if _waited < 8:
		return
	var image := get_viewport().get_texture().get_image()
	var at := "%s/intro-%s-%dx%d.png" % [_out, _tab if _tab != "" else "how",
		_shot.x, _shot.y]
	image.save_png(at)
	print("wrote " + at)
	get_tree().quit()
