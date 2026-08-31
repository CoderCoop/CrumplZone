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
		"landmarks": ["towercrane"],
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
		"landmarks": ["chimney", "drum", "chimney"],
	},
	"waterfront": {
		# Wide, open and hazy, with the city set well back across the water.
		"sky_top": Color(0.10, 0.13, 0.22), "sky_low": Color(0.62, 0.46, 0.36),
		"haze": Color(0.55, 0.44, 0.40),
		"far": Color(0.24, 0.24, 0.31), "mid": Color(0.17, 0.18, 0.24),
		"near": Color(0.10, 0.12, 0.16),
		"density": 0.6, "tall": 0.8, "lit": 0.7,
		"ground": Color(0.20, 0.21, 0.23),
		"landmarks": ["crane"],
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
		"landmarks": ["gable"],
	},
	"strip": {
		# Late afternoon over a retail park: low, wide, half-empty, and the
		# tallest things on the horizon are the signs.
		"sky_top": Color(0.22, 0.27, 0.38), "sky_low": Color(0.72, 0.56, 0.38),
		"haze": Color(0.60, 0.50, 0.42),
		"far": Color(0.29, 0.29, 0.33), "mid": Color(0.22, 0.22, 0.26),
		"near": Color(0.15, 0.15, 0.18),
		"density": 0.75, "tall": 0.42, "lit": 0.55,
		"ground": Color(0.21, 0.21, 0.22),
		"landmarks": ["pylon", "shed", "pylon"],
	},
	"highway": {
		# Night under the interchange: sodium haze, and a road on piers running
		# the whole width behind the site.
		"sky_top": Color(0.06, 0.07, 0.12), "sky_low": Color(0.34, 0.24, 0.22),
		"haze": Color(0.34, 0.26, 0.24),
		"far": Color(0.17, 0.17, 0.22), "mid": Color(0.12, 0.13, 0.17),
		"near": Color(0.08, 0.09, 0.12),
		"density": 1.15, "tall": 0.5, "lit": 0.45,
		"ground": Color(0.17, 0.17, 0.18),
		"flyover": true, "landmarks": [],
	},
	"stadium": {
		# Floodlit, with the masts still on and the stand behind them. Cool,
		# because the light on the horizon is lamps rather than the sun.
		"sky_top": Color(0.05, 0.08, 0.14), "sky_low": Color(0.22, 0.27, 0.33),
		"haze": Color(0.40, 0.44, 0.48),
		"far": Color(0.20, 0.22, 0.26), "mid": Color(0.15, 0.16, 0.20),
		"near": Color(0.10, 0.11, 0.14),
		"density": 0.85, "tall": 0.5, "lit": 0.30,
		"ground": Color(0.18, 0.19, 0.19),
		"landmarks": ["mast", "stand", "mast"],
	},
}

## What stands on the horizon in each setting, and how far apart. The palette
## alone was not enough: two districts under different skies still read as the
## same place, because a skyline of plain boxes is a skyline of plain boxes.
## A gantry crane says dockside, a floodlight mast says ground, a sign pylon
## says retail park — one silhouette does more than any amount of tinting.
## Spaced for the frame the game actually uses, not for the one the tool
## renders. skyshot stands well back to make a horizon judgeable; main.gd fills
## the screen with the building, and at that zoom a landmark every 720 px is a
## landmark nobody sees. Measured by rendering the same skies at both.
const LANDMARK_GAP := {
	"towercrane": 460.0, "chimney": 260.0, "drum": 260.0, "crane": 320.0,
	"gable": 170.0, "pylon": 230.0, "shed": 300.0, "mast": 250.0,
	"stand": 480.0,
}

## How far above the road the landmarks stand. Level with the middle row's own
## feet, not the near row's: at 78 the shorter landmarks stood among the near
## buildings, the same height and much the same colour, and a retail shed was
## simply not there. The near row still overlaps their feet, which is the point
## — they should be in the city, not in front of it.
const LANDMARK_BASE := 104.0

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
var _marks: Array = []


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
	_build_landmarks(rng, pal)


## The silhouettes that say which part of town this is. Placed with the same
## seeded generator as the rows, so a level's horizon is the same horizon every
## time it is built.
func _build_landmarks(rng: RandomNumberGenerator, pal: Dictionary) -> void:
	_marks = []
	var kinds: Array = pal.get("landmarks", [])
	if kinds.is_empty():
		return
	var at := extent.position.x - 40.0
	var pick := 0
	while at < extent.end.x + 40.0:
		var kind := String(kinds[pick % kinds.size()])
		pick += 1
		_marks.append({
			"x": at, "kind": kind, "scale": rng.randf_range(0.82, 1.22),
		})
		at += float(LANDMARK_GAP.get(kind, 400.0)) * rng.randf_range(0.8, 1.35)


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
	_draw_row(_layers[0])
	_draw_row(_layers[1])
	# Between the middle row and the near one. In front of them a landmark
	# would be the subject of the picture, and behind them all it would be a
	# smudge on the horizon; here the city overlaps it and it reads as
	# standing in the city rather than as painted on the sky.
	_draw_landmarks()
	_draw_row(_layers[2])
	_draw_ground()


