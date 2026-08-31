extends Node2D

## Does the city play as a ramp, and is it a city rather than one street?
##
##   godot --headless --fixed-fps 60 --path game res://ordertest.tscn
##
## Difficulty is meant to climb across the run with ups and downs in it, not to
## be flat and not to be a staircase. And the districts are meant to be worth
## having: a map whose levels are nearly all in one place is a list wearing a
## map's clothes.

func _ready() -> void:
	var ids := Levels.all_ids()
	var seen := {}
	var scores: Array[float] = []
	print("")
	print("  #  level  district      building        difficulty")
	for i in ids.size():
		var id := String(ids[i])
		var d := Levels.difficulty_of(id)
		scores.append(d)
		var district := Levels.district_of(id)
		seen[district] = int(seen.get(district, 0)) + 1
		print("%3d  %-6s %-13s %-15s %6.1f" % [i + 1, id, district,
			Pack.system_for(id.to_int()), d])

	var failures: Array[String] = []
	if ids.size() < 8:
		failures.append("only %d levels — a city needs more than that" % ids.size())

	# Climbing: the second half must be harder than the first.
	var half := ids.size() / 2
	var early := 0.0
	var late := 0.0
	for i in ids.size():
		if i < half:
			early += scores[i]
		else:
			late += scores[i]
	early /= maxf(float(half), 1.0)
	late /= maxf(float(ids.size() - half), 1.0)
	print("")
	print("first half averages %.1f, second half %.1f" % [early, late])
	if late <= early * 1.15:
		failures.append("the run does not get harder: %.1f then %.1f" % [early, late])

	# And not a staircase: some level must be easier than the one before it.
	var steps_back := 0
	for i in range(1, scores.size()):
		if scores[i] < scores[i - 1]:
			steps_back += 1
	print("levels easier than the one before them: %d of %d" % [
		steps_back, maxi(scores.size() - 1, 1)])
	if steps_back == 0:
		failures.append("difficulty only ever climbs — no ups and downs")

	print("districts: %s" % seen)
	if seen.size() < 4:
		failures.append("levels are in only %d districts — that is a list, not a map"
			% seen.size())
	for district in seen:
		if float(seen[district]) > float(ids.size()) * 0.55:
			failures.append("%s holds more than half the city" % district)

	print("")
	print("expected : the run climbs but not monotonically, and the city has")
	print("           levels spread across its districts")
	if failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit()
		return
	for f in failures:
		print("FAIL  " + f)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
