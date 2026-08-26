extends Node2D

## Do damage lines stay where they were drawn?
##
##   godot --headless --fixed-fps 60 --path game res://cracktest.tscn
##
## A piece's cracks are redrawn from scratch every time it takes damage, and
## the seed they are drawn from used to be hashed from the body's live
## global_position. So a piece that had moved between blows — which is every
## piece in a collapse — had all of its damage lines redrawn somewhere else.
## Measured: the same crack went from (57, 45) to (56, -46) purely because the
## piece it belonged to had shifted.
##
## The seed is now stamped once when the piece is made. This holds it there.

var _level: Level
var _body: RigidBody2D
var _first: PackedVector2Array
var _ticks := 0
var _stage := 0


func _ready() -> void:
	_level = Level.new()
	add_child(_level)
	_level.build({
		"centre_x": 400.0, "floor_y": 540.0, "height_line": 140.0,
		"power": 100.0, "moves": 1,
		"blocks": [{"x": 400.0, "y": 480.0, "w": 120.0, "h": 120.0,
			"material": Materials.REINFORCED}],
	})
	_body = _level.live_blocks()[0]


func _crack_shape() -> PackedVector2Array:
	for child in _body.get_children():
		if String(child.name) == "crack_0":
			return (child as Polygon2D).polygon
	return PackedVector2Array()


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_level.tick_settle()
	if _stage == 0 and _ticks > 5:
		_level.damage(_body, 10, _body.global_position)
		_first = _crack_shape().duplicate()
		print("crack after first damage : %s" % [_first])
		_stage = 1
	elif _stage == 1 and _ticks > 10:
		# Move the piece the way falling rubble would, then damage it again.
		_body.global_position += Vector2(37.0, -19.0)
		_level.damage(_body, 10, _body.global_position)
		var now := _crack_shape()
		print("crack after it moved     : %s" % [now])
		var moved := _first.size() != now.size()
		if not moved:
			for i in _first.size():
				if _first[i].distance_to(now[i]) > 0.5:
					moved = true
					break
		print("")
		print("expected : the same crack, in the same place on the piece")
		print("actual   : %s" % ["it moved" if moved else "unchanged"])
		print("VERDICT  : %s" % ["FAIL" if moved else "PASS"])
		get_tree().quit()
