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

const SEED := 8412

const SKY_TOP := Color(0.09, 0.11, 0.19)
const SKY_HORIZON := Color(0.45, 0.29, 0.26)
const CITY_FAR := Color(0.14, 0.16, 0.24)
const CITY_NEAR := Color(0.10, 0.12, 0.18)
const LIT_WINDOW := Color(1.0, 0.83, 0.48, 0.75)
const ROAD := Color(0.16, 0.17, 0.19)
const PAVEMENT := Color(0.22, 0.23, 0.26)
const KERB := Color(0.34, 0.35, 0.38)
const LANE := Color(0.62, 0.60, 0.42, 0.55)
const HOARDING := Color(0.72, 0.55, 0.16)

var floor_y := 540.0
var extent := Rect2(-200.0, -400.0, 1400.0, 1200.0)

var _far: Array = []
var _near: Array = []


func _ready() -> void:
	z_index = -100
	_build_skyline()


## Paints whatever the camera can see. main.gd works out that rectangle after
## framing the level, because a phone in portrait sees a taller slice of world
## than a laptop does and a sky that stops short of the top of the screen looks
## like a bug.
func cover(world: Rect2) -> void:
	extent = world
	_build_skyline()
	queue_redraw()


func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_far = []
	_near = []
	var x := extent.position.x
	while x < extent.end.x:
		var w := rng.randf_range(46.0, 104.0)
		var h := rng.randf_range(90.0, 260.0)
		_far.append({"x": x, "w": w, "h": h, "lit": rng.randf()})
		x += w + rng.randf_range(6.0, 26.0)
	x = extent.position.x - 30.0
	while x < extent.end.x:
		var w := rng.randf_range(60.0, 130.0)
		var h := rng.randf_range(50.0, 150.0)
		_near.append({"x": x, "w": w, "h": h, "lit": rng.randf()})
		x += w + rng.randf_range(14.0, 40.0)


func _draw() -> void:
	_draw_sky()
	_draw_city(_far, CITY_FAR, 118.0, 0.55)
	_draw_city(_near, CITY_NEAR, 64.0, 0.35)
	_draw_ground()


## Banded rather than a shader: a dozen rectangles is enough for a dusk
## gradient and costs nothing on a phone.
func _draw_sky() -> void:
	const BANDS := 18
	var top := extent.position.y
	var height := floor_y - top
	for i in BANDS:
		var t := float(i) / float(BANDS - 1)
		var band := Rect2(
			extent.position.x, top + height * float(i) / BANDS,
			extent.size.x, height / BANDS + 1.0)
		draw_rect(band, SKY_TOP.lerp(SKY_HORIZON, pow(t, 2.2)))


func _draw_city(blocks: Array, colour: Color, base_offset: float, window_odds: float) -> void:
	var base := floor_y - base_offset
	for b in blocks:
		draw_rect(Rect2(b["x"], base - b["h"], b["w"], b["h"]), colour)
		# A few lit windows, so the skyline reads as buildings rather than as
		# a bar chart.
		if b["lit"] > window_odds:
			continue
		var rows := int(b["h"] / 22.0)
		var cols := int(b["w"] / 18.0)
		for r in rows:
			for c in cols:
				# Deterministic scatter: no RNG call, just a hash of the cell.
				if (int(b["x"]) + r * 7 + c * 13) % 5 != 0:
					continue
				draw_rect(Rect2(
					b["x"] + 6.0 + c * 18.0, base - b["h"] + 8.0 + r * 22.0,
					6.0, 9.0), LIT_WINDOW)


## The street the site sits on. Everything here is below the level's own
## footing block, which is 48 px deep, so the kerb starts under that rather
## than being hidden by it.
func _draw_ground() -> void:
	var left := extent.position.x
	var width := extent.size.x
	var bottom := extent.end.y

	# Pavement, then the kerb edge, then asphalt.
	draw_rect(Rect2(left, floor_y, width, bottom - floor_y), PAVEMENT)
	draw_rect(Rect2(left, floor_y + 92.0, width, maxf(bottom - floor_y - 92.0, 0.0)), ROAD)
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

	# Lane markings, so the asphalt reads as a road rather than as a gap at the
	# bottom of the screen.
	var lane := floor_y + 150.0
	if lane < bottom:
		var dash := left
		while dash < extent.end.x:
			draw_rect(Rect2(dash, lane, 34.0, 5.0), LANE)
			dash += 74.0