func _draw_landmarks() -> void:
	var pal := _palette()
	# Lighter than the row they stand among, not darker. The first attempt
	# tinted them toward the near row and they vanished: a dark silhouette on a
	# dark skyline is a dark skyline. Distance reads as haze in these palettes,
	# so something in the middle distance sits between "far" and "mid".
	var ink: Color = Color(pal["far"]).lerp(Color(pal["mid"]), 0.20)
	if bool(pal.get("flyover", false)):
		_draw_flyover(ink)
	for m in _marks:
		var x: float = float(m["x"])
		var s: float = float(m["scale"])
		var foot: float = floor_y - LANDMARK_BASE
		match String(m["kind"]):
			"towercrane":
				_mark_tower_crane(x, s, foot, ink)
			"crane":
				_mark_gantry_crane(x, s, foot, ink)
			"chimney":
				_mark_chimney(x, s, foot, ink)
			"drum":
				_mark_gas_holder(x, s, foot, ink)
			"gable":
				_mark_house(x, s, foot, ink)
			"pylon":
				_mark_sign(x, s, foot, ink)
			"shed":
				_mark_retail_shed(x, s, foot, ink)
			"mast":
				_mark_floodlight(x, s, foot, ink)
			"stand":
				_mark_stand(x, s, foot, ink)


## Downtown: something else is going up while this comes down.
func _mark_tower_crane(x: float, s: float, foot: float, ink: Color) -> void:
	var h := 190.0 * s
	var jib := foot - h
	draw_rect(Rect2(x - 3.5, jib, 7.0, h), ink)
	draw_rect(Rect2(x - 46.0 * s, jib - 5.0, 168.0 * s, 5.0), ink)
	draw_rect(Rect2(x - 46.0 * s, jib - 12.0, 22.0 * s, 12.0), ink)
	draw_line(Vector2(x + 82.0 * s, jib), Vector2(x + 82.0 * s, jib + 44.0),
		ink, 1.5)
	draw_circle(Vector2(x, jib - 16.0), 2.5, BEACON)


## Waterfront: a portal crane with its jib out over the water.
func _mark_gantry_crane(x: float, s: float, foot: float, ink: Color) -> void:
	var h := 96.0 * s
	var span := 82.0 * s
	draw_rect(Rect2(x, foot - h, 6.0, h), ink)
	draw_rect(Rect2(x + span - 6.0, foot - h, 6.0, h), ink)
	draw_rect(Rect2(x - 34.0 * s, foot - h - 10.0, span + 68.0 * s, 10.0), ink)
	var peak := Vector2(x + span * 0.5, foot - h - 48.0 * s)
	draw_line(peak, Vector2(x + 4.0, foot - h - 10.0), ink, 4.0)
	draw_line(peak, Vector2(x + span - 4.0, foot - h - 10.0), ink, 4.0)
	draw_line(Vector2(x - 20.0 * s, foot - h),
		Vector2(x - 20.0 * s, foot - h + 30.0), ink, 2.0)


## The works: a tapered brick chimney with its collar bands.
func _mark_chimney(x: float, s: float, foot: float, ink: Color) -> void:
	var h := 155.0 * s
	var w := 13.0 * s
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - w, foot), Vector2(x + w, foot),
		Vector2(x + w * 0.6, foot - h), Vector2(x - w * 0.6, foot - h)]), ink)
	for i in 3:
		var band := foot - h * (0.44 + 0.17 * float(i))
		draw_rect(Rect2(x - w * 0.95, band, w * 1.9, 3.0), ink.lightened(0.12))


## The works: a gas holder in its guide frame.
func _mark_gas_holder(x: float, s: float, foot: float, ink: Color) -> void:
	var r := 46.0 * s
	draw_rect(Rect2(x - r, foot - r * 1.15, r * 2.0, r * 1.15), ink)
	for i in 3:
		draw_rect(Rect2(x - r, foot - r * (0.30 + 0.27 * float(i)), r * 2.0,
			2.5), ink.lightened(0.12))
	draw_rect(Rect2(x - r - 6.0, foot - r * 1.34, 4.0, r * 1.34), ink)
	draw_rect(Rect2(x + r + 2.0, foot - r * 1.34, 4.0, r * 1.34), ink)


## The old town: the same two-up two-down that is being taken down, in a row.
func _mark_house(x: float, s: float, foot: float, ink: Color) -> void:
	var w := 76.0 * s
	var h := 42.0 * s
	draw_rect(Rect2(x, foot - h, w, h), ink)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 5.0, foot - h),
		Vector2(x + w * 0.5, foot - h - 26.0 * s),
		Vector2(x + w + 5.0, foot - h)]), ink.lightened(0.09))
	draw_rect(Rect2(x + w * 0.70, foot - h - 30.0 * s, 8.0, 22.0 * s), ink)


