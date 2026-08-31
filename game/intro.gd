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

## Carries which of the three the player picked.
signal play_pressed(difficulty: String)

const TITLE_SIZE := 32
const HEADING_SIZE := 17
const BODY_SIZE := 15

const DIM := Color(0.62, 0.66, 0.72)
const BRIGHT := Color(0.92, 0.94, 0.96)
const ACCENT := Color(0.95, 0.45, 0.35)

const MARGIN := 16.0
const PLAY_HEIGHT := 52.0
const INSTALL_HEIGHT := 46.0
## How often to ask the browser whether it is offering an install yet.
const INSTALL_POLL := 0.4
const TAB_HEIGHT := 44.0

var _root: Control
var _shade: ColorRect
var _column: VBoxContainer
var _scroll: ScrollContainer
var _play: Button
var _plays: Array[Button] = []
## The level the Play button will start. Tiles set it, and the button says so,
## so the primary action is never a mystery.
## The level the Play button will start. The furthest the player has got,
## rather than a fixed one: coming back to the game should offer the level they
## are actually on.
var _selected: String = ""
var _install: Button
var _install_note: Label
var _install_poll := 0.0
var _how: VBoxContainer
var _news: VBoxContainer
var _levels: VBoxContainer
var _levels_button: Button
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
	_levels = _level_list()
	_column.add_child(_how)
	_column.add_child(_news)
	_column.add_child(_levels)

	# Offered rather than advertised: the button only exists when the browser
	# has an install prompt in hand for it.
	_install = Button.new()
	_install.text = "Install as an app"
	_install.focus_mode = Control.FOCUS_NONE
	_install.add_theme_font_size_override("font_size", 16)
	_install.pressed.connect(_on_install)
	_install.visible = false
	_root.add_child(_install)

	# One Play button, not one per difficulty.
	#
	# There were three — Easy, Medium, Hard, side by side in thumb reach — and
	# that was right while three was the whole game. It is fifteen now, so the
	# list moved into its own tab, and leaving the three along the bottom as
	# well would have put the same choice on screen twice. Duplicated controls
	# are the thing this project has already been told off for once, when the
	# power and tool readouts appeared top-left and again along the bottom.
	#
	# So the bottom is the one action — play the building you last picked —
	# and the Levels tab is where you pick a different one.
	_play = Button.new()
	_play.focus_mode = Control.FOCUS_NONE
	_play.clip_text = true
	_play.add_theme_font_size_override("font_size", 21)
	_selected = _furthest()
	_play.add_theme_color_override("font_color", Color(0.10, 0.10, 0.12))
	_play.add_theme_color_override("font_pressed_color", Color(0.10, 0.10, 0.12))
	_play.pressed.connect(func() -> void: play_pressed.emit(_selected))
	_root.add_child(_play)
	_plays = [_play]
	_refresh_play()

	_show(_how)
	_refresh_install()
	relayout()
	get_viewport().size_changed.connect(relayout)


## Sized by hand for the same reason main.gd does it: an anchor preset applied
## to a container before it has laid out keeps its zero size.
## The install button appears when the browser offers one, and the note takes
## its place on iOS, where there is no prompt to fire and the only way in is
## Share → Add to Home Screen.
## Re-checked rather than read once. The browser fires its install event a
## moment after the page loads — after this screen has already been built — so
## asking once at startup answered "no" every time and the button never
## appeared, on a build that was perfectly installable.
func _process(_delta: float) -> void:
	_install_poll -= _delta
	if _install_poll > 0.0:
		return
	_install_poll = INSTALL_POLL
	_refresh_install()
	# The help screen is the one place where switching builds costs nothing:
	# there is no level in progress to throw away. Taking it here is what makes
	# an update land on the next time the game is opened rather than whenever
	# the player happens to close every tab.
	if UI.update_ready():
		UI.apply_update()


func _refresh_install() -> void:
	if _install == null:
		return
	var offered := UI.can_install()
	if offered == _install.visible:
		return
	_install.visible = offered
	if _install_note != null:
		_install_note.visible = not offered and not UI.installed()
	UI.report_install_button(offered)
	relayout()


func _on_install() -> void:
	UI.install()
	# The browser takes it from here; the button goes once the prompt is spent.
	await get_tree().create_timer(0.5).timeout
	_refresh_install()
	relayout()


## Warmer as it gets harder, so the three read as a scale rather than as three
## unrelated buttons.
## The Play button wears the name and the colour of what it will start.
func _refresh_play() -> void:
	if _play == null:
		return
	var spec := Levels.by_id(_selected)
	var kind := String(spec.get("kind", ""))
	_play.text = "Play  %s — %s" % [Levels.title_for(_selected),
		Architecture.ABOUT.get(kind, ["Building", ""])[0]]
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_play.add_theme_stylebox_override(state,
			_tile_style(kind, state.contains("pressed")))


