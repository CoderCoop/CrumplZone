class_name CityMap
extends Control

## The city as a model on a board, seen from above.
##
## This was a flat top-down map: correct as cartography and wrong as a thing to
## look at. A map tells you where a district is; it does not tell you that
## downtown is towers and the Old Town is two-storey brick, which is the part
## that makes picking one feel like picking a place. So the city is drawn the
## way an architect's model is photographed — an oblique projection, everything
## extruded, lit from one side, sitting on a baseboard with a visible cut edge.
##
## Every footprint is a box: a top face, and the two walls that face the
## viewer. Heights come from the district a block is nearest, so the shape of
## the skyline says what is built there before a single label is read.
##
## Boxes are drawn back to front (painter's algorithm, keyed on the near
## corner) because there is no depth buffer in a Control's draw list. The
## raised interchange is cut into segments so it interleaves with the buildings
## it passes rather than being flatly in front of or behind all of them.
##
## Tapping a pin selects a district; the levels in it are listed underneath by
## whoever owns this control. That two-step is deliberate on a phone: a model
## small enough to fit in a thumb's reach cannot also carry seventeen legible
## level tiles, and pan-and-zoom is a worse answer than a tap.
##
## Everything is drawn rather than loaded, for the same reason the tool icons
## are: a font or an asset the build does not ship renders as nothing, and this
## project has been caught by that twice.

signal district_picked(district: String)

const WATER := Color(0.17, 0.30, 0.42)
const QUAY := Color(0.42, 0.43, 0.44)
const BOARD := Color(0.27, 0.27, 0.25)
const BOARD_NEAR := Color(0.13, 0.13, 0.15)
const BOARD_SIDE := Color(0.10, 0.10, 0.12)
const GREEN := Color(0.25, 0.35, 0.25)
const ROAD := Color(0.33, 0.34, 0.37)
const CONCRETE := Color(0.62, 0.63, 0.66)
const INK := Color(0.10, 0.10, 0.12)
const LABEL := Color(0.88, 0.91, 0.95)
const STEM := Color(0.58, 0.61, 0.66)

## The model on its board, in screen pixels.
const MARGIN := 10.0
## How thick the baseboard is. This is the whole difference between a model and
## a map: a map has no edge, a model is a slab of something sitting on a table.
const SLAB := 9.0
## Room above the far corner of the board for the tallest tower and its pin.
const HEAD := 62.0

## The light is behind and to one side, so tops are brightest, the wall facing
## along the model is next, and the wall facing the viewer's side is in shade.
const TOP_LIT := 0.12
const WALL_LIT := 0.20
const WALL_DIM := 0.44

## How tall each district builds, in screen pixels at the model's scale. These
## are the skyline, so they are ordered the way the districts actually are:
## downtown towers over everything, the retail park is a single storey and a
## sign, the interchange is not a building at all.
const RISE := {
	Districts.DOWNTOWN: 40.0,
	Districts.WATERFRONT: 22.0,
	Districts.WORKS: 15.0,
	Districts.HIGHWAY: 9.0,
	Districts.STRIP: 11.0,
	Districts.RESIDENTIAL: 17.0,
	Districts.STADIUM: 24.0,
}

## The interchange runs across the board, through the highway district's own
## spot rather than merely near it.
const ROAD_FROM := Vector2(0.0, 0.49)
const ROAD_TO := Vector2(1.0, 0.79)
const DECK := 15.0
const SPANS := 7

## The park and the pitch, in plan coordinates. Ground that is deliberately not
## built on, so the model has somewhere for the eye to rest.
const PARK := Rect2(0.50, 0.60, 0.13, 0.13)
const PITCH_R := 0.085

## How many parcels the board is divided into each way. Buildings are placed
## inside parcels rather than scattered, because a scatter reads as noise and a
## grid with gaps reads as streets.
const PARCELS := 7

var selected := ""