## The retail park: a sign on a pole, taller than anything it advertises.
func _mark_sign(x: float, s: float, foot: float, ink: Color) -> void:
	var h := 74.0 * s
	draw_rect(Rect2(x - 4.0, foot - h, 8.0, h), ink)
	# The sign is the landmark, not the pole it is on. At 42 x 27 on a 104 pole
	# it read as an aerial.
	var box := Rect2(x - 29.0 * s, foot - h - 36.0 * s, 58.0 * s, 36.0 * s)
	draw_rect(box, ink.lightened(0.22))
	draw_rect(box.grow(-4.0), Color(1.0, 0.82, 0.45, 0.55))


## The retail park: a long shed with a canopy along the front of it.
func _mark_retail_shed(x: float, s: float, foot: float, ink: Color) -> void:
	var w := 210.0 * s
	var h := 56.0 * s
	draw_rect(Rect2(x, foot - h, w, h), ink)
	draw_rect(Rect2(x - 6.0, foot - h - 7.0, w + 12.0, 7.0), ink.lightened(0.13))
	draw_rect(Rect2(x + 10.0, foot - 15.0, w - 20.0, 4.0), ink.lightened(0.22))


## The ground: a lattice mast with the lights still on.
func _mark_floodlight(x: float, s: float, foot: float, ink: Color) -> void:
	var h := 168.0 * s
	draw_rect(Rect2(x - 6.0, foot - h, 12.0, h), ink)
	# Braced both ways, so it reads as a lattice rather than as a pole with
	# scratches on it.
	var rung := foot - 10.0
	while rung > foot - h:
		draw_line(Vector2(x - 6.0, rung), Vector2(x + 6.0, rung - 16.0), ink,
			1.5)
		draw_line(Vector2(x + 6.0, rung), Vector2(x - 6.0, rung - 16.0), ink,
			1.5)
		rung -= 16.0
	var head := Rect2(x - 28.0 * s, foot - h - 24.0 * s, 56.0 * s, 24.0 * s)
	draw_rect(head, ink.lightened(0.14))
	# The glow around the head, not just the lamps. A floodlight that is only
	# four dots is four dots; the halo is the thing that says the ground is in
	# use tonight.
	for step in 3:
		draw_circle(head.get_center(), (16.0 + float(step) * 15.0) * s,
			Color(0.86, 0.92, 1.0, 0.055))
	for i in 4:
		draw_circle(Vector2(
			head.position.x + head.size.x * (0.16 + 0.23 * float(i)),
			head.position.y + head.size.y * 0.5), 2.6 * s,
			Color(1.0, 0.96, 0.82, 0.85))


## The ground: a raked terrace with a roof reaching out over it.
func _mark_stand(x: float, s: float, foot: float, ink: Color) -> void:
	var w := 300.0 * s
	var h := 74.0 * s
	# The terrace, high at the back and raked down toward the pitch. Drawn
	# lighter than the rest: the first version was the same tone as the middle
	# row and only its roof stood out, so a stand read as a beam hanging in the
	# air over the skyline.
	var body := ink.lightened(0.13)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, foot), Vector2(x + w, foot),
		Vector2(x + w, foot - h * 0.42), Vector2(x, foot - h)]), body)
	# Steps across it, which is what says seating rather than a wedge.
	for i in 4:
		var t: float = 0.22 + 0.19 * float(i)
		draw_line(Vector2(x + w * t, foot),
			Vector2(x + w * t, foot - h * lerpf(1.0, 0.42, t)),
			body.darkened(0.16), 1.5)
	# The back wall the roof stands on.
	draw_rect(Rect2(x - 7.0, foot - h - 30.0, 14.0, h + 30.0),
		body.lightened(0.08))
	# The roof, cantilevered out from that wall over the terrace.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 9.0, foot - h - 30.0),
		Vector2(x + w * 0.86, foot - h * 0.52 - 26.0),
		Vector2(x + w * 0.86, foot - h * 0.52 - 14.0),
		Vector2(x - 9.0, foot - h - 18.0)]), body.lightened(0.14))


## The interchange: a road on piers running the whole width behind the site.
## Continuous rather than placed, because a flyover that stops is a bridge.
func _draw_flyover(ink: Color) -> void:
	var deck := floor_y - 150.0
	var left := extent.position.x
	var right := extent.end.x
	var foot := floor_y - LANDMARK_BASE
	var pier := left + 60.0
	while pier < right:
		draw_rect(Rect2(pier - 17.0, deck + 16.0, 34.0, 7.0), ink)
		draw_rect(Rect2(pier - 9.0, deck + 16.0, 18.0,
			maxf(foot - deck - 16.0, 0.0)), ink)
		pier += 190.0
	draw_rect(Rect2(left, deck, right - left, 16.0), ink)
	draw_rect(Rect2(left, deck - 8.0, right - left, 3.0), ink.lightened(0.16))
	var post := left
	while post < right:
		draw_rect(Rect2(post, deck - 8.0, 2.0, 8.0), ink.lightened(0.16))
		post += 22.0


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
