class_name Backdrop
extends Node2D

## The place the building stands in: dusk sky, a city behind it, and the street
## it is being demolished on.
##
## Entirely cosmetic and entirely deterministic. It owns no bodies and takes no
## part in the simulation, so the solver sees exactly the same physics with or
## without it. Everything random here comes from a fixed seed, so the skyline
## does not reshuffle itself every time a level is rebuilt — which, given the
## solver rebuilds a level thousands of times, would be both distracting and a
## waste of the frames it takes to draw.
##
## Three depths, drawn far to near, each paler and softer than the one in front
## of it. That is the whole trick behind a city that looks like a city: haze
## with distance, detail with proximity.

const SEED := 8412

## Where the level is. A works shed does not stand in a glass financial
## district, and putting it there reads as a mistake rather than as variety —
## so the generator picks a setting that suits the building and the sky, the
## skyline and the ground all follow from it.
##
## Each is a whole palette rather than a tint: the sky it is happening under,
## the haze on the horizon, and how dense and how tall the city behind is. That
## is enough to make two levels of the same building feel like different jobs.
const SETTINGS := {
	"downtown": {
		"sky_top": Color(0.07, 0.09, 0.17), "sky_low": Color(0.48, 0.31, 0.27),
		"haze": Color(0.42, 0.30, 0.31),
		"far": Color(0.19, 0.20, 0.29), "mid": Color(0.13, 0.15, 0.22),
		"near": Color(0.08, 0.10, 0.15),
		"density": 1.0, "tall": 1.0, "lit": 1.0,
		"ground": Color(0.16, 0.17, 0.19),
	},
	"works": {
		# Industrial, before dawn: a colder sky, a low sprawling skyline of
		# sheds and stacks, and almost nothing lit.
		"sky_top": Color(0.05, 0.07, 0.13), "sky_low": Color(0.26, 0.25, 0.30),
		"haze": Color(0.30, 0.28, 0.30),
		"far": Color(0.15, 0.16, 0.21), "mid": Color(0.11, 0.12, 0.16),
		"near": Color(0.07, 0.08, 0.11),
		"density": 1.35, "tall": 0.55, "lit": 0.35,
		"ground": Color(0.19, 0.18, 0.16),
	},
	"waterfront": {
		# Wide, open and hazy, with the city set well back across the water.
		"sky_top": Color(0.10, 0.13, 0.22), "sky_low": Color(0.62, 0.46, 0.36),
		"haze": Color(0.55, 0.44, 0.40),
		"far": Color(0.24, 0.24, 0.31), "mid": Color(0.17, 0.18, 0.24),
		"near": Color(0.10, 0.12, 0.16),
		"density": 0.6, "tall": 0.8, "lit": 0.7,
		"ground": Color(0.20, 0.21, 0.23),
	},
	"estate": {
		# Overcast daylight, and a horizon of blocks exactly like the one being
		# taken down.
		"sky_top": Color(0.30, 0.33, 0.40), "sky_low": Color(0.55, 0.56, 0.58),
		"haze": Color(0.52, 0.53, 0.56),
		"far": Color(0.34, 0.35, 0.40), "mid": Color(0.26, 0.27, 0.32),
		"near": Color(0.18, 0.19, 0.23),
		"density": 1.1, "tall": 0.7, "lit": 0.15,
		"ground": Color(0.22, 0.22, 0.24),
	},
}

## Which setting this backdrop is drawing. Set before it enters the tree.
var setting := "downtown"

const SKY_TOP := Color(0.07, 0.09, 0.17)
const SKY_HORIZON := Color(0.48, 0.31, 0.27)
const HAZE := Color(0.42, 0.30, 0.31)

const FAR := Color(0.19, 0.20, 0.29)
const MID := Color(0.13, 0.15, 0.22)
const NEAR := Color(0.08, 0.10, 0.15)


## The palette for the setting in force, falling back to downtown for a name
## that does not exist rather than drawing nothing.
func _palette() -> Dictionary:
	return SETTINGS.get(setting, SETTINGS["downtown"])

const WARM_WINDOW := Color(1.0, 0.82, 0.45, 0.85)
const COOL_WINDOW := Color(0.62, 0.82, 1.0, 0.55)
const BEACON := Color(1.0, 0.32, 0.28, 0.9)