var _pins: Array[Button] = []
var _anchors: Array[Vector2] = []
var _feet: Array[Vector2] = []


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 330.0)
	_build_pins()
	resized.connect(func() -> void:
		_place_pins()
		queue_redraw())


# --- projection ------------------------------------------------------------

## Plan coordinates run 0..1 both ways over the board; the result is where that
## spot lands on screen. The far corner is (0, 0) at the top, the near corner
## is (1, 1) at the bottom, so depth is simply u + v.
func _ground(u: float, v: float) -> Vector2:
	var top: float = MARGIN + HEAD
	var hy: float = maxf((size.y - MARGIN - SLAB - top) * 0.5, 1.0)
	# Held to a fixed proportion rather than filling the width. A Control that
	# expands sideways and not downward turns the board into a flat ribbon on a
	# wide window, and a model that has been rolled out is not a model.
	var hx: float = minf(maxf(size.x * 0.5 - MARGIN, 1.0), hy * 2.4)
	return Vector2(size.x * 0.5 + (u - v) * hx, top + (u + v) * hy)


func _box(u0: float, v0: float, u1: float, v1: float, rise: float,
		tint: Color) -> void:
	var lift := Vector2(0.0, -rise)
	var far := _ground(u0, v0)
	var right := _ground(u1, v0)
	var near := _ground(u1, v1)
	var left := _ground(u0, v1)
	draw_colored_polygon(PackedVector2Array([
		right, near, near + lift, right + lift]), tint.darkened(WALL_LIT))
	draw_colored_polygon(PackedVector2Array([
		near, left, left + lift, near + lift]), tint.darkened(WALL_DIM))
	draw_colored_polygon(PackedVector2Array([
		far + lift, right + lift, near + lift, left + lift]),
		tint.lightened(TOP_LIT))


## A flat patch of ground — water, grass, tarmac — projected as it lies.
func _patch(points: PackedVector2Array, tint: Color) -> void:
	var out := PackedVector2Array()
	for p in points:
		out.append(_ground(p.x, p.y))
	draw_colored_polygon(out, tint)


