class_name Intro
extends CanvasLayer

## The screen a player meets first: what the game wants from them, what the
## three tools do, what the building is made of, which version this is, and
## what changed in it.
##
## Laid out in CSS pixels and scaled by UI.units_per_css(), like the rest of
## the UI, because this is the one screen a phone player has to be able to read
## without pinching. The body of it scrolls, so a landscape phone with 390 px
## of height still reaches the Play button.

signal play_pressed

const TITLE_SIZE := 32
const HEADING_SIZE := 17
const BODY_SIZE := 15

const DIM := Color(0.62, 0.66, 0.72)
const BRIGHT := Color(0.92, 0.94, 0.96)
const ACCENT := Color(0.95, 0.45, 0.35)

const MARGIN := 16.0
const PLAY_HEIGHT := 52.0
const TAB_HEIGHT := 44.0

var _root: Control
var _shade: ColorRect
var _column: VBoxContainer
var _scroll: ScrollContainer
var _play: Button
var _how: VBoxContainer
var _news: VBoxContainer
var _how_button: Button
var _news_button: Button


func _ready() -> void:
	layer = 10

	_root = Control.new()
	add_child(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shade = ColorRect.new()
	_shade.color = Color(0.09, 0.10, 0.13, 0.97)
	_root.add_child(_shade)
	# Swallows taps so one meant for the menu never reaches the level.
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP

	# Everything except Play scrolls. Play is pinned to the bottom instead of
	# sitting at the end of the column, because a Control clamps to its content's
	# minimum size: put in the column, it was pushed off the bottom of a phone
	# and the screen had no way out of it. Measured, not guessed — the column
	# wanted 1615 px of an 844 px screen.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_column)

	_column.add_child(_title_row())
	_column.add_child(_label(
		"Bring the building down. Nothing may stand above the red line.",
		HEADING_SIZE, DIM, true))
	_column.add_child(_spacer(4))
	_column.add_child(_tab_row())

	_how = _how_to_play()
	_news = _whats_new()
	_column.add_child(_how)
	_column.add_child(_news)

	_play = Button.new()
	_play.text = "Play"
	_play.focus_mode = Control.FOCUS_NONE
	_play.add_theme_font_size_override("font_size", 19)
	_play.pressed.connect(func() -> void: play_pressed.emit())
	_root.add_child(_play)

	_show_how(true)
	relayout()
	get_viewport().size_changed.connect(relayout)


## Sized by hand for the same reason main.gd does it: an anchor preset applied
## to a container before it has laid out keeps its zero size.
func relayout() -> void:
	var k := UI.units_per_css(get_viewport())
	var size := get_viewport().get_visible_rect().size / k
	scale = Vector2(k, k)
	_root.position = Vector2.ZERO
	_root.size = size
	_shade.position = Vector2.ZERO
	_shade.size = size

	var width := maxf(size.x - MARGIN * 2.0, 60.0)
	var reserved := PLAY_HEIGHT + MARGIN * 2.0
	_scroll.position = Vector2(MARGIN, MARGIN)
	_scroll.size = Vector2(width, maxf(size.y - MARGIN - reserved, 80.0))
	_play.position = Vector2(MARGIN, size.y - PLAY_HEIGHT - MARGIN)
	_play.size = Vector2(width, PLAY_HEIGHT)


func _title_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("CrumplZone", TITLE_SIZE, BRIGHT))
	var version := _label("v" + ReleaseNotes.version(), HEADING_SIZE, ACCENT)
	version.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	row.add_child(version)
	return row


func _tab_row() -> HBoxContainer:
	var row := HBoxContainer.new()
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
	# Half the width each, and tall enough to be a touch target rather than a
	# mouse target.
	button.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", BODY_SIZE)
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
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	box.add_child(_label("The tools", HEADING_SIZE, BRIGHT))
	box.add_child(_tool_line("1", "Jackhammer", Materials.of(Materials.CONCRETE)["colour"],
		"%d damage to the one piece you point at, and nothing else"
			% Tools.JACKHAMMER_DAMAGE))
	box.add_child(_tool_line("2", "Wrecking ball", Color(0.55, 0.57, 0.60),
		"swings in from the side you tapped nearer and shoves a whole storey "
		+ "over, cracking what it strikes (%d damage)" % Tools.BALL_DAMAGE))
	box.add_child(_tool_line("3", "Explosive", ACCENT,
		("%d damage where you place it, less further out, and throws "
		+ "everything nearby outwards") % Tools.BLAST_DAMAGE))

	box.add_child(_spacer(6))
	box.add_child(_label("Durability, 1 to 100", HEADING_SIZE, BRIGHT))
	box.add_child(_label(
		"Every piece takes damage until it runs out of durability, then breaks "
		+ "apart. Cracks show how close it is. Nothing is invincible — some "
		+ "things are just a bad use of a move.", BODY_SIZE, DIM, true))
	box.add_child(_material_line(Materials.GLASS, "Glass",
		"holds nothing up"))
	box.add_child(_material_line(Materials.BRICK, "Brick",
		"infill, not structure"))
	box.add_child(_material_line(Materials.CONCRETE, "Concrete floors",
		"what has to end up below the line"))
	box.add_child(_material_line(Materials.STEEL, "Steel columns",
		"what carries the building"))
	box.add_child(_material_line(Materials.REINFORCED, "Reinforced core",
		"bring the building down around it"))

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
	box.add_child(_spacer(6))
	box.add_child(_label("Tap to use the selected tool. On a keyboard, 1/2/3 "
		+ "switch tools and R starts over.", BODY_SIZE, DIM, true))
	return box


func _whats_new() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in ReleaseNotes.NOTES:
		box.add_child(_label("v%s — %s" % [entry["version"], entry["date"]],
			HEADING_SIZE, BRIGHT))
		for line in entry["lines"]:
			box.add_child(_label("  •  " + line, BODY_SIZE, DIM, true))
		box.add_child(_spacer(6))
	box.add_child(_label(
		"The full changelog lives with the source at github.com/CoderCoop/CrumplZone",
		BODY_SIZE, DIM, true))
	return box


## Name on one line, description wrapped under it. Side by side needs width a
## phone in portrait does not have.
func _tool_line(key: String, name: String, swatch: Color, what: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_swatch_row("%s  %s" % [key, name], swatch))
	var detail := _label(what, BODY_SIZE, DIM, true)
	box.add_child(detail)
	box.add_child(_spacer(4))
	return box


## Durability first, because it is the number the decision turns on, then what
## that means in jackhammer blows — the unit a player actually spends.
func _material_line(made_of: String, name: String, what: String) -> HBoxContainer:
	var hits := Materials.hits(made_of, Tools.JACKHAMMER_DAMAGE)
	return _swatch_row("%s %d — %s, %d blow%s"
		% [name, Materials.durability(made_of), what, hits, "" if hits == 1 else "s"],
		Materials.of(made_of)["colour"])


func _swatch_row(text: String, swatch: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chip := ColorRect.new()
	chip.color = swatch
	chip.custom_minimum_size = Vector2(12.0, 14.0)
	var wrap := CenterContainer.new()
	wrap.add_child(chip)
	row.add_child(wrap)
	row.add_child(_label(text, BODY_SIZE, BRIGHT, true))
	return row


## `wrap` defaults to off, and that matters more than it looks. An autowrapping
## Label reports a minimum width of one pixel, so inside an HBoxContainer —
## which gives children their minimum width — it collapses to one character per
## line unless it is also told to expand. Both flags go together, which is what
## _label does when wrap is on.
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
