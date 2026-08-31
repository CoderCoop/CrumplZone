extends Node2D

## Does every district actually have a sky of its own?
##
##   godot --headless --fixed-fps 60 --path game res://skytest.tscn
##
## Districts.SKY names a backdrop setting for each part of town, and
## Backdrop._palette falls back to downtown for a name it does not recognise.
## That fallback is the right behaviour at runtime and the wrong thing to find
## out about from a screenshot: a typo, or a district added without a setting,
## costs a level its whole horizon and nothing anywhere says so.
##
## It also checks that two districts do not share a setting. That was true of
## four of the seven — the Retail Park and the Old Town were the same place
## with different names on it — and it was true for months because nothing was
## looking. A shared setting is a decision, and a decision that has to be made
## again is one to make in front of a failing check.
##
## And that each palette is complete. The rows read "far", "mid", "near",
## "density", "tall" and "lit" straight out of the dictionary; a setting
## missing one of those does not draw wrong, it errors on the frame it is used.

const KEYS := ["sky_top", "sky_low", "haze", "far", "mid", "near",
	"density", "tall", "lit", "ground"]

var _problems: Array[String] = []


func _ready() -> void:
	var used := {}
	for district in Districts.PLACES:
		var name := String(Districts.SKY.get(district, ""))
		if name == "":
			_problems.append("%s has no sky" % district)
			continue
		if not Backdrop.SETTINGS.has(name):
			_problems.append("%s asks for \"%s\", which backdrop.gd does not have"
				% [district, name])
			continue
		if used.has(name):
			_problems.append("%s and %s are both seen against \"%s\""
				% [used[name], district, name])
		used[name] = district

	for name in Backdrop.SETTINGS:
		var palette: Dictionary = Backdrop.SETTINGS[name]
		for key in KEYS:
			if not palette.has(key):
				_problems.append("setting \"%s\" has no \"%s\"" % [name, key])
		for kind in palette.get("landmarks", []):
			if not Backdrop.LANDMARK_GAP.has(String(kind)):
				_problems.append("setting \"%s\" wants landmark \"%s\", which has no spacing"
					% [name, kind])

	# Every setting has to be somewhere. One that no district reaches is a
	# palette nobody will ever see, which is not a bug but is not shipping
	# either — and it is how a setting ends up maintained and dead.
	for name in Backdrop.SETTINGS:
		if not used.has(name):
			_problems.append("setting \"%s\" is not the sky over any district"
				% name)

	_report(used)


func _report(used: Dictionary) -> void:
	print("districts        : %d" % Districts.PLACES.size())
	print("backdrop settings: %d" % Backdrop.SETTINGS.size())
	for district in Districts.PLACES:
		print("  %-12s %s" % [district, Districts.SKY.get(district, "<none>")])
	print("")
	print("distinct settings in use : %d" % used.size())
	if not _problems.is_empty():
		print("")
		for problem in _problems:
			print("  " + problem)
	print("")
	print("expected : every district names a setting that exists, no two share")
	print("           one, every palette is complete, and none is unreachable")
	print("VERDICT  : %s" % ["FAIL" if not _problems.is_empty() else "PASS"])
	get_tree().quit(1 if not _problems.is_empty() else 0)