func _disc(at: Vector2, radius: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in 18:
		var a: float = TAU * float(i) / 18.0
		points.append(at + Vector2(cos(a), sin(a)) * radius)
	_patch(points, tint)


# --- what stands where -----------------------------------------------------

## Which district a spot on the board belongs to: the nearest one. Blocks take
## their height and colour from it, so the model grows tall around downtown and
## stays low out by the works without anything being placed by hand.
func _district_at(u: float, v: float) -> String:
	var best := ""
	var nearest := INF
	for entry in Districts.inhabited():
		var district := String(entry)
		var d: float = Districts.at(district).distance_to(Vector2(u, v))
		if d < nearest:
			nearest = d
			best = district
	return best


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


## The shoreline, as a plan u for a given v. It widens toward the near corner,
## because on this projection a strip of even width along the edge came out as
## a sliver that read as a shadow rather than as water.
##
## The waterfront district sits at u = 0.20, so the water has to stay inboard
## of that or the warehouses are in it — this is the one piece of the layout
## that has to agree with districts.gd rather than merely look like a city.
func _shore(v: float) -> float:
	return 0.110 + 0.050 * v + 0.025 * sin(v * 7.0)


func _wet(u: float, v: float) -> bool:
	return u < _shore(v)


func _open(u: float, v: float) -> bool:
	if _wet(u, v):
		return false
	if PARK.has_point(Vector2(u, v)):
		return false
	var ground := Districts.at(Districts.STADIUM)
	return Vector2(u, v).distance_to(ground) >= PITCH_R * 1.15


# --- pins ------------------------------------------------------------------

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
		# Over the 44 px touch floor, and wide enough for the longest district
		# name at this size. It was 96 and "The Interchange" came out as "The
		# Interchang", which is why the district is called Interchange now.
		pin.custom_minimum_size = Vector2(104.0, 44.0)
		pin.pressed.connect(func() -> void:
			selected = district
			_restyle()
			_place_pins()
			queue_redraw()
			district_picked.emit(district))
		add_child(pin)
		_pins.append(pin)
	_restyle()
	_place_pins()


## A pin carries the colour of what stands in its district, so the model reads
## as somewhere with different buildings in different places even before
## anything is played.
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
			box.shadow_size = 3
			box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
			box.shadow_offset = Vector2(0.0, 2.0)
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


## Pins stand on the model rather than lying on it: each one is anchored to its
## district's spot on the board and lifted clear of the buildings there on a
## stem, the way a label is pinned into an architect's model.
##
## The projection is what makes this hard. A flat map spread the districts over
## the whole rectangle; an oblique one puts screen x on u - v, which for a city
## laid out like this one squeezes every district toward the middle — the first
## render had four of the seven pins piled on top of each other and two of them
## invisible.
##
## So pins are placed far corner first and any clash is resolved by moving the
## later pin *toward* the viewer. Downward, not upward: everything already
## placed is above, so pushing up is pushing into the pile, which is exactly
## what the first attempt did. The foot stays at the district's real spot, so a
## pin that has been moved still points at the right part of town.
func _place_pins() -> void:
	var all := Districts.inhabited()
	_anchors.clear()
	_feet.clear()
	_anchors.resize(_pins.size())
	_feet.resize(_pins.size())

	var order: Array[int] = []
	var ideal: Array[Vector2] = []
	var anchors: Array[Vector2] = []
	for i in _pins.size():
		var district := String(all[i])
		var at := Districts.at(district)
		var anchor := _ground(at.x, at.y)
		var want := _pins[i].custom_minimum_size
		var lift: float = float(RISE.get(district, 14.0)) + 18.0
		anchors.append(anchor)
		ideal.append(Vector2(
			clampf(anchor.x - want.x * 0.5, 2.0,
				maxf(size.x - want.x - 2.0, 2.0)),
			anchor.y - lift - want.y))
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return ideal[a].y < ideal[b].y)

	var taken: Array[Rect2] = []
	for i in order:
		var pin := _pins[i]
		var want := pin.custom_minimum_size
		var spot := _free_spot(ideal[i], want, taken)
		pin.position = spot
		pin.size = want
		taken.append(Rect2(spot, want))
		_anchors[i] = anchors[i]
		_feet[i] = Vector2(clampf(anchors[i].x, spot.x + 8.0,
			spot.x + want.x - 8.0), spot.y + want.y)


## The first spot near the ideal one that nothing else has taken. Sideways is
## tried before forward, because a pin that slides 40 px along keeps roughly
## the right part of the board and a pin pushed forward costs a whole row —
## with six labels on one board that difference is most of the model.
func _free_spot(want_at: Vector2, want: Vector2,
		taken: Array[Rect2]) -> Vector2:
	for step in 14:
		var down: float = float(step) * 12.0
		for slide in [0.0, 38.0, -38.0, 76.0, -76.0]:
			var spot := Vector2(
				clampf(want_at.x + slide, 2.0,
					maxf(size.x - want.x - 2.0, 2.0)),
				clampf(want_at.y + down, 2.0,
					maxf(size.y - want.y - 2.0, 2.0)))
			var clear := true
			for other in taken:
				if Rect2(spot, want).intersects(other.grow(1.5)):
					clear = false
					break
			if clear:
				return spot
	return Vector2(
		clampf(want_at.x, 2.0, maxf(size.x - want.x - 2.0, 2.0)),
		clampf(want_at.y, 2.0, maxf(size.y - want.y - 2.0, 2.0)))


# --- the board -------------------------------------------------------------

