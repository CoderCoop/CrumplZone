class_name CityMap
extends Control

## The city, drawn.
##
## The level list was districts as headed sections: correct, and not a map. A
## player was told which part of town a building was in and shown nothing of
## where that is. This draws the place — water along one edge, a road grid, the
## river of the interchange cutting across — and puts a pin on each district.
##
## Tapping a pin selects a district; the levels in it are listed underneath by
## whoever owns this control. That two-step is deliberate on a phone: a map
## small enough to fit in a thumb's reach cannot also carry seventeen legible
## level tiles, and a pan-and-zoom map is a worse answer than a tap.
##
## Everything is drawn rather than drawn from an image, for the same reason the
## tool icons are: a font or an asset the build does not ship renders as
## nothing, and this project has been caught by that twice.

signal district_picked(district: String)

const WATER := Color(0.17, 0.26, 0.34)
const GROUND := Color(0.15, 0.16, 0.19)
const BLOCKS := Color(0.19, 0.20, 0.24)
const ROAD := Color(0.26, 0.27, 0.31)
const PARK := Color(0.17, 0.24, 0.19)
const INK := Color(0.10, 0.10, 0.12)
const LABEL := Color(0.86, 0.89, 0.93)

## Where the water sits, as a share of the map. The waterfront district is
## placed against it, which is the one piece of the layout that has to agree
## with districts.gd rather than merely look like a city.
const SHORE := 0.30

var selected := ""

var _pins: Array[Button] = []


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 230.0)
	_build_pins()
	resized.connect(_place_pins)


func _build_pins() -> void:
	for pin in _pins:
		pin.queue_free()
	_pins.clear()
	for entry in Districts.inhabited():
		var district: String = String(entry)
		var pin := Button.new()
		pin.text = Districts.title(district)
		pin.focus_mode = Control.FOCUS_NONE
		pin.clip_text = true
		pin.add_theme_font_size_override("font_size", 13)
		# Over the 44 px touch floor, and the districts are far enough apart on
		# the map that a thumb cannot land on two.
		# Wide enough for the longest district name at this font size. It was
		# 96 and "The Interchange" came out as "The Interchang".
		pin.custom_minimum_size = Vector2(104.0, 44.0)
		pin.pressed.connect(func() -> void:
			selected = district
			_restyle()
			queue_redraw()
			district_picked.emit(district))
		add_child(pin)
		_pins.append(pin)
	_restyle()
	_place_pins()


## A pin carries the colour of what stands in its district, so the map reads as
## somewhere with different buildings in different places even before anything
## is played.
func _restyle() -> void:
	for i in _pins.size():
		var district: String = String(Districts.inhabited()[i])
		var tint := _tint_of(district)
		var chosen: bool = district == selected
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = tint if chosen else tint.darkened(0.35)
			box.corner_radius_top_left = 8
			box.corner_radius_top_right = 8
			box.corner_radius_bottom_left = 8
			box.corner_radius_bottom_right = 8
			if chosen:
				box.border_width_top = 2
				box.border_width_bottom = 2
				box.border_width_left = 2
				box.border_width_right = 2
				box.border_color = LABEL
			_pins[i].add_theme_stylebox_override(state, box)
		var ink := INK if chosen else LABEL
		_pins[i].add_theme_color_override("font_color", ink)
		_pins[i].add_theme_color_override("font_pressed_color", ink)


func _tint_of(district: String) -> Color:
	for system in Districts.HOME:
		if String(Districts.HOME[system]) != district:
			continue
		match system:
			Architecture.CURTAIN_WALL, Architecture.FLAT_SLAB:
				return Color(0.62, 0.78, 0.92)
			Architecture.HOUSE, Architecture.PANEL:
				return Color(0.86, 0.55, 0.44)
			Architecture.RETAIL:
				return Color(0.90, 0.80, 0.46)
			Architecture.OVERPASS:
				return Color(0.78, 0.80, 0.83)
			Architecture.MASONRY, Architecture.STACK:
				return Color(0.84, 0.62, 0.46)
			Architecture.SHED, Architecture.STAND:
				return Color(0.70, 0.76, 0.72)
	return Color(0.75, 0.77, 0.80)


func _place_pins() -> void:
	var all := Districts.inhabited()
	for i in _pins.size():
		var at := Districts.at(String(all[i]))
		var pin := _pins[i]
		var want := pin.custom_minimum_size
		# Kept inside the map: a pin whose label runs off the edge is a label
		# that cannot be read.
		var x: float = clampf(size.x * at.x - want.x * 0.5, 4.0,
			maxf(size.x - want.x - 4.0, 4.0))
		var y: float = clampf(size.y * at.y - want.y * 0.5, 4.0,
			maxf(size.y - want.y - 4.0, 4.0))
		pin.position = Vector2(x, y)
		pin.size = want


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	# Water along the top-left, which is what the waterfront is on.
	var shore := size.y * SHORE
	draw_polygon(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(size.x * 0.44, 0.0),
		Vector2(size.x * 0.30, shore), Vector2(0.0, shore * 1.25)]),
		PackedColorArray([WATER, WATER, WATER, WATER]))

	# City blocks: a rough grid, denser toward the middle, so the ground reads
	# as built-up rather than as empty paper.
	var rng := RandomNumberGenerator.new()
	# Fixed, so the city is the same city every time it is drawn.
	rng.seed = 20260831
	for i in 46:
		var bx := rng.randf() * size.x
		var by := shore * 0.6 + rng.randf() * (size.y - shore * 0.6)
		var bw := rng.randf_range(10.0, 26.0)
		var bh := rng.randf_range(8.0, 20.0)
		if by < shore and bx < size.x * 0.34:
			continue
		draw_rect(Rect2(bx, by, bw, bh), BLOCKS)

	# A park, and the roads.
	draw_rect(Rect2(size.x * 0.56, size.y * 0.70, size.x * 0.14,
		size.y * 0.16), PARK)
	for share in [0.30, 0.58, 0.84]:
		draw_line(Vector2(0.0, size.y * share), Vector2(size.x, size.y * share),
			ROAD, 3.0)
	for share in [0.24, 0.52, 0.78]:
		draw_line(Vector2(size.x * share, shore * 0.5),
			Vector2(size.x * share, size.y), ROAD, 3.0)
	# The interchange: a wider road cutting across, which is what the highway
	# district is on.
	draw_line(Vector2(0.0, size.y * 0.66), Vector2(size.x, size.y * 0.46),
		ROAD.lightened(0.10), 6.0)
