class_name Fracture
extends RefCounted

## How a shape comes apart. Pure geometry — no bodies, no physics, no engine
## state — so it can be checked directly and replayed identically.
##
## Everything here works on convex polygons and keeps them convex: cutting a
## convex shape with a straight line gives two convex shapes, which is what
## lets a fragment carry a ConvexPolygonShape2D collider rather than an
## approximation of one.
##
## Two fracture patterns, because two materials break in genuinely different
## ways:
##
##   brittle    — cuts radiate from the point struck, so glass comes apart in
##                uneven slivers that all point back at the impact, the way a
##                pane actually shatters. Never a tidy grid of rectangles.
##   structural — one or two cuts across the piece, offset from the middle and
##                sloped off the perpendicular. A column broken this way parts
##                on a diagonal face, so the upper piece slides off its own
##                stump instead of resting on a flat surface and carrying the
##                load as if nothing had happened.

const EPSILON := 0.0001

## Angle a structural fracture runs off the perpendicular. This is not a taste
## decision — it is a friction one. A fracture face only slides when its angle
## exceeds atan(friction), so a shallow break locks together and the piece
## above goes on carrying its load exactly as it did before, which is the bug
## this range exists to prevent. Rubble is given a friction of about 0.45 (see
## level.gd), so a face has to clear ~25° to move at all, and these run from
## about 31° to 66°.
const SLOPE_MIN := 0.55
const SLOPE_MAX := 1.15

## How far off centre a structural break can land, as a fraction of the piece.
const OFFSET := 0.30


static func area(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0
	var total := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		total += a.cross(b)
	return absf(total) * 0.5


static func centroid(points: PackedVector2Array) -> Vector2:
	var twice_area := 0.0
	var sum := Vector2.ZERO
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var cross := a.cross(b)
		twice_area += cross
		sum += (a + b) * cross
	if absf(twice_area) < EPSILON:
		var average := Vector2.ZERO
		for p in points:
			average += p
		return average / maxf(1.0, float(points.size()))
	return sum / (3.0 * twice_area)


## The rectangle a level spec describes, as a polygon centred on its own middle.
static func rectangle(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])


## Keeps the side of the line where (point - origin) · normal >= 0.
## Sutherland-Hodgman against a single half-plane.
static func clip(points: PackedVector2Array, origin: Vector2,
		normal: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size():
		var current := points[i]
		var next := points[(i + 1) % points.size()]
		var here := (current - origin).dot(normal)
		var there := (next - origin).dot(normal)
		if here >= 0.0:
			out.append(current)
		if (here >= 0.0) != (there >= 0.0):
			out.append(current.lerp(next, here / (here - there)))
	return out


## Cuts a polygon in two. Returns both halves, or nothing at all when the cut
## would shave a sliver off the edge instead of dividing the piece — the caller
## then leaves the piece alone, which is what keeps every fragment worth
## simulating and keeps the total area exactly what it was.
static func split(points: PackedVector2Array, origin: Vector2, normal: Vector2,
		min_area: float) -> Array:
	var a := clip(points, origin, normal)
	var b := clip(points, origin, -normal)
	if a.size() < 3 or b.size() < 3:
		return []
	if area(a) < min_area or area(b) < min_area:
		return []
	return [a, b]


## Breaks a polygon into roughly `count` pieces around the point struck.
## Deterministic in `seed`: the solver replays a level thousands of times and a
## fracture that came out differently each time would make its verdicts
## meaningless.
static func fragments(points: PackedVector2Array, impact: Vector2, count: int,
		brittle: bool, min_area: float, fracture_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = fracture_seed
	var pieces: Array = [points]
	# A cut can be refused for being too thin a shaving, so allow more attempts
	# than cuts and stop when they stop landing.
	var attempts := 0
	var wanted: int = maxi(2, count)
	while pieces.size() < wanted and attempts < wanted * 8:
		attempts += 1
		var index := _largest(pieces)
		var piece: PackedVector2Array = pieces[index]
		var cut := _plane(piece, impact, brittle, rng)
		var halves := split(piece, cut[0], cut[1], min_area)
		if halves.is_empty():
			continue
		pieces.remove_at(index)
		pieces.append_array(halves)
	return pieces


static func _largest(pieces: Array) -> int:
	var best := 0
	var best_area := -1.0
	for i in pieces.size():
		var a := area(pieces[i])
		if a > best_area:
			best_area = a
			best = i
	return best


## Where to cut, and which way the cut runs.
static func _plane(points: PackedVector2Array, impact: Vector2, brittle: bool,
		rng: RandomNumberGenerator) -> Array:
	var middle := centroid(points)
	if brittle:
		# Radial: every cut passes through the point struck, so the shards all
		# point back at it. An impact outside the piece (a fragment thrown
		# clear of where the blow landed) falls back to its middle.
		var through := impact if _contains(points, impact) else middle
		var angle := rng.randf_range(0.0, PI)
		return [through, Vector2(cos(angle), sin(angle))]

	# Structural: across the long axis, off centre, and sloped.
	var extent := _extent(points)
	var along := Vector2.DOWN if extent.y >= extent.x else Vector2.RIGHT
	var reach: float = (extent.y if extent.y >= extent.x else extent.x) * 0.5
	var origin := middle + along * rng.randf_range(-OFFSET, OFFSET) * reach * 2.0
	var slope := rng.randf_range(SLOPE_MIN, SLOPE_MAX) * (1.0 if rng.randf() < 0.5 else -1.0)
	return [origin, along.rotated(slope)]


static func _extent(points: PackedVector2Array) -> Vector2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for p in points:
		low = low.min(p)
		high = high.max(p)
	return high - low


static func _contains(points: PackedVector2Array, point: Vector2) -> bool:
	var sign_seen := 0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var side := (b - a).cross(point - a)
		if absf(side) < EPSILON:
			continue
		var this_sign := 1 if side > 0.0 else -1
		if sign_seen == 0:
			sign_seen = this_sign
		elif this_sign != sign_seen:
			return false
	return true


## Furthest any vertex reaches from the piece's own origin — what the height
## line rule measures a piece by, once pieces are no longer rectangles.
static func reach(points: PackedVector2Array) -> float:
	var furthest := 0.0
	for p in points:
		furthest = maxf(furthest, p.length())
	return furthest