func _draw() -> void:
	_board()
	_water()
	_greens()
	_streets()

	# Everything with height goes in one list and comes out sorted from the far
	# corner forward. A Control's draw list has no depth buffer, so the order
	# things are painted in *is* the depth.
	var solids: Array = []
	_gather_blocks(solids)
	_gather_interchange(solids)
	solids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["depth"]) < float(b["depth"]))
	for solid in solids:
		var f: Callable = solid["draw"]
		f.call()

	_stems()


## The baseboard: the top the city sits on, and the two cut edges facing the
## viewer. The edge is what says model rather than map.
func _board() -> void:
	# The board throws a shadow, which is most of what says this is an object
	# on a table rather than a picture of a plan.
	var shadow := PackedVector2Array()
	for corner in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0),
			Vector2(0.0, 1.0)]:
		shadow.append(_ground(corner.x, corner.y) + Vector2(5.0, SLAB + 6.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.30))
	_patch(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.0, 1.0)]), BOARD)
	var down := Vector2(0.0, SLAB)
	var right := _ground(1.0, 0.0)
	var near := _ground(1.0, 1.0)
	var left := _ground(0.0, 1.0)
	draw_colored_polygon(PackedVector2Array([
		right, near, near + down, right + down]), BOARD_NEAR)
	draw_colored_polygon(PackedVector2Array([
		near, left, left + down, near + down]), BOARD_SIDE)


func _water() -> void:
	var edge := PackedVector2Array()
	edge.append(Vector2(0.0, 0.0))
	for i in 13:
		var v: float = float(i) / 12.0
		edge.append(Vector2(_shore(v), v))
	edge.append(Vector2(0.0, 1.0))
	# A shoreline is not convex, and draw_colored_polygon only promises convex
	# results, so it goes down as strips between the edge and the board's rim.
	for i in edge.size() - 2:
		_patch(PackedVector2Array([
			Vector2(0.0, edge[i + 1].y), edge[i + 1], edge[i + 2],
			Vector2(0.0, edge[i + 2].y)]), WATER)
	# A quay along the inland side. The water is a thin wedge on this
	# projection and reads as a shadow without something pale against it; a
	# wharf is also what a waterfront district is built on.
	for i in edge.size() - 2:
		_patch(PackedVector2Array([
			edge[i + 1], edge[i + 1] + Vector2(0.022, 0.0),
			edge[i + 2] + Vector2(0.022, 0.0), edge[i + 2]]), QUAY)


func _greens() -> void:
	_patch(PackedVector2Array([
		PARK.position, PARK.position + Vector2(PARK.size.x, 0.0),
		PARK.end, PARK.position + Vector2(0.0, PARK.size.y)]), GREEN)
	_disc(Districts.at(Districts.STADIUM), PITCH_R, GREEN)


## Streets, as tarmac lying on the board rather than as lines on paper: they
## take the projection like everything else, so they run away from the viewer.
func _streets() -> void:
	for i in PARCELS + 1:
		var at: float = float(i) / float(PARCELS)
		_patch(PackedVector2Array([
			Vector2(0.0, at - 0.012), Vector2(1.0, at - 0.012),
			Vector2(1.0, at + 0.012), Vector2(0.0, at + 0.012)]), ROAD)
		_patch(PackedVector2Array([
			Vector2(at - 0.012, 0.0), Vector2(at - 0.012, 1.0),
			Vector2(at + 0.012, 1.0), Vector2(at + 0.012, 0.0)]), ROAD)


