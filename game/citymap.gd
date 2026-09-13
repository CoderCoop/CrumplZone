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
##
## The same board also shows one district close up (#63). `window` is the
## part of the plan the board covers — the whole city by default, a square
## around one district for the close-up — and everything projects through it,
## so the two views cannot disagree about where north is. In a close-up the
## pins are the district's levels, each standing on a real plot of the model,
## because a level is a building somewhere in town and a tile in a grid had
## stopped saying so.

signal district_picked(district: String)
signal level_picked(id: String)

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

## The part of the plan this board shows, in plan coordinates.
var window := Rect2(0.0, 0.0, 1.0, 1.0)
## When set, the board is that district close up and the pins are its levels.
var district_view := ""
var selected_level := ""

var _pins: Array[Button] = []
var _anchors: Array[Vector2] = []
var _feet: Array[Vector2] = []
## In a close-up: which levels are on the board, and which plot each stands on
## ({"plot": index into _plots(), "kind": what the building is made of}).
var _level_ids: Array[String] = []
var _level_plots := {}


## The plan window for a district close-up: a square around its spot, kept on
## the board. Zooming by about two and a half, which is enough to give every
## level its own building without the district losing its neighbours.
static func window_for(district: String) -> Rect2:
	var half := 0.21
	var at := Districts.at(district)
	var origin := Vector2(
		clampf(at.x - half, 0.0, 1.0 - half * 2.0),
		clampf(at.y - half, 0.0, 1.0 - half * 2.0))
	return Rect2(origin, Vector2(half * 2.0, half * 2.0))


## What a level's building is coloured, by what it is made of. Shared with the
## intro's Play button so the two agree.
static func kind_tint(kind: String) -> Color:
	return {
		Architecture.CURTAIN_WALL: Color(0.62, 0.78, 0.92),
		Architecture.MASONRY: Color(0.86, 0.55, 0.44),
		Architecture.FLAT_SLAB: Color(0.78, 0.80, 0.83),
		Architecture.STACK: Color(0.84, 0.62, 0.46),
		Architecture.SHED: Color(0.70, 0.76, 0.72),
	}.get(kind, Color(0.95, 0.78, 0.34)) as Color


## How much taller than the city view things stand: a close-up of a quarter of
## the board is two and a half times closer, so a building rises two and a
## half times as far or the district comes out flattened.
func _zoom() -> float:
	return 1.0 / maxf(window.size.x, 0.05)


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 330.0)
	# The map is the largest thing in a scrolling column, so a Control that
	# swallows drags makes most of the screen unscrollable on a phone. It only
	# draws — it has no input of its own to take.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var nu: float = (u - window.position.x) / window.size.x
	var nv: float = (v - window.position.y) / window.size.y
	return Vector2(size.x * 0.5 + (nu - nv) * hx, top + (nu + nv) * hy)


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
##
## Clipped to the window by clamping each corner into it. Exact for the
## rectangles that streets, parcels and the park are; a fair approximation for
## the shoreline strips and the pitch, whose clipped edge is at worst a little
## straighter than it should be. A patch clamped flat — entirely outside the
## window — is dropped rather than handed to the triangulator as a line.
func _patch(points: PackedVector2Array, tint: Color) -> void:
	var out := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		var c := p.clamp(window.position, window.end)
		lo = lo.min(c)
		hi = hi.max(c)
		out.append(_ground(c.x, c.y))
	if hi.x - lo.x < 0.0005 or hi.y - lo.y < 0.0005:
		return
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
	if district_view != "":
		_build_level_pins()
		return
	for entry in Districts.inhabited():
		var district: String = String(entry)
		var pin := Button.new()
		pin.text = Districts.title(district)
		pin.focus_mode = Control.FOCUS_NONE
		# Takes its own taps and lets a drag past it to the scroll behind —
		# see UI.let_drags_through.
		pin.mouse_filter = Control.MOUSE_FILTER_PASS
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