## The level to offer: the first one not yet cleared, or the last if the whole
## city is done.
func _furthest() -> String:
	var all := Levels.all_ids()
	for id in all:
		if not Progress.cleared(String(id)):
			return String(id)
	return String(all[all.size() - 1])


func relayout() -> void:
	var k := UI.units_per_css(get_viewport())
	var size := get_viewport().get_visible_rect().size / k
	scale = Vector2(k, k)
	_root.position = Vector2.ZERO
	_root.size = size
	_shade.position = Vector2.ZERO
	_shade.size = size

	var width := maxf(size.x - MARGIN * 2.0, 60.0)
	var install_room := (INSTALL_HEIGHT + 8.0) if _install != null and _install.visible else 0.0
	var reserved := PLAY_HEIGHT + install_room + MARGIN * 2.0
	_scroll.position = Vector2(MARGIN, MARGIN)
	_scroll.size = Vector2(width, maxf(size.y - MARGIN - reserved, 80.0))
	# Three across the bottom, with real gaps between them so a thumb cannot
	# land on two.
	var gap := 10.0
	var each: float = maxf((width - gap * float(_plays.size() - 1))
		/ float(_plays.size()), 44.0)
	for i in _plays.size():
		_plays[i].position = Vector2(MARGIN + float(i) * (each + gap),
			size.y - PLAY_HEIGHT - MARGIN)
		_plays[i].size = Vector2(each, PLAY_HEIGHT)
	if _install != null:
		_install.position = Vector2(MARGIN, _play.position.y - INSTALL_HEIGHT - 8.0)
		_install.size = Vector2(width, INSTALL_HEIGHT)


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
	_how_button = _tab("How to play", func() -> void: _show(_how))
	row.add_child(_how_button)
	_news_button = _tab("What's new", func() -> void: _show(_news))
	row.add_child(_news_button)
	_levels_button = _tab("Levels", func() -> void: _show(_levels))
	row.add_child(_levels_button)
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


## Switch tabs by name, for the picture harness. The panes themselves are
## private; this is the one seam it needs.
func show_tab(which: String) -> void:
	match which:
		"levels":
			_show(_levels)
		"news":
			_show(_news)
		_:
			_show(_how)


func _show(pane: Control) -> void:
	_how.visible = pane == _how
	_news.visible = pane == _news
	_levels.visible = pane == _levels
	_how_button.button_pressed = _how.visible
	_news_button.button_pressed = _news.visible
	_levels_button.button_pressed = _levels.visible


## The city, as a map.
##
## Levels are grouped by the part of town they are in, in map order, and each
## is a tile carrying its number, what the building is, and the stars earned on
## it. A district with nothing in it is not drawn.
##
## A grid of numbers was here before. It worked and it said nothing: a level
## was a number and the city was a list. This is the same information arranged
## the way the game talks about it — you are demolishing the waterfront, not
## level three.
func _level_list() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var done := Progress.summary()
	box.add_child(_label("The city", HEADING_SIZE, BRIGHT))
	box.add_child(_label(
		"%d of %d cleared, %d stars of %d. Bring one down to open the next."
			% [done["cleared"], done["of"], done["stars"], done["possible"]],
		BODY_SIZE, DIM, true))

	for district in Districts.inhabited():
		box.add_child(_spacer(6))
		box.add_child(_label(Districts.title(district), BODY_SIZE, ACCENT))
		box.add_child(_label(Districts.about(district), 14, DIM, true))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id in Levels.all_ids():
			if Levels.district_of(String(id)) == district:
				grid.add_child(_level_tile(String(id)))
		box.add_child(grid)

	box.add_child(_spacer(10))
	# Everything open at once. A toggle rather than a hidden code, because it
	# is not a cheat: the levels are generated and re-baked, and looking at all
	# of them without playing seventeen demolitions first is a reasonable thing
	# to want — for a player and for anyone reviewing the generator.
	var free_play := CheckBox.new()
	free_play.text = "Experimental mode — open every level"
	free_play.focus_mode = Control.FOCUS_NONE
	free_play.button_pressed = Progress.experimental()
	free_play.add_theme_font_size_override("font_size", BODY_SIZE)
	free_play.add_theme_color_override("font_color", DIM)
	free_play.add_theme_color_override("font_pressed_color", BRIGHT)
	free_play.custom_minimum_size = Vector2(0.0, 44.0)
	free_play.toggled.connect(func(on: bool) -> void:
		Progress.set_experimental(on)
		_rebuild_levels())
	box.add_child(free_play)
	return box


## The map again, after something changed what it should say.
func _rebuild_levels() -> void:
	if _levels == null or _column == null:
		return
	var was_visible := _levels.visible
	var at := _levels.get_index()
	_column.remove_child(_levels)
	_levels.queue_free()
	_levels = _level_list()
	_column.add_child(_levels)
	_column.move_child(_levels, at)
	_levels.visible = was_visible
	relayout()


func _level_tile(id: String) -> Button:
	var spec := Levels.by_id(id)
	var kind := String(spec.get("kind", ""))
	var open := Progress.unlocked(id)
	var earned := Progress.stars(id)
	var button := Button.new()
	# Stars as filled and hollow pips, drawn in text rather than as glyphs the
	# font may not have — the tofu-box trap this project has hit twice. A
	# locked level says so instead of showing an empty rating it cannot earn.
	var rating := "· · ·"
	if open:
		rating = ""
		for i in 3:
			rating += ("*" if i < earned else "·") + (" " if i < 2 else "")
	button.text = "%s\n%s\n%s" % [Levels.title_for(id),
		Architecture.ABOUT.get(kind, ["", ""])[0], rating]
	button.disabled = not open
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Comfortably over the 44 px floor in both directions, and the grid puts
	# 8 px between them so a thumb cannot land on two at once.
	button.custom_minimum_size = Vector2(0.0, 74.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state,
			_tile_style(kind, state.contains("pressed"), not open))
	var ink := Color(0.10, 0.10, 0.12) if open else Color(0.55, 0.57, 0.62)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_disabled_color", ink)
	if open:
		button.pressed.connect(func() -> void:
			_selected = id
			_refresh_play()
			play_pressed.emit(id))
	return button


## A tile takes the colour of what it is made of, so the list reads as a row
## of different buildings rather than a row of numbers.
func _tile_style(kind: String, held := false, locked := false) -> StyleBoxFlat:
	var tint: Color = {
		Architecture.CURTAIN_WALL: Color(0.62, 0.78, 0.92),
		Architecture.MASONRY: Color(0.86, 0.55, 0.44),
		Architecture.FLAT_SLAB: Color(0.78, 0.80, 0.83),
		Architecture.STACK: Color(0.84, 0.62, 0.46),
		Architecture.SHED: Color(0.70, 0.76, 0.72),
	}.get(kind, Color(0.95, 0.78, 0.34)) as Color
	var style := StyleBoxFlat.new()
	style.bg_color = tint.darkened(0.18) if held else tint
	if locked:
		# Still its own colour, so the map reads as a city of different
		# buildings even where it has not been played — just dimmed, rather
		# than a row of identical grey blanks.
		style.bg_color = tint.darkened(0.55)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _how_to_play() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	box.add_child(_label("The tools — hold to use", HEADING_SIZE, BRIGHT))
	box.add_child(_tool_line("1", "Jackhammer", Materials.of(Materials.CONCRETE)["colour"],
		("keeps chipping for as long as you hold it — %d damage a blow to the "
		+ "one piece you are on, %d power each")
			% [Tools.JACKHAMMER_DAMAGE, int(Tools.JACKHAMMER_POWER)]))
	box.add_child(_tool_line("2", "Wrecking ball", Color(0.55, 0.57, 0.60),
		("hold to haul a real %d kg ball further back, let go to swing it in. "
		+ "Damage is the momentum it arrives with, so a longer haul hits "
		+ "harder — up to %d power")
			% [int(Level.BALL_MASS), int(Tools.cost(Tools.Kind.WRECKING_BALL, 1.0))]))
	box.add_child(_tool_line("3", "Explosive", ACCENT,
		("hold to pack more in, let go to blow it. Up to %d damage where you "
		+ "place it and less further out, for up to %d power")
			% [Tools.BLAST_DAMAGE, int(Tools.cost(Tools.Kind.EXPLOSIVE, 1.0))]))

	box.add_child(_spacer(6))
	box.add_child(_label("Power", HEADING_SIZE, BRIGHT))
	box.add_child(_label(
		"The bar above the tools is everything you get. Every use takes a bite "
		+ "out of it, and how big a bite is up to how long you hold. A tap is "
		+ "cheap and weak; a full hold is neither.", BODY_SIZE, DIM, true))
	box.add_child(_label(
		"A tool that finds nothing to act on costs you nothing.", BODY_SIZE, DIM, true))

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
		"Nothing is ever deleted — demolition makes big things into smaller "
		+ "things, and every piece still has to end up below the line.",
		BODY_SIZE, DIM, true))
	box.add_child(_spacer(6))
	box.add_child(_spacer(6))
	box.add_child(_label("Installing", HEADING_SIZE, BRIGHT))
	_install_note = _label(
		"This runs as an app offline. Where your browser offers it there is an "
		+ "Install button below; on an iPhone use Share → Add to Home Screen.",
		BODY_SIZE, DIM, true)
	box.add_child(_install_note)

	box.add_child(_spacer(6))
	box.add_child(_label("Hold anywhere on the building to use the selected "
		+ "tool, and slide before letting go to change your mind about where. "
		+ "On a keyboard, 1/2/3 switch tools and R starts over.",
		BODY_SIZE, DIM, true))
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