## Buildings, parcel by parcel. Each parcel between the streets is split into
## one or two plots each way and built on, which is why the model reads as
## blocks with streets between rather than as a scatter of dots.
func _gather_blocks(into: Array) -> void:
	var rng := RandomNumberGenerator.new()
	# Fixed, so it is the same city every time it is drawn.
	rng.seed = 20260831
	var step: float = 1.0 / float(PARCELS)
	for gu in PARCELS:
		for gv in PARCELS:
			var u0: float = float(gu) * step + 0.018
			var v0: float = float(gv) * step + 0.018
			var wide: int = 1 if rng.randf() < 0.45 else 2
			var deep: int = 1 if rng.randf() < 0.45 else 2
			for a in wide:
				for b in deep:
					var pu: float = u0 + float(a) * (step - 0.036) / float(wide)
					var pv: float = v0 + float(b) * (step - 0.036) / float(deep)
					var pw: float = (step - 0.036) / float(wide) - 0.008
					var ph: float = (step - 0.036) / float(deep) - 0.008
					if not _open(pu + pw * 0.5, pv + ph * 0.5):
						continue
					if rng.randf() < 0.18:
						continue
					var district := _district_at(pu + pw * 0.5, pv + ph * 0.5)
					var rise: float = float(RISE.get(district, 14.0)) \
						* rng.randf_range(0.55, 1.25)
					var tint: Color = _tint_of(district).darkened(
						rng.randf_range(0.30, 0.58))
					into.append({
						"depth": pu + pw + pv + ph,
						"draw": func() -> void:
							_box(pu, pv, pu + pw, pv + ph, rise, tint),
					})


## The interchange, raised on piers and cut into spans. One entry per span, so
## it passes behind the towers it goes behind and in front of the ones it does
## not — which a single flat ribbon could not do.
func _gather_interchange(into: Array) -> void:
	for i in SPANS:
		var t0: float = float(i) / float(SPANS)
		var t1: float = float(i + 1) / float(SPANS)
		var a := ROAD_FROM.lerp(ROAD_TO, t0)
		var b := ROAD_FROM.lerp(ROAD_TO, t1)
		var mid := a.lerp(b, 0.5)
		into.append({
			"depth": a.x + a.y + 0.03,
			"draw": func() -> void:
				_box(mid.x - 0.012, mid.y - 0.012, mid.x + 0.012,
					mid.y + 0.012, DECK - 3.0, CONCRETE.darkened(0.42))
				_deck(a, b),
		})


func _deck(a: Vector2, b: Vector2) -> void:
	var lift := Vector2(0.0, -DECK)
	var wide := 0.030
	var p0 := _ground(a.x, a.y - wide) + lift
	var p1 := _ground(b.x, b.y - wide) + lift
	var p2 := _ground(b.x, b.y + wide) + lift
	var p3 := _ground(a.x, a.y + wide) + lift
	draw_colored_polygon(PackedVector2Array([
		p3, p2, p2 + Vector2(0.0, 4.0), p3 + Vector2(0.0, 4.0)]),
		CONCRETE.darkened(0.50))
	draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]),
		CONCRETE.darkened(0.18))


## The stems the pins stand on, with a foot where the district actually is,
## and a ring of light on the board under whichever district is selected.
##
## The ring is what ties the pin to the place. Highlighting only the pin says
## which button is pressed; highlighting the board says which part of the city
## that button is about, which is the thing being chosen.
func _stems() -> void:
	var all := Districts.inhabited()
	for i in _feet.size():
		if i < all.size() and String(all[i]) == selected:
			var glow := PackedVector2Array()
			for step in 20:
				var a: float = TAU * float(step) / 20.0
				glow.append(_anchors[i] + Vector2(cos(a) * 34.0,
					sin(a) * 17.0))
			draw_colored_polygon(glow, Color(1.0, 0.96, 0.86, 0.13))
			draw_polyline(glow + PackedVector2Array([glow[0]]),
				Color(1.0, 0.96, 0.86, 0.55), 1.5)
	for i in _feet.size():
		# A pin moved toward the viewer can end up level with or below its own
		# spot on the board. Drawing the stem then points the wrong way, so it
		# is left off and the foot alone marks the place.
		if _feet[i].y < _anchors[i].y - 2.0:
			draw_line(_anchors[i], _feet[i], STEM, 2.0)
		draw_circle(_anchors[i], 3.5, STEM)
