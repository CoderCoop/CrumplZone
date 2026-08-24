class_name Intro
extends CanvasLayer

## The screen a player meets first: what the game wants from them, what the
## three tools do, which version this is, and what changed in it.
##
## Built in code like the rest of the UI, and deliberately readable at the
## 800x600 the game is designed around — this is the one screen where a phone
## player has to be able to read everything without pinching.

signal play_pressed

const TITLE_SIZE := 34
const HEADING_SIZE := 16
const BODY_SIZE := 14

const DIM := Color(0.62, 0.66, 0.72)
const BRIGHT := Color(0.92, 0.94, 0.96)
const ACCENT := Color(0.95, 0.45, 0.35)

var _how: VBoxContainer
var _news: VBoxContainer
var _how_button: Button
var _news_button: Button


func _ready() -> void:
	layer = 10

	# Anchors are set after each node is in the tree. Setting them beforehand
	# leaves containers at their minimum size, which collapses every label to
	# one character per line.
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.09, 0.10, 0.13, 0.97)
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Swallows clicks so a tap meant for the menu never reaches the level.
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	column.add_child(_title_row())
	column.add_child(_label(
		"Bring the building down. Nothing may stand above the red line.",
		HEADING_SIZE, DIM, true))
	column.add_child(_spacer(4))
	column.add_child(_tab_row())

	_how = _how_to_play()
	_news = _whats_new()
	column.add_child(_how)
	column.add_child(_news)

	column.add_child(_spacer(8))
	var play := Button.new()
	play.text = "Play"
	play.focus_mode = Control.FOCUS_NONE
	play.custom_minimum_size = Vector2(0.0, 44.0)
	play.add_theme_font_size_override("font_size", 19)
	play.pressed.connect(func() -> void: play_pressed.emit())
	column.add_child(play)

	_show_how(true)


func _title_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var title := _label("CrumplZone", TITLE_SIZE, BRIGHT)
	row.add_child(title)
	var version := _label("v" + ReleaseNotes.version(), HEADING_SIZE, ACCENT)
	version.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	row.add_child(version)
	return row


func _tab_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_how_button = _tab("How to play", func() -> void: _show_how(true))
	row.add_child(_how_button)
	_news_button = _tab("What's new", func() -> void: _show_how(false))
	row.add_child(_news_button)
	return row


func _tab(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150.0, 32.0)
	# Toggle rather than disable. Disabling the selected tab greys it out, which
	# reads as "this one is unavailable" — the exact opposite of selected.
	button.toggle_mode = true
	button.pressed.connect(on_press)
	return button


func _show_how(how: bool) -> void:
	_how.visible = how
	_news.visible = not how
	_how_button.button_pressed = how
	_news_button.button_pressed = not how


func _how_to_play() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	box.add_child(_label("The tools", HEADING_SIZE, BRIGHT))
	box.add_child(_tool_line("1", "Jackhammer",
		"breaks the block you point at into two pieces",
		Level.ROLE_COLOURS["pillar"]))
	box.add_child(_tool_line("2", "Wrecking ball",
		"swings in from the side you clicked nearer and shoves things over",
		Level.ROLE_COLOURS["slab"]))
	box.add_child(_tool_line("3", "Explosive",
		"pushes everything nearby outwards and shatters what is closest",
		ACCENT))

	box.add_child(_spacer(6))
	box.add_child(_label("Controls", HEADING_SIZE, BRIGHT))
	box.add_child(_label("Click or tap to use the selected tool.", BODY_SIZE, DIM))
	box.add_child(_label("Switch tools with the buttons or the 1, 2 and 3 keys.",
		BODY_SIZE, DIM))
	box.add_child(_label("R starts the level again.", BODY_SIZE, DIM))

	box.add_child(_spacer(6))
	box.add_child(_label("Worth knowing", HEADING_SIZE, BRIGHT))
	box.add_child(_label(
		"Every tool costs one move — they differ in what they do, not what "
		+ "they cost.", BODY_SIZE, DIM, true))
	box.add_child(_label(
		"A tool that finds nothing to act on costs you nothing.", BODY_SIZE, DIM, true))
	box.add_child(_label(
		"Nothing is ever deleted — demolition makes big things into smaller "
		+ "things, and every piece still has to end up below the line.",
		BODY_SIZE, DIM, true))
	return box


func _whats_new() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	for entry in ReleaseNotes.NOTES:
		box.add_child(_label("v%s — %s" % [entry["version"], entry["date"]],
			HEADING_SIZE, BRIGHT))
		for line in entry["lines"]:
			box.add_child(_label("  •  " + line, BODY_SIZE, DIM))
		box.add_child(_spacer(6))
	box.add_child(_label(
		"The full changelog lives with the source at github.com/CoderCoop/CrumplZone",
		BODY_SIZE, DIM, true))
	return box


func _tool_line(key: String, name: String, what: String, swatch: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var chip := ColorRect.new()
	chip.color = swatch
	chip.custom_minimum_size = Vector2(12.0, 16.0)
	var wrap := CenterContainer.new()
	wrap.add_child(chip)
	row.add_child(wrap)
	var named := _label("%s  %s" % [key, name], BODY_SIZE, BRIGHT)
	named.custom_minimum_size = Vector2(128.0, 0.0)
	row.add_child(named)
	row.add_child(_label("— " + what, BODY_SIZE, DIM, true))
	return row


## `wrap` defaults to off, and that matters more than it looks. An autowrapping
## Label reports a minimum width of one pixel, so inside an HBoxContainer —
## which gives children their minimum width — it collapses to one character per
## line. Only the long paragraphs, which sit in a VBox and get the full width,
## should wrap.
func _label(text: String, size: int, colour: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer
