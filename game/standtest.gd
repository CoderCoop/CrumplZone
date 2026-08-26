extends Node2D

## Does each level stand up on its own?
##
##   godot --headless --fixed-fps 60 --path game res://standtest.tscn
##
## stresstest checks this for the default tower. It had never checked the other
## difficulties, and a taller building is exactly where it stops being obvious:
## a level that falls down by itself is cleared before the player touches it,
## which a solver reports as "one use clears it" and a person reports as "the
## game is broken".

const WATCH := 600

var _level: Level
var _queue: Array[String] = []
var _difficulty := ""
var _ticks := 0
var _before := 0
var _failures: Array[String] = []
var _lines: Array[String] = []


func _ready() -> void:
	_queue = Levels.ORDER.duplicate()
	_level = Level.new()
	add_child(_level)
	_start()


func _start() -> void:
	_difficulty = _queue.pop_front()
	_level.build(Levels.level(_difficulty))
	_before = _level.standing()
	_ticks = 0


func _physics_process(_delta: float) -> void:
	_ticks += 1
	_level.tick_settle()
	if _ticks < WATCH:
		return
	var now := _level.standing()
	var damaged := 0
	for body in _level.live_blocks():
		if int(body.get_meta("damage", 0)) > 0:
			damaged += 1
	_lines.append("%-7s %d standing before, %d after %.1fs untouched; %d pieces damaged"
		% [_difficulty, _before, now, float(WATCH) / 60.0, damaged])
	if now < _before:
		_failures.append("%s falls down on its own: %d standing became %d"
			% [_difficulty, _before, now])
	if damaged > 0:
		_failures.append("%s damages itself while standing still: %d pieces"
			% [_difficulty, damaged])
	if _queue.is_empty():
		_report()
		return
	_start()


func _report() -> void:
	print("")
	for line in _lines:
		print(line)
	print("")
	print("expected : every level stands up until it is touched")
	if _failures.is_empty():
		print("VERDICT  : PASS")
		get_tree().quit()
		return
	for failure in _failures:
		print("FAIL  " + failure)
	print("VERDICT  : FAIL")
	get_tree().quit(1)