const ROAD := Color(0.16, 0.17, 0.19)
const PAVEMENT := Color(0.22, 0.23, 0.26)
const KERB := Color(0.34, 0.35, 0.38)
const LANE := Color(0.62, 0.60, 0.42, 0.55)
const HOARDING := Color(0.72, 0.55, 0.16)
const LAMP := Color(1.0, 0.86, 0.55)

var floor_y := 540.0
var extent := Rect2(-200.0, -400.0, 1400.0, 1200.0)

var _layers: Array = []
var _lamps: Array = []


func _ready() -> void:
	z_index = -100
	_build_city()


## Paints whatever the camera can see. main.gd works out that rectangle after
## framing the level, because a phone in portrait sees a taller slice of world
## than a laptop does and a sky that stops short of the top of the screen looks
## like a bug.
func cover(world: Rect2) -> void:
	extent = world
	_build_city()
	queue_redraw()


## Rebuilds the city for the current setting. Called when a level is built,
## since the setting arrives with it.
func rebuild() -> void:
	_build_city()
	queue_redraw()


func _build_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# base_offset is how far above the road each layer's feet sit; the further
	# away, the higher and the hazier.
	var pal := _palette()
	var tall: float = float(pal["tall"])
	var dense: float = float(pal["density"])
	_layers = [
		_row(rng, 150.0, 120.0 * tall, 320.0 * tall, 54.0 / dense, 130.0 / dense,
			pal["far"], 0.55 * float(pal["lit"])),
		_row(rng, 96.0, 90.0 * tall, 240.0 * tall, 46.0 / dense, 108.0 / dense,
			pal["mid"], 0.35 * float(pal["lit"])),
		_row(rng, 52.0, 60.0 * tall, 170.0 * tall, 62.0 / dense, 150.0 / dense,
			pal["near"], 0.22 * float(pal["lit"])),
	]
	_lamps = []
	var x := extent.position.x + 60.0
	while x < extent.end.x:
		_lamps.append(x)
		x += 220.0


func _row(rng: RandomNumberGenerator, base: float, low: float, high: float,
		thin: float, wide: float, colour: Color, lit_share: float) -> Dictionary:
	var blocks: Array = []
	var x := extent.position.x - 40.0
	while x < extent.end.x + 40.0:
		var w := rng.randf_range(thin, wide)
		var h := rng.randf_range(low, high)
		blocks.append({
			"x": x, "w": w, "h": h,
			"lit": rng.randf() < lit_share,
			# What sits on the roof: nothing, a setback, a spire or a tank.
			"top": rng.randi_range(0, 3),
			"warm": rng.randf() < 0.7,
			"beacon": rng.randf() < 0.18,
		})
		x += w + rng.randf_range(4.0, 22.0)
	return {"base": base, "colour": colour, "blocks": blocks}


func _draw() -> void:
	_draw_sky()
	for layer in _layers:
		_draw_row(layer)
	_draw_ground()


## Banded rather than a shader: a couple of dozen rectangles is enough for a
## dusk gradient and costs nothing on a phone.
func _draw_sky() -> void:
	var pal := _palette()
	var sky_top: Color = pal["sky_top"]
	var sky_low: Color = pal["sky_low"]
	const BANDS := 26
	var top := extent.position.y
	var height := floor_y - top
	for i in BANDS:
		var t := float(i) / float(BANDS - 1)
		var band := Rect2(
			extent.position.x, top + height * float(i) / BANDS,
			extent.size.x, height / BANDS + 1.0)
		draw_rect(band, sky_top.lerp(sky_low, pow(t, 2.4)))


func _draw_row(layer: Dictionary) -> void:
	var base: float = floor_y - float(layer["base"])
	var colour: Color = layer["colour"]
	for b in layer["blocks"]:
		var x: float = b["x"]
		var w: float = b["w"]
		var h: float = b["h"]
		draw_rect(Rect2(x, base - h, w, h), colour)
		_draw_roof(b, x, base - h, w, colour)
		if b["lit"]:
			_draw_windows(b, x, base - h, w, h)


