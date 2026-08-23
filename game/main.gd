extends Node2D

## A deliberately small slice of CrumplZone: one hand-placed tower, a height
## line, and explosive charges on a move budget. It exists to give the web
## export something real to prove itself against — physics, input, rendering
## and UI all running in a browser tab — not to be the game. Tools, generated
## levels and scoring are not here. See CHARTER.md.

const MOVES := 4
const BLAST_RADIUS := 130.0
const BLAST_FORCE := 900.0
const DENSITY := 0.001

const FLOOR_Y := 520.0
const HEIGHT_LINE := 380.0
const PILLAR_W := 22.0
const PILLAR_H := 78.0
const SLAB_H := 22.0
const STOREYS := 3
const PILLARS := 4
const SPACING := 92.0
const FIRST_X := 232.0

const SETTLE_SPEED := 6.0
const SETTLE_TICKS := 30

var _blocks: Array[RigidBody2D] = []
var _moves_left := MOVES
var _settled_for := 0
var _resolved := ""
var _label: Label


func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(400.0, 300.0)
	add_child(camera)

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16.0, 12.0)
	_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_label)

	_build()


func _build() -> void:
	for child in get_children():
		if child is RigidBody2D or child is StaticBody2D:
			remove_child(child)
			child.queue_free()

	var material := PhysicsMaterial.new()
	material.friction = 0.85
	material.bounce = 0.0

	var ground := StaticBody2D.new()
	ground.position = Vector2(400.0, FLOOR_Y + 24.0)
	var ground_shape := CollisionShape2D.new()
	var ground_rect := RectangleShape2D.new()
	ground_rect.size = Vector2(1600.0, 48.0)
	ground_shape.shape = ground_rect
	ground.add_child(ground_shape)
	ground.add_child(_visual(Vector2(1600.0, 48.0), Color(0.20, 0.22, 0.26)))
	add_child(ground)

	_blocks = []
	var y := FLOOR_Y
	for storey in STOREYS:
		for i in PILLARS:
			_blocks.append(_block(
				Vector2(FIRST_X + i * SPACING, y - PILLAR_H * 0.5),
				Vector2(PILLAR_W, PILLAR_H),
				Color(0.79, 0.45, 0.29),
				material))
		y -= PILLAR_H
		var slab_w := (PILLARS - 1) * SPACING + PILLAR_W * 2.0
		_blocks.append(_block(
			Vector2(FIRST_X + (PILLARS - 1) * SPACING * 0.5, y - SLAB_H * 0.5),
			Vector2(slab_w, SLAB_H),
			Color(0.62, 0.65, 0.71),
			material))
		y -= SLAB_H

	_moves_left = MOVES
	_settled_for = 0
	_resolved = ""
	queue_redraw()


func _block(pos: Vector2, size: Vector2, color: Color, material: PhysicsMaterial) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.position = pos
	body.mass = size.x * size.y * DENSITY
	body.physics_material_override = material
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.add_child(_visual(size, color))
	add_child(body)
	return body


func _visual(size: Vector2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var half := size * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	poly.color = color
	return poly


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_build()
		return
	if _resolved != "" or _moves_left <= 0:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_detonate(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		_detonate(get_global_mouse_position())


func _detonate(at: Vector2) -> void:
	_moves_left -= 1
	_settled_for = 0
	for body in _blocks:
		if not is_instance_valid(body):
			continue
		var offset := body.global_position - at
		var distance := offset.length()
		if distance > BLAST_RADIUS:
			continue
		# Linear falloff, and a floor on the distance so a charge placed on top
		# of a block does not divide by something near zero.
		var falloff := 1.0 - distance / BLAST_RADIUS
		var direction := offset.normalized() if distance > 1.0 else Vector2.UP
		body.apply_impulse(direction * BLAST_FORCE * falloff * body.mass)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _resolved != "":
		return
	if _is_settled():
		_settled_for += 1
		if _settled_for >= SETTLE_TICKS:
			_evaluate()
	else:
		_settled_for = 0
	queue_redraw()


func _is_settled() -> bool:
	for body in _blocks:
		if is_instance_valid(body) and body.linear_velocity.length() > SETTLE_SPEED:
			return false
	return true


func _evaluate() -> void:
	if _standing() == 0:
		_resolved = "CLEARED — %d move%s to spare" % [_moves_left, "" if _moves_left == 1 else "s"]
	elif _moves_left <= 0:
		_resolved = "OUT OF MOVES — %d block%s above the line" \
			% [_standing(), "" if _standing() == 1 else "s"]
	else:
		_resolved = ""


## Blocks whose centre is still above the height line.
func _standing() -> int:
	var count := 0
	for body in _blocks:
		if is_instance_valid(body) and body.global_position.y < HEIGHT_LINE:
			count += 1
	return count



func _draw() -> void:
	draw_dashed_line(
		Vector2(0.0, HEIGHT_LINE), Vector2(800.0, HEIGHT_LINE),
		Color(0.95, 0.35, 0.35, 0.9), 2.0, 10.0)
	if _label != null:
		var status := _resolved if _resolved != "" else "%d above the line" % _standing()
		_label.text = "CrumplZone  ·  moves left: %d  ·  %s\nclick or tap to place a charge  ·  R to reset" \
			% [_moves_left, status]
