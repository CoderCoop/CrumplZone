extends Node2D

## Regression test for the bug behind "I remove pieces and nothing happens".
##
##   godot --headless --fixed-fps 60 --path game res://waketest.tscn
##   godot --headless --fixed-fps 60 --path game res://waketest.tscn -- nowake
##
## Godot's rigid bodies sleep once they settle, and deleting or splitting the
## body holding a sleeping one up does not wake it. The stack above the cut
## hangs in mid-air, indefinitely.
##
## This asserts the MECHANISM, not the symptom. The hanging itself only shows
## up in the real game — headless harnesses drive physics from _physics_process
## and always see a normal collapse, so several attempts to reproduce the
## visible bug passed with and without the fix and proved nothing. What is
## reliably observable is the state the bug is made of: after a tool has acted,
## blocks are still asleep.
##
## Two assertions, because one of them alone would be worthless:
##   1. Bodies really are asleep before the tool fires. Without this the second
##      assertion passes trivially on a level that never settles.
##   2. Nothing is left asleep once the tool has acted.
##
## `nowake` skips the fix, so the negative control can be run on demand.

const SETTLE_TICKS := 240      # four seconds; well past the engine's threshold

var _level: Level
var _spec: Dictionary
var _ticks := 0
var _done := false


func _ready() -> void:
	_spec = Levels.level(Levels.MEDIUM)
	_level = Level.new()
	add_child(_level)
	_level.build(_spec)


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_ticks += 1
	if _ticks < SETTLE_TICKS:
		return
	_done = true

	var total := _level.live_blocks().size()
	var asleep_before := _count_asleep()
	print("after %d ticks: %d of %d bodies asleep" % [SETTLE_TICKS, asleep_before, total])

	# Cut a block low in the structure, the way a player would.
	var victim := _lowest_slab()
	if victim == null:
		print("FAIL  test could not find a block to cut")
		get_tree().quit(1)
		return
	var at := victim.global_position

	if OS.get_cmdline_user_args().has("nowake"):
		# The pre-fix behaviour: change the world, wake nothing.
		_level.split(victim)
	else:
		Tools.apply(Tools.Kind.JACKHAMMER, _level, at)

	var asleep_after := _count_asleep()
	print("immediately after the cut: %d of %d bodies asleep"
		% [asleep_after, _level.live_blocks().size()])
	print("")

	var meaningful := asleep_before > 0
	var woken := asleep_after == 0

	print("expected : bodies are asleep beforehand (or this test proves nothing),")
	print("           and none are left asleep once a tool has acted")
	print("actual   : %d asleep before, %d asleep after" % [asleep_before, asleep_after])
	print("%s  the level actually settles, so the check is meaningful"
		% ("PASS" if meaningful else "FAIL — nothing ever slept"))
	print("%s  a tool wakes what it disturbed"
		% ("PASS" if woken else "FAIL — blocks left asleep will hang in mid-air"))

	var ok := meaningful and woken
	print("VERDICT  : %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _count_asleep() -> int:
	var n := 0
	for body in _level.live_blocks():
		if body.sleeping:
			n += 1
	return n


## A slab near the bottom: something with weight resting on it. Pieces are
## polygons rather than rectangles now, so "wider than it is tall" comes from
## the outline's own bounding box.
func _lowest_slab() -> RigidBody2D:
	var best: RigidBody2D = null
	for body in _level.live_blocks():
		var extent := _extent_of(body)
		if extent.x < extent.y:
			continue          # a column, not a slab
		if best == null or body.global_position.y > best.global_position.y:
			best = body
	return best


func _extent_of(body: RigidBody2D) -> Vector2:
	var polygon: PackedVector2Array = body.get_meta("poly")
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in polygon:
		low = low.min(point)
		high = high.max(point)
	return high - low
