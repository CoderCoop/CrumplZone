extends Node2D

## Does the same level, rebuilt, break into the same pieces?
##
##   godot --headless --fixed-fps 60 --path game res://replaytest.tscn
##
## Note what this does *not* claim. Exact replay was measured long ago and does
## not hold: the physics diverges across a multi-move collapse, which is why
## the solver confirms a candidate rather than trusting one run. Positions here
## drift by design and are reported, not asserted.
##
## What must hold is that the same building breaks into the same pieces. That
## is fracture geometry, which is seeded, and it has been broken once — by a
## counter feeding each piece's seed that was reset with the Level object
## rather than with the level. Every rebuild then broke the building
## differently, and the solver was comparing runs that differed for reasons
## that had nothing to do with the moves: partest reported the same level
## solvable in one run and unsolvable in the next.

const TICKS := 700

var _level: Level
var _ticks := 0
var _pass := 0
var _step := 0
var _plan: Array = []
var _prints: Array[String] = []


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	_begin()


func _begin() -> void:
	var spec := Levels.level(Levels.MEDIUM)
	_level.build(spec)
	var cx: float = spec["centre_x"]
	var fy: float = spec["floor_y"]
	_plan = [
		[30, Tools.Kind.EXPLOSIVE, Vector2(cx - 86.0, fy - 50.0)],
		[150, Tools.Kind.WRECKING_BALL, Vector2(cx, fy - 180.0)],
		[330, Tools.Kind.EXPLOSIVE, Vector2(cx + 60.0, fy - 120.0)],
	]
	_step = 0
	_ticks = 0


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_level.tick_settle()
	while _step < _plan.size() and _ticks >= int(_plan[_step][0]):
		Tools.apply(_plan[_step][1], _level, _plan[_step][2], 1.0)
		_step += 1
	if _ticks < TICKS:
		return
	_prints.append(_fingerprint())
	_pass += 1
	if _pass < 2:
		_begin()
		return
	_report()


## Enough of the final state to notice a difference that matters: how many
## pieces there are, how many are still up, and where their mass ended up.
func _fingerprint() -> String:
	var live := _level.live_blocks()
	var sum_x := 0.0
	var sum_y := 0.0
	for body in live:
		sum_x += body.global_position.x
		sum_y += body.global_position.y
	return "%d pieces | %d standing, centre (%.1f, %.1f)" % [
		live.size(), _level.standing(),
		sum_x / maxf(1.0, float(live.size())),
		sum_y / maxf(1.0, float(live.size()))]


func _report() -> void:
	print("first play  : %s" % _prints[0])
	print("replayed    : %s" % _prints[1])
	var first_pieces := _prints[0].split("|")[0]
	var again_pieces := _prints[1].split("|")[0]
	print("")
	print("expected : the same building rebuilt breaks into the same pieces")
	print("           (where they end up drifts, and is not asserted)")
	var same := first_pieces == again_pieces
	print("VERDICT  : %s" % ["PASS" if same else "FAIL"])
	get_tree().quit(0 if same else 1)