## One pin per level of the district, standing on the building it is. A locked
## level is still on the map — dimmed and unpressable — so the district reads
## as a place with that many buildings in it, not as a place with gaps.
func _build_level_pins() -> void:
	_level_ids.clear()
	_level_plots.clear()
	for entry in Levels.all_ids():
		var id := String(entry)
		if Levels.district_of(id) != district_view:
			continue
		_level_ids.append(id)
		var open := Progress.unlocked(id)
		var earned := Progress.stars(id)
		var rating := "· · ·"
		if open:
			rating = ""
			for i in 3:
				rating += ("*" if i < earned else "·") + (" " if i < 2 else "")
		var pin := Button.new()
		pin.text = "Level %s\n%s" % [Levels.title_for(id), rating]
		pin.disabled = not open
		pin.focus_mode = Control.FOCUS_NONE
		pin.mouse_filter = Control.MOUSE_FILTER_PASS
		pin.clip_text = true
		pin.add_theme_font_size_override("font_size", 13)
		# Over the 44 px floor both ways, and there are at most a handful per
		# district, so they can afford to be larger than the tiles were.
		pin.custom_minimum_size = Vector2(88.0, 48.0)
		if open:
			pin.pressed.connect(func() -> void:
				selected_level = id
				_restyle()
				queue_redraw()
				level_picked.emit(id))
		add_child(pin)
		_pins.append(pin)
	_restyle()
	_place_pins()


## A pin carries the colour of what stands in its district, so the model reads
## as somewhere with different buildings in different places even before
## anything is played.
func _restyle() -> void:
	if district_view != "":
		_restyle_level_pins()
		return
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


## A level pin is coloured by what its building is made of, the way the tiles
## were, so a district of brick houses reads as brick before it is played.
func _restyle_level_pins() -> void:
	for i in _pins.size():
		var id: String = _level_ids[i]
		var kind := String(_level_plots.get(id, {}).get("kind", ""))
		var tint := kind_tint(kind)
		var open := not _pins[i].disabled
		var chosen: bool = id == selected_level
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = tint if open else tint.darkened(0.55)
			if chosen:
				box.bg_color = tint.lightened(0.15)
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
		var ink := INK if open else Color(0.55, 0.57, 0.62)
		_pins[i].add_theme_color_override("font_color", ink)
		_pins[i].add_theme_color_override("font_pressed_color", ink)
		_pins[i].add_theme_color_override("font_disabled_color", ink)


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
	var stands: Array[Vector2] = []
	if district_view != "":
		stands = _level_stands()
	for i in _pins.size():
		var anchor: Vector2
		var lift: float
		if district_view != "":
			anchor = stands[i]
			lift = 14.0
		else:
			var district := String(all[i])
			var at := Districts.at(district)
			anchor = _ground(at.x, at.y)
			lift = float(RISE.get(district, 14.0)) + 18.0
		var want := _pins[i].custom_minimum_size
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


