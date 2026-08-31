class_name Progress
extends RefCounted

## What the player has done, kept between sessions.
##
## Stars earned per level, and which levels are open. A level opens when the
## one before it in Levels.all_ids() has been cleared, so the city unlocks
## along the difficulty ramp rather than all at once.
##
## Stored in user:// as a plain config file. It is a demolition game's save
## data: small, not secret, and worth nothing to anyone. Written on every
## change rather than on quit, because a phone browser is closed by being
## navigated away from and there is no quit to hook.

const PATH := "user://progress.cfg"
const SECTION := "stars"
const SETTINGS := "settings"

static var _stars := {}
static var _experimental := false
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for key in file.get_section_keys(SECTION) if file.has_section(SECTION) else []:
		_stars[key] = int(file.get_value(SECTION, key, 0))
	_experimental = bool(file.get_value(SETTINGS, "experimental", false))


static func _save() -> void:
	var file := ConfigFile.new()
	for key in _stars:
		file.set_value(SECTION, String(key), int(_stars[key]))
	file.set_value(SETTINGS, "experimental", _experimental)
	file.save(PATH)


## Best stars earned on a level, or 0 for one never finished.
static func stars(id: String) -> int:
	_load()
	return int(_stars.get(id, 0))


## Records a finish. Only ever upward: a worse run does not undo a better one,
## which is what lets a player go back to an early level for fun without
## losing what they earned on it.
static func record(id: String, earned: int) -> void:
	_load()
	if earned <= int(_stars.get(id, 0)):
		return
	_stars[id] = earned
	_save()


static func cleared(id: String) -> bool:
	return stars(id) > 0


## Is this level open? The first always is, and everything else waits on the
## level before it in the run.
static func unlocked(id: String) -> bool:
	_load()
	if _experimental:
		return true
	var all := Levels.all_ids()
	var at := all.find(id)
	if at <= 0:
		return at == 0
	return cleared(String(all[at - 1]))


## How far along the city is, for the map's own readout.
static func summary() -> Dictionary:
	var all := Levels.all_ids()
	var done := 0
	var earned := 0
	for id in all:
		var got := stars(String(id))
		if got > 0:
			done += 1
		earned += got
	return {"cleared": done, "of": all.size(), "stars": earned,
		"possible": all.size() * 3}


## Everything open at once, for looking around rather than playing through.
##
## Off by default and deliberately not framed as a cheat: a game whose levels
## are generated and re-baked wants a way to look at all of them without
## playing seventeen demolitions first, and so does anyone reviewing a change
## to the generator.
static func experimental() -> bool:
	_load()
	return _experimental


static func set_experimental(on: bool) -> void:
	_load()
	_experimental = on
	_save()