## Roofs are what stop a skyline reading as a bar chart: a setback, a spire, a
## water tank, or nothing at all.
func _draw_roof(b: Dictionary, x: float, top: float, w: float, colour: Color) -> void:
	match int(b["top"]):
		1:      # setback: a smaller storey on top
			draw_rect(Rect2(x + w * 0.2, top - w * 0.28, w * 0.6, w * 0.28), colour)
		2:      # spire
			var spire := x + w * 0.5
			draw_rect(Rect2(spire - 2.0, top - w * 0.75, 4.0, w * 0.75), colour)
			if b["beacon"]:
				draw_circle(Vector2(spire, top - w * 0.75), 2.5, BEACON)
		3:      # water tank on legs
			var tank := Rect2(x + w * 0.32, top - 22.0, w * 0.36, 14.0)
			draw_rect(tank, colour)
			draw_rect(Rect2(tank.position.x + 2.0, tank.end.y, 3.0, 8.0), colour)
			draw_rect(Rect2(tank.end.x - 5.0, tank.end.y, 3.0, 8.0), colour)


## Lit windows in a grid, deterministic from the building's own position so the
## same tower always lights the same rooms.
func _draw_windows(b: Dictionary, x: float, top: float, w: float, h: float) -> void:
	var colour: Color = WARM_WINDOW if b["warm"] else COOL_WINDOW
	var step := 16.0
	var rows := int(h / 20.0)
	var cols := int(w / step)
	for r in rows:
		for c in cols:
			var cell := int(x) * 7 + r * 31 + c * 13
			if cell % 5 != 0:
				continue
			var lit := colour
			# A few rooms brighter than the rest, so the grid is not uniform.
			if cell % 15 == 0:
				lit = colour.lightened(0.25)
			draw_rect(Rect2(x + 5.0 + c * step, top + 9.0 + r * 20.0, 5.0, 8.0), lit)


## The street the site sits on. Everything here is below the level's own
## footing block, which is 48 px deep, so the kerb starts under that rather
## than being hidden by it.
func _draw_ground() -> void:
	var left := extent.position.x
	var width := extent.size.x
	var bottom := extent.end.y

	# A band of haze where the city meets the ground, so the skyline sits in
	# the air rather than on the pavement.
	var haze: Color = _palette()["haze"]
	draw_rect(Rect2(left, floor_y - 60.0, width, 60.0), Color(haze.r, haze.g, haze.b, 0.18))

	draw_rect(Rect2(left, floor_y, width, bottom - floor_y), PAVEMENT)
	draw_rect(Rect2(left, floor_y + 92.0, width, maxf(bottom - floor_y - 92.0, 0.0)),
		_palette()["ground"])
	draw_rect(Rect2(left, floor_y + 88.0, width, 4.0), KERB)

	# Demolition hoarding along the plot edge: diagonal hazard stripes.
	var band := Rect2(left, floor_y + 54.0, width, 16.0)
	draw_rect(band, Color(0.13, 0.14, 0.16))
	var stripe := band.position.x
	while stripe < band.end.x:
		draw_line(
			Vector2(stripe, band.end.y), Vector2(stripe + 16.0, band.position.y),
			HOARDING, 6.0)
		stripe += 30.0

	# Street lights: a post standing at the kerb with its head clear of the
	# hoarding, and a pool of light on the road under it. The glow is three
	# nested cones rather than one, because a single flat trapezoid at low
	# alpha reads as a grey shape painted on the road rather than as light.
	for x in _lamps:
		var foot := floor_y + 96.0
		var head := Vector2(float(x) + 14.0, foot - 88.0)
		draw_rect(Rect2(float(x) - 1.5, head.y, 3.0, 88.0), Color(0.31, 0.32, 0.36))
		draw_rect(Rect2(float(x) - 1.5, head.y - 2.0, 16.0, 3.0), Color(0.31, 0.32, 0.36))
		for step in 3:
			var spread := 26.0 + float(step) * 22.0
			var fade := 0.10 - float(step) * 0.03
			draw_colored_polygon(PackedVector2Array([
				head + Vector2(-5.0, 2.0), head + Vector2(5.0, 2.0),
				Vector2(head.x + spread, foot + 26.0),
				Vector2(head.x - spread, foot + 26.0)]),
				Color(1.0, 0.86, 0.55, fade))
		draw_circle(head, 11.0, Color(1.0, 0.86, 0.55, 0.16))
		draw_circle(head, 4.0, LAMP)

	# Lane markings, so the asphalt reads as a road rather than as a gap at the
	# bottom of the screen.
	var lane := floor_y + 150.0
	if lane < bottom:
		var dash := left
		while dash < extent.end.x:
			draw_rect(Rect2(dash, lane, 34.0, 5.0), LANE)
			dash += 74.0
