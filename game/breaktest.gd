extends Node2D

## Every structural piece comes apart, and every blow that does not break one
## still visibly lands.
##
##   godot --headless --fixed-fps 60 --path game res://breaktest.tscn
##
## This exists because "I hit it and nothing happened" is the way this game
## most often lies to a player, and it has happened twice now for different
## reasons. A blow that only decrements a hidden counter reads as a bug
## whatever the durability model says it is.
##
## For each material: hit one block with the jackhammer until it breaks, and
## check three things a player can see — it broke within the number of hits its
## durability promises, into two or more pieces, and every hit before that one
## registered as damage. Then check the two ends of the scale: reinforced
## concrete survives a whole move budget, and rubble refuses a blow rather than
## charging for it.

const BLOCK := Vector2(120.0, 60.0)
const BUDGET := 7            # the hand-built level's move budget
const MAX_HITS := 40         # a stop, so a broken model cannot hang the gate

var _level: Level
var _failures: Array[String] = []


func _ready() -> void:
	_level = Level.new()
	add_child(_level)

	for made_of in [Materials.GLASS, Materials.BRICK, Materials.CONCRETE,
			Materials.STEEL, Materials.REINFORCED]:
		_check(made_of)
	_check_budget_proof()
	_check_rubble()

	print("")
	print("expected : each material breaks in the number of blows its")
	print("           durability promises, into two or more pieces, losing")
	print("           none of its area; every earlier blow registers as damage")
	print("           and cracks; reinforced concrete outlasts a move budget;")
	print("           rubble refuses a blow instead of charging for it")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)


func _check(made_of: String) -> void:
	var expected := Materials.hits(made_of, Tools.JACKHAMMER_DAMAGE)
	_build_one(made_of, BLOCK)
	var area_before := _area()
	var body := _level.live_blocks()[0]

	var hits := 0
	var cracks_seen := false
	while _level.live_blocks().size() == 1 and hits < MAX_HITS:
		var acted := Tools.apply(Tools.Kind.JACKHAMMER, _level, _centre())
		hits += 1
		if not acted:
			_failures.append("%s: blow %d reported no effect" % [made_of, hits])
			break
		if _level.live_blocks().size() > 1:
			break
		# It survived, so it must show that it was hit.
		if int(body.get_meta("damage", 0)) != hits * Tools.JACKHAMMER_DAMAGE:
			_failures.append("%s: blow %d did not register as damage" % [made_of, hits])
		if _crack_count(body) > 0:
			cracks_seen = true

	var pieces := _level.live_blocks().size()
	print("%-11s durability %2d → broke on blow %d of an expected %d, into %d pieces"
		% [made_of, Materials.durability(made_of), hits, expected, pieces])

	if hits != expected:
		_failures.append("%s: broke on blow %d, durability promises %d"
			% [made_of, hits, expected])
	if pieces < 2:
		_failures.append("%s: %d piece(s) after breaking, expected two or more"
			% [made_of, pieces])
	if expected > 1 and not cracks_seen:
		_failures.append("%s: took %d blows without ever showing a crack"
			% [made_of, expected])
	if absf(_area() - area_before) > 1.0:
		_failures.append("%s: %.0f px² before, %.0f px² after — material vanished"
			% [made_of, area_before, _area()])
	for piece in _level.live_blocks():
		if String(piece.get_meta("material", "")) != made_of:
			_failures.append("%s: a fragment changed material" % made_of)
			break


## The claim the scale rests on: reinforced concrete is not invincible, it is
## just a terrible use of a move. It must outlast a whole budget of jackhammer
## blows, and still go to two charges.
func _check_budget_proof() -> void:
	_build_one(Materials.REINFORCED, BLOCK)
	for _i in BUDGET:
		Tools.apply(Tools.Kind.JACKHAMMER, _level, _centre())
	var survived := _level.live_blocks().size() == 1
	print("reinforced  %d jackhammer blows (a whole budget) → %s"
		% [BUDGET, "still standing" if survived else "broken"])
	if not survived:
		_failures.append("reinforced: a move budget of jackhammer blows broke it")

	_build_one(Materials.REINFORCED, BLOCK)
	Tools.apply(Tools.Kind.EXPLOSIVE, _level, _centre())
	var after_one := _level.live_blocks().size()
	Tools.apply(Tools.Kind.EXPLOSIVE, _level, _centre())
	var after_two := _level.live_blocks().size()
	print("reinforced  charges → %d piece after one, %d after two"
		% [after_one, after_two])
	if after_one != 1:
		_failures.append("reinforced: one charge broke it, expected two")
	if after_two < 2:
		_failures.append("reinforced: two charges did not break it — nothing is invincible")


func _check_rubble() -> void:
	var made_of := Materials.STEEL
	# Below twice the smallest area worth simulating, so nothing divides it.
	var size := sqrt(Materials.MIN_AREA * 2.0) * 0.85
	_build_one(made_of, Vector2(size, size))
	var acted := Tools.apply(Tools.Kind.JACKHAMMER, _level, _centre_of(size))
	print("rubble      %.0f px square of steel → acted=%s, %d piece"
		% [size, acted, _level.live_blocks().size()])
	if acted:
		_failures.append("rubble: charged a move for a blow that cannot divide it")


func _build_one(made_of: String, size: Vector2) -> void:
	_level.build({
		"centre_x": 400.0,
		"floor_y": 540.0,
		"height_line": 440.0,
		"blocks": [{
			"x": 400.0, "y": 540.0 - size.y * 0.5,
			"w": size.x, "h": size.y,
			"role": "test", "material": made_of,
		}],
		"moves": 1,
	})


func _centre() -> Vector2:
	return _centre_of(BLOCK.y)


func _centre_of(height: float) -> Vector2:
	return Vector2(400.0, 540.0 - height * 0.5)


func _crack_count(body: RigidBody2D) -> int:
	var count := 0
	for child in body.get_children():
		if String(child.name).begins_with("crack"):
			count += 1
	return count


func _area() -> float:
	var total := 0.0
	for body in _level.live_blocks():
		total += Fracture.area(body.get_meta("poly"))
	return total