## Where each level pin stands in a close-up: on the roof of a plot of its own.
##
## The levels are spread round the district's spot on a ring, far side first,
## and each takes the nearest plot nobody has yet. A ring rather than a row,
## because a district is a place and its buildings are around it, not along
## it; and real plots rather than free-floating spots, so the pin points at a
## building rather than at a patch of street.
func _level_stands() -> Array[Vector2]:
	_level_plots.clear()
	var out: Array[Vector2] = []
	var plots := _plots()
	var centre := Districts.at(district_view)
	var inside := window.grow(-0.03)
	var claimed := {}
	var n: int = _level_ids.size()
	for i in n:
		var id: String = _level_ids[i]
		var angle: float = -PI * 0.5 + TAU * float(i) / maxf(float(n), 1.0)
		var want: Vector2 = centre + Vector2(cos(angle), sin(angle)) \
			* window.size.x * 0.26
		var best := -1
		var nearest := INF
		for plot in plots:
			var index: int = int(plot["index"])
			if claimed.has(index):
				continue
			var mid := Vector2(float(plot["u"]) + float(plot["w"]) * 0.5,
				float(plot["v"]) + float(plot["h"]) * 0.5)
			if not inside.has_point(mid):
				continue
			var d := mid.distance_to(want)
			if d < nearest:
				nearest = d
				best = index
		var kind := String(Levels.by_id(id).get("kind", ""))
		if best < 0:
			_level_plots[id] = {"plot": -1, "kind": kind}
			out.append(_ground(want.x, want.y))
			continue
		claimed[best] = true
		_level_plots[id] = {"plot": best, "kind": kind}
		var plot: Dictionary = plots[best]
		var roof := _ground(float(plot["u"]) + float(plot["w"]) * 0.5,
			float(plot["v"]) + float(plot["h"]) * 0.5)
		out.append(roof + Vector2(0.0, -float(plot["rise"]) * _zoom()))
	return out


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
	# The board is the window, not the city: in a close-up the slab is cut
	# where the view is, or its edges land two boards away.
	var w0 := window.position
	var w1 := window.end
	var shadow := PackedVector2Array()
	for corner in [w0, Vector2(w1.x, w0.y), w1, Vector2(w0.x, w1.y)]:
		shadow.append(_ground(corner.x, corner.y) + Vector2(5.0, SLAB + 6.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.30))
	_patch(PackedVector2Array([
		w0, Vector2(w1.x, w0.y), w1, Vector2(w0.x, w1.y)]), BOARD)
	var down := Vector2(0.0, SLAB)
	var right := _ground(w1.x, w0.y)
	var near := _ground(w1.x, w1.y)
	var left := _ground(w0.x, w1.y)
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


## Every plot on the board, the same every time it is asked for: where it is,
## how tall, what colour. Parcel by parcel — each parcel between the streets
## is split into one or two plots each way and built on, which is why the
## model reads as blocks with streets between rather than as a scatter of
## dots. A list rather than a draw loop because in a close-up the level pins
## stand on these.
func _plots() -> Array:
	var out: Array = []
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
					out.append({"index": out.size(), "u": pu, "v": pv,
						"w": pw, "h": ph, "rise": rise, "tint": tint})
	return out


## The plots as boxes, clipped to the window. A plot a level stands on is
## drawn in its level's own colour, lit rather than shaded, so the buildings
## that can be played are the ones that stand out.
func _gather_blocks(into: Array) -> void:
	var level_of := {}
	for id in _level_plots:
		level_of[int(_level_plots[id]["plot"])] = id
	for plot in _plots():
		var rect := Rect2(float(plot["u"]), float(plot["v"]),
			float(plot["w"]), float(plot["h"])).intersection(window)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var rise: float = float(plot["rise"]) * _zoom()
		var tint: Color = plot["tint"]
		if level_of.has(int(plot["index"])):
			tint = kind_tint(String(_level_plots[level_of[int(plot["index"])]]["kind"]))
		into.append({
			"depth": rect.end.x + rect.end.y,
			"draw": func() -> void:
				_box(rect.position.x, rect.position.y, rect.end.x, rect.end.y,
					rise, tint),
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
		# A span is drawn whole or not at all: a span cut by the window's edge
		# would have to bend to stay on the board.
		if not (window.grow(0.02).has_point(a) and window.grow(0.02).has_point(b)):
			continue
		var mid := a.lerp(b, 0.5)
		into.append({
			"depth": a.x + a.y + 0.03,
			"draw": func() -> void:
				_box(mid.x - 0.012, mid.y - 0.012, mid.x + 0.012,
					mid.y + 0.012, (DECK - 3.0) * _zoom(), CONCRETE.darkened(0.42))
				_deck(a, b),
		})


func _deck(a: Vector2, b: Vector2) -> void:
	var lift := Vector2(0.0, -DECK * _zoom())
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
		var lit: bool
		if district_view != "":
			lit = i < _level_ids.size() and _level_ids[i] == selected_level
		else:
			lit = i < all.size() and String(all[i]) == selected
		if lit:
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
