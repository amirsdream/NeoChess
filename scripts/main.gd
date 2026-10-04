extends Control

const SETTINGS_PATH := "user://settings.cfg"
const PROMO_KIND := {"Queen": 5, "Rook": 4, "Bishop": 3, "Knight": 2}
const START_COUNT := {1: 8, 2: 2, 3: 2, 4: 2, 5: 1}
const PIECE_VALUE := {1: 1, 2: 3, 3: 3, 4: 5, 5: 9}
const CAPTURE_ORDER := [5, 4, 3, 2, 1]

const C_GOOD := Color("9fd08a")
const C_BAD := Color("e08a7a")

var C_BG := Color("14110e")
var C_SURFACE := Color("1f1a15")
var C_RAISED := Color("2a231c")
var C_LINE := Color("3a3128")
var C_GOLD := Color("c6a15b")
var C_GOLD_SOFT := Color("e4c37a")
var C_TEXT := Color("f4ede4")
var C_MUTED := Color("b3a394")
var C_DIM := Color("8a7b6a")
var pal := {
	"bg": Color("14110e"), "surface": Color("1f1a15"), "raised": Color("2a231c"), "line": Color("3a3128"),
	"gold": Color("c6a15b"), "gold_soft": Color("e4c37a"), "text": Color("f4ede4"), "muted": Color("b3a394"),
	"dim": Color("8a7b6a"), "gold_hover": Color("d4b56e"), "gold_down": Color("a8863e"), "on_gold": Color("1c140c"),
	"text_hi": Color("fff8ee"), "title": Color("f6efe4"), "line_text": Color("e8dccb"), "btn_hover": Color("4a3d32"),
	"field": Color("241c17"), "picked": Color("3d3226"), "off": Color("2a241e"),
}
var palette_key := -1
var bindings := {}
const SIDEBAR_W := 380.0
const ANALYSIS_DELAY := 0.3
const MENU_COPY_PGN := 0
const MENU_COPY_FEN := 1
const MENU_SAVE := 2
const MENU_PASTE := 3
const MENU_OPEN := 4
const MENU_LIBRARY := 5
const BOOK_ROWS := 5
const STRIP_H := 60.0
const STRIP_GAP := 8.0

var game := ChessGame.new()
var board_view: BoardView
var board_area: Control
var top_strip := {}
var bottom_strip := {}
var status_label: Label
var status_pill: PanelContainer
var pill_style: StyleBoxFlat
var settings_btn: Button
var play_panel: Control
var settings_panel: Control
var settings_pages: Array = []
var settings_tabs: Array = []
var settings_open := false
var board_grid: GridContainer
var piece_grid: GridContainer
var board_chips: Array = []
var piece_chips: Array = []
var piece_texture_cache := {}
var board_flipped := false
var eval_tween: Tween
var moves_label: RichTextLabel
var mode_opt: OptionButton
# The side you play against Stockfish. It is chosen when a new game starts.
var human_white := true
var side_box: PanelContainer
var skill_slider: HSlider
var time_slider: HSlider
var skill_label: Label
var time_label: Label
var time_mode_btns: Array = []
var time_caption: Label
var fixed_movetime := 400
var clock_minutes := 5
var use_clock := false
var white_ms := 0
var black_ms := 0
var turn_started_ms := 0
var clock_stack: Array = []
var board_index := 0
var piece_index := 0
var preview_board := -1
var preview_piece := -1
var threads_slider: HSlider
var threads_label: Label
var hash_opt: OptionButton
var overhead_slider: HSlider
var overhead_label: Label
var limit_check: CheckButton
var elo_slider: HSlider
var elo_label: Label
var engine_edit: LineEdit
var engine_label: Label
var show_arrow_check: CheckButton
var show_best_check: CheckButton
var opening_label: Label
var opening_note: Label
# The first move of Stockfish's three best lines, drawn as arrows on the board.
var analysis_moves: Array = [{"from": -1, "to": -1}, {"from": -1, "to": -1}, {"from": -1, "to": -1}]
var show_lines_check: CheckButton
var lines_box: PanelContainer
var lines_hint: Label
var branches_box: VBoxContainer
var branch_cards: Array = []
var pending_info: Dictionary = {}
var new_btn: Button
var undo_btn: Button
var flip_btn: Button
var promo_box: PanelContainer
var dialog: FileDialog

var legal: Array = []
var state := ""
var played: Array = []
var sans: Array[String] = []
var start_fen := Pgn.START_FEN
var start_black := false
var start_number := 1
var game_tags: Dictionary = {}
var game_date := ""
var recorded_result := ""
var view_ply := -1
var view_game: ChessGame
var engine: UciEngine
var analysis_running := false
var analysis_pending := false
var analysis_delay := 0.0
# The position Stockfish is analysing in the live game (while it is your turn),
# or empty when no live analysis is running.
var live_fen := ""
# The Live switch before a review turned it on (-1 when not reviewing). Reviewing
# analyses while Live is on; switching it off stops the engine.
var live_before_review := -1
# Test and screenshot runs must never overwrite the player's saved settings.
var settings_locked := false
var saved_eval_share := 0.5
var saved_eval_text := "0.0"
var review_bar: HBoxContainer
var review_label: Label
var nav_buttons: Array = []
var menu_btn: MenuButton
var save_dialog: FileDialog
var open_dialog: FileDialog
var notice_dialog: AcceptDialog
var toast: PanelContainer
var toast_label: Label
var toast_tween: Tween
var last_dir := ""
var selected := -1
var pending_promo: Array = []
var engine_error := ""
var installer: EngineInstaller
var setup_card: PanelContainer
var setup_progress: ProgressBar
var setup_status: Label
var setup_download_btn: Button
var setup_cancel_btn: Button
var engine_download_btn: Button
var setup_error := ""
var engine_busy := false
var animating := false
var screenshot := false
var no_engine := false

# Game library (SQLite): your own games, imported databases and the opening book.
var library_path := ""
var library_store: GameStore
var library_view: LibraryView
var archive_enabled := true
var archivable := false
var archive_id := 0
var archived_key := ""
var book_query: BookQuery
var book_check: CheckButton
var book_card: PanelContainer
var book_source_opt: OptionButton
var book_source_ids: Array = [0]
var book_source_name := ""
var book_rows_box: VBoxContainer
var book_hint: Label
var book_title: Label
var book_key := ""
var book_rows: Array = []
var book_bars: Array = []


func _ready() -> void:
	screenshot = "--shot" in OS.get_cmdline_user_args()
	no_engine = "--no-engine" in OS.get_cmdline_user_args()
	settings_locked = screenshot or no_engine
	archive_enabled = not settings_locked
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	_build_ui()
	_load_settings()
	if not FileAccess.file_exists(engine_edit.text.strip_edges()):
		var bundled := _bundled_engine()
		if not bundled.is_empty():
			engine_edit.text = bundled
	_apply_style()
	_reset_clocks()
	_apply_time_mode()
	_connect_signals()
	_refresh()
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--check-library="):
			_check_library(str(arg).get_slice("=", 1))
			return
	if screenshot:
		_prepare_shot()
	elif _engine_should_move():
		_start_engine()


func _unhandled_input(event: InputEvent) -> void:
	if library_view != null and library_view.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if side_box != null and side_box.visible:
			_hide_side_box()
		elif settings_open:
			_set_settings_open(false)
		else:
			selected = -1
			_cancel_promo()
			_refresh()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.is_command_or_control_pressed() and not key.alt_pressed:
			if key.keycode == KEY_C:
				_on_menu(MENU_COPY_FEN if key.shift_pressed else MENU_COPY_PGN)
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_V:
				_on_menu(MENU_PASTE)
				get_viewport().set_input_as_handled()
			return
		if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
			return
		match key.keycode:
			KEY_N:
				_ask_new_game()
			KEY_U:
				_on_undo()
			KEY_F:
				_on_flip()
			KEY_S:
				_set_settings_open(not settings_open)
			KEY_L:
				_open_library()


func _exit_tree() -> void:
	_archive_game()
	if library_store != null:
		library_store.close()
	if engine != null:
		engine.shutdown()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = C_BG
	_bind(background, "color", C_BG)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(edge, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	board_area = Control.new()
	board_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.custom_minimum_size = Vector2(440, 440)
	body.add_child(board_area)

	top_strip = _make_strip()
	bottom_strip = _make_strip()
	board_view = BoardView.new()
	board_area.add_child(top_strip["panel"] as Control)
	board_area.add_child(board_view)
	board_area.add_child(bottom_strip["panel"] as Control)
	promo_box = _build_promo()
	board_area.add_child(promo_box)
	side_box = _build_side_box()
	board_area.add_child(side_box)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	body.add_child(side)
	installer = EngineInstaller.new()
	add_child(installer)
	setup_card = _build_setup_card()
	side.add_child(setup_card)
	play_panel = _build_play_panel()
	settings_panel = _build_settings_panel()
	settings_panel.visible = false
	side.add_child(play_panel)
	side.add_child(settings_panel)

	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	if EngineSetup.platform() == "windows":
		dialog.filters = PackedStringArray(["*.exe ; Executable", "* ; All files"])
	else:
		dialog.filters = PackedStringArray(["* ; All files"])
	dialog.title = "Select Stockfish"
	dialog.file_selected.connect(_on_engine_file)
	add_child(dialog)
	library_view = LibraryView.new(self)
	add_child(library_view)
	library_view.open_game.connect(_open_library_game)
	library_view.message.connect(_notify)
	library_view.sources_changed.connect(_on_sources_changed)
	library_view.games_deleted.connect(_on_games_deleted)
	library_view.imported.connect(_on_imported)
	library_view.closed.connect(_refresh)
	book_query = BookQuery.new()
	add_child(book_query)
	book_query.answered.connect(_on_book_answer)
	_build_game_io()

	var bundled := _bundled_engine()
	if FileAccess.file_exists(bundled):
		engine_edit.text = bundled


func _build_setup_card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := _card_style()
	_border(style, C_GOLD)
	card.add_theme_stylebox_override("panel", style)
	card.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	var title := Label.new()
	title.text = "Stockfish is needed to play the computer"
	title.add_theme_font_size_override("font_size", 17)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tint(title, "font_color", C_GOLD_SOFT)
	col.add_child(title)

	col.add_child(_muted("Stockfish is a free, open-source chess engine. Download the official build once (about 80 MB), or choose a copy you already have. Pass and play works without it."))

	setup_progress = ProgressBar.new()
	setup_progress.min_value = 0.0
	setup_progress.max_value = 100.0
	setup_progress.show_percentage = false
	setup_progress.custom_minimum_size = Vector2(0, 8)
	setup_progress.add_theme_stylebox_override("background", _flat(C_LINE, 4))
	setup_progress.add_theme_stylebox_override("fill", _flat(C_GOLD, 4))
	setup_progress.visible = false
	col.add_child(setup_progress)

	setup_status = _muted("")
	setup_status.visible = false
	col.add_child(setup_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	setup_download_btn = Button.new()
	setup_download_btn.text = "Download Stockfish %s" % EngineSetup.VERSION
	setup_download_btn.custom_minimum_size = Vector2(0, 42)
	setup_download_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_primary(setup_download_btn, 10)
	row.add_child(setup_download_btn)
	var choose := Button.new()
	choose.text = "Choose file"
	choose.custom_minimum_size = Vector2(0, 42)
	choose.pressed.connect(_browse)
	row.add_child(choose)
	setup_cancel_btn = Button.new()
	setup_cancel_btn.text = "Cancel"
	setup_cancel_btn.custom_minimum_size = Vector2(0, 42)
	setup_cancel_btn.visible = false
	row.add_child(setup_cancel_btn)

	var link := LinkButton.new()
	link.text = "About this download (Stockfish, GPLv3)"
	link.uri = EngineSetup.RELEASE_PAGE
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(link)
	return card


func _make_primary(button: Button, radius: int) -> void:
	button.add_theme_stylebox_override("normal", _flat(C_GOLD, radius))
	button.add_theme_stylebox_override("hover", _flat(Color("d4b56e"), radius))
	button.add_theme_stylebox_override("pressed", _flat(Color("a8863e"), radius))
	button.add_theme_stylebox_override("disabled", _flat(C_LINE, radius))
	_tint(button, "font_color", Color("1c140c"))
	_tint(button, "font_hover_color", Color("1c140c"))
	_tint(button, "font_pressed_color", Color("1c140c"))

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 44)

	var logo := TextureRect.new()
	logo.texture = load("res://icon.png") as Texture2D
	logo.custom_minimum_size = Vector2(36, 36)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)

	var title := Label.new()
	title.text = "NeoChess"
	title.add_theme_font_size_override("font_size", 22)
	_tint(title, "font_color", Color("f6efe4"))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)

	status_pill = PanelContainer.new()
	status_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill_style = _flat(C_RAISED, 18)
	pill_style.content_margin_left = 16
	pill_style.content_margin_right = 16
	pill_style.content_margin_top = 6
	pill_style.content_margin_bottom = 6
	status_pill.add_theme_stylebox_override("panel", pill_style)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_pill.add_child(status_label)
	row.add_child(status_pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	menu_btn = MenuButton.new()
	menu_btn.text = "Game"
	menu_btn.flat = false
	menu_btn.custom_minimum_size = Vector2(96, 40)
	menu_btn.tooltip_text = "Import or export a game (PGN) or a position (FEN)"
	var menu := menu_btn.get_popup()
	menu.add_item("Copy game (PGN)", MENU_COPY_PGN)
	menu.add_item("Copy position (FEN)", MENU_COPY_FEN)
	menu.add_item("Save game as…", MENU_SAVE)
	menu.add_separator()
	menu.add_item("Paste game or position", MENU_PASTE)
	menu.add_item("Open game file…", MENU_OPEN)
	menu.add_separator()
	menu.add_item("Game library…", MENU_LIBRARY)
	menu.id_pressed.connect(_on_menu)
	row.add_child(menu_btn)

	settings_btn = Button.new()
	settings_btn.text = "Settings"
	settings_btn.toggle_mode = true
	settings_btn.custom_minimum_size = Vector2(120, 40)
	settings_btn.tooltip_text = "Open settings (S)"
	settings_btn.add_theme_stylebox_override("pressed", _flat(C_GOLD, 8))
	settings_btn.add_theme_stylebox_override("hover_pressed", _flat(Color("d4b56e"), 8))
	_tint(settings_btn, "font_pressed_color", Color("1c140c"))
	_tint(settings_btn, "font_hover_pressed_color", Color("1c140c"))
	row.add_child(settings_btn)
	return row


func _make_strip() -> Dictionary:
	var panel := PanelContainer.new()
	var style := _flat(C_SURFACE, 12)
	style.content_margin_left = 14
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_width_left = 4
	style.border_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, STRIP_H)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(18, 18)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 16)
	title_row.add_child(name_label)
	var sub_label := _muted("")
	sub_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_row.add_child(sub_label)

	var captured := HBoxContainer.new()
	captured.add_theme_constant_override("separation", -10)
	captured.custom_minimum_size = Vector2(0, 22)
	info.add_child(captured)

	var thinking := _muted("Thinking…")
	thinking.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tint(thinking, "font_color", C_GOLD_SOFT)
	thinking.visible = false
	thinking.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(thinking)

	var clock_panel := PanelContainer.new()
	var clock_style := _flat(C_BG, 8)
	clock_style.content_margin_left = 12
	clock_style.content_margin_right = 12
	clock_style.content_margin_top = 4
	clock_style.content_margin_bottom = 4
	clock_panel.add_theme_stylebox_override("panel", clock_style)
	clock_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock_panel.visible = false
	var clock_label := Label.new()
	clock_label.add_theme_font_size_override("font_size", 20)
	clock_label.custom_minimum_size = Vector2(56, 0)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_panel.add_child(clock_label)
	row.add_child(clock_panel)

	return {
		"panel": panel, "style": style, "dot": dot, "name": name_label, "sub": sub_label,
		"captured": captured, "thinking": thinking, "clock_panel": clock_panel, "clock": clock_label,
	}


func _build_play_panel() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_build_engine_card())
	col.add_child(_build_book_card())
	col.add_child(_build_moves_card())
	col.add_child(_build_actions())
	# Everything is meant to fit the window. If a font or a long list makes the
	# column taller than the window, it scrolls instead of being cut off.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(col)
	return scroll


func _build_engine_card() -> Control:
	lines_box = PanelContainer.new()
	lines_box.add_theme_stylebox_override("panel", _card_style())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	lines_box.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "Engine analysis"
	title.add_theme_font_size_override("font_size", 17)
	_tint(title, "font_color", C_GOLD_SOFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	show_lines_check = CheckButton.new()
	show_lines_check.text = "Live"
	show_lines_check.tooltip_text = "Show Stockfish's five best lines while it thinks."
	head.add_child(show_lines_check)
	book_check = CheckButton.new()
	book_check.text = "Book"
	book_check.tooltip_text = "Show what was played in the games of your library after these moves."
	head.add_child(book_check)

	lines_hint = _muted("")
	col.add_child(lines_hint)

	branches_box = VBoxContainer.new()
	branches_box.add_theme_constant_override("separation", 4)
	col.add_child(branches_box)
	for i in 5:
		var card := PanelContainer.new()
		var card_style := _flat(C_RAISED, 10)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 3
		card_style.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", card_style)
		var card_col := VBoxContainer.new()
		card_col.add_theme_constant_override("separation", 0)
		card.add_child(card_col)
		var line_head := HBoxContainer.new()
		line_head.add_theme_constant_override("separation", 8)
		card_col.add_child(line_head)
		var rank := Label.new()
		rank.text = "#%d" % (i + 1)
		rank.custom_minimum_size = Vector2(24, 0)
		_tint(rank, "font_color", C_MUTED)
		line_head.add_child(rank)
		var score := Label.new()
		score.text = "–"
		score.add_theme_font_size_override("font_size", 16)
		score.custom_minimum_size = Vector2(60, 0)
		line_head.add_child(score)
		var line_moves := Label.new()
		line_moves.clip_text = true
		line_moves.autowrap_mode = TextServer.AUTOWRAP_OFF
		line_moves.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line_moves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_moves.mouse_filter = Control.MOUSE_FILTER_PASS
		line_moves.add_theme_font_size_override("font_size", 13)
		_tint(line_moves, "font_color", Color("e8dccb"))
		line_head.add_child(line_moves)
		var depth := Label.new()
		depth.add_theme_font_size_override("font_size", 12)
		depth.custom_minimum_size = Vector2(52, 0)
		depth.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_tint(depth, "font_color", Color("8a7b6a"))
		line_head.add_child(depth)
		branches_box.add_child(card)
		branch_cards.append({"score": score, "depth": depth, "moves": line_moves})
	return lines_box


func _build_moves_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	col.add_child(head)
	var title := Label.new()
	title.text = "Moves"
	title.add_theme_font_size_override("font_size", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tint(title, "font_color", C_GOLD_SOFT)
	head.add_child(title)
	var nav_specs := [
		["«", "First position (Home)", "_nav_first"],
		["‹", "Previous move (Left arrow)", "_nav_prev"],
		["›", "Next move (Right arrow)", "_nav_next"],
		["»", "Back to the latest position (End)", "_nav_last"],
	]
	for spec in nav_specs:
		var nav := Button.new()
		nav.text = str(spec[0])
		nav.tooltip_text = str(spec[1])
		nav.custom_minimum_size = Vector2(38, 30)
		nav.focus_mode = Control.FOCUS_NONE
		nav.pressed.connect(Callable(self, str(spec[2])))
		head.add_child(nav)
		nav_buttons.append(nav)
	opening_label = Label.new()
	opening_label.clip_text = true
	opening_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	opening_label.add_theme_font_size_override("font_size", 15)
	opening_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_tint(opening_label, "font_color", C_GOLD_SOFT)
	col.add_child(opening_label)
	opening_note = Label.new()
	opening_note.clip_text = true
	opening_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	opening_note.add_theme_font_size_override("font_size", 12)
	opening_note.mouse_filter = Control.MOUSE_FILTER_PASS
	_tint(opening_note, "font_color", C_MUTED)
	col.add_child(opening_note)
	moves_label = RichTextLabel.new()
	moves_label.bbcode_enabled = true
	moves_label.scroll_active = true
	moves_label.scroll_following = true
	moves_label.selection_enabled = false
	moves_label.meta_underlined = false
	moves_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	moves_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	moves_label.custom_minimum_size = Vector2(0, 64)
	moves_label.meta_clicked.connect(_on_move_clicked)
	col.add_child(moves_label)

	review_bar = HBoxContainer.new()
	review_bar.add_theme_constant_override("separation", 8)
	review_bar.visible = false
	col.add_child(review_bar)
	review_label = Label.new()
	review_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_label.clip_text = true
	review_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tint(review_label, "font_color", C_MUTED)
	review_bar.add_child(review_label)
	var play_here := Button.new()
	play_here.text = "Play from here"
	play_here.tooltip_text = "Drop the later moves and continue from this position"
	play_here.focus_mode = Control.FOCUS_NONE
	play_here.pressed.connect(_play_from_here)
	review_bar.add_child(play_here)
	return card


func _build_actions() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	new_btn = Button.new()
	new_btn.text = "New game"
	new_btn.tooltip_text = "Start a new game (N)"
	new_btn.custom_minimum_size = Vector2(0, 44)
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.add_theme_stylebox_override("normal", _flat(C_GOLD, 10))
	new_btn.add_theme_stylebox_override("hover", _flat(Color("d4b56e"), 10))
	new_btn.add_theme_stylebox_override("pressed", _flat(Color("a8863e"), 10))
	_tint(new_btn, "font_color", Color("1c140c"))
	_tint(new_btn, "font_hover_color", Color("1c140c"))
	_tint(new_btn, "font_pressed_color", Color("1c140c"))
	undo_btn = Button.new()
	undo_btn.text = "Undo"
	undo_btn.tooltip_text = "Take back your last move (U)"
	undo_btn.custom_minimum_size = Vector2(84, 44)
	flip_btn = Button.new()
	flip_btn.text = "Flip"
	flip_btn.tooltip_text = "Turn the board around (F)"
	flip_btn.custom_minimum_size = Vector2(84, 44)
	row.add_child(new_btn)
	row.add_child(undo_btn)
	row.add_child(flip_btn)
	return row


func _build_promo() -> PanelContainer:
	var box := PanelContainer.new()
	box.visible = false
	var style := _flat(C_RAISED, 14)
	_border(style, C_GOLD)
	style.set_border_width_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	box.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	box.add_child(col)
	var title := Label.new()
	title.text = "Promote pawn to"
	title.add_theme_font_size_override("font_size", 16)
	_tint(title, "font_color", C_GOLD_SOFT)
	col.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for piece_name in ["Queen", "Rook", "Bishop", "Knight"]:
		var button := Button.new()
		button.text = piece_name
		button.custom_minimum_size = Vector2(76, 40)
		button.pressed.connect(_on_promo.bind(piece_name))
		row.add_child(button)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(76, 40)
	cancel.pressed.connect(_cancel_promo)
	col.add_child(cancel)
	return box


# The "New game" question: which side do you want to play?
func _build_side_box() -> PanelContainer:
	var box := PanelContainer.new()
	box.visible = false
	var style := _flat(C_RAISED, 14)
	_border(style, C_GOLD)
	style.set_border_width_all(2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	box.add_child(col)
	var title := Label.new()
	title.text = "New game"
	title.add_theme_font_size_override("font_size", 20)
	_tint(title, "font_color", C_GOLD_SOFT)
	col.add_child(title)
	var prompt := Label.new()
	prompt.text = "Play as"
	_tint(prompt, "font_color", Color("a99c8a"))
	col.add_child(prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for choice in ["White", "Random", "Black"]:
		var button := Button.new()
		button.text = choice
		button.custom_minimum_size = Vector2(92, 46)
		button.pressed.connect(_on_side_chosen.bind(choice))
		row.add_child(button)
	var hint := Label.new()
	hint.text = "As Black, Stockfish makes the first move."
	hint.add_theme_font_size_override("font_size", 13)
	_tint(hint, "font_color", Color("8a7b6a"))
	col.add_child(hint)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 38)
	cancel.pressed.connect(_hide_side_box)
	col.add_child(cancel)
	return box


func _build_settings_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Done"
	close.custom_minimum_size = Vector2(72, 36)
	close.pressed.connect(_set_settings_open.bind(false))
	head.add_child(close)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	col.add_child(tab_row)
	var group := ButtonGroup.new()
	var tab_names := ["Play", "Look", "Engine"]
	for i in tab_names.size():
		var tab := Button.new()
		tab.text = str(tab_names[i])
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = i == 0
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 38)
		tab.add_theme_stylebox_override("pressed", _flat(C_GOLD, 8))
		tab.add_theme_stylebox_override("hover_pressed", _flat(Color("d4b56e"), 8))
		_tint(tab, "font_pressed_color", Color("1c140c"))
		_tint(tab, "font_hover_pressed_color", Color("1c140c"))
		tab.pressed.connect(_show_settings_page.bind(i))
		tab_row.add_child(tab)
		settings_tabs.append(tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	settings_pages = [_build_play_page(), _build_look_page(), _build_engine_page()]
	for page in settings_pages:
		pages.add_child(page as Control)
	_show_settings_page(0)
	return panel


func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return page


func _setting(title: String, control: Control, hint: String = "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_section(title))
	box.add_child(control)
	if hint != "":
		box.add_child(_muted(hint))
	return box


func _build_play_page() -> Control:
	var page := _page()

	mode_opt = OptionButton.new()
	mode_opt.add_item("Versus Stockfish")
	mode_opt.add_item("Pass and play")
	page.add_child(_setting("Opponent", mode_opt))

	skill_label = _muted("Level 8")
	skill_slider = HSlider.new()
	skill_slider.min_value = 0
	skill_slider.max_value = 20
	skill_slider.step = 1
	skill_slider.value = 8
	skill_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var strength := VBoxContainer.new()
	strength.add_theme_constant_override("separation", 4)
	strength.add_child(skill_label)
	strength.add_child(skill_slider)
	limit_check = CheckButton.new()
	limit_check.text = "Cap strength with an Elo rating"
	strength.add_child(limit_check)
	elo_label = _muted("Elo cap  1600")
	elo_label.visible = false
	strength.add_child(elo_label)
	elo_slider = HSlider.new()
	elo_slider.min_value = 1320
	elo_slider.max_value = 3190
	elo_slider.step = 10
	elo_slider.value = 1600
	elo_slider.visible = false
	elo_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strength.add_child(elo_slider)
	page.add_child(_setting("Strength", strength, "Level 20 is full strength. Lower levels play weaker and more human."))

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	var mode_group := ButtonGroup.new()
	var mode_names := ["Fixed time", "Clock"]
	for i in mode_names.size():
		var seg := Button.new()
		seg.text = str(mode_names[i])
		seg.toggle_mode = true
		seg.button_group = mode_group
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.custom_minimum_size = Vector2(0, 38)
		seg.add_theme_stylebox_override("pressed", _flat(C_GOLD, 8))
		seg.add_theme_stylebox_override("hover_pressed", _flat(Color("d4b56e"), 8))
		_tint(seg, "font_pressed_color", Color("1c140c"))
		_tint(seg, "font_hover_pressed_color", Color("1c140c"))
		seg.tooltip_text = "Fixed gives every move the same time. Clock gives each side a clock and Stockfish spends more on hard moves."
		mode_row.add_child(seg)
		time_mode_btns.append(seg)
	time_caption = _muted("Time per move")
	time_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label = Label.new()
	time_label.text = "0.40 s"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tint(time_label, "font_color", C_GOLD_SOFT)
	var time_row := HBoxContainer.new()
	time_row.add_child(time_caption)
	time_row.add_child(time_label)
	time_slider = HSlider.new()
	time_slider.min_value = 100
	time_slider.max_value = 2000
	time_slider.step = 50
	time_slider.value = 400
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var timing := VBoxContainer.new()
	timing.add_theme_constant_override("separation", 6)
	timing.add_child(mode_row)
	timing.add_child(time_row)
	timing.add_child(time_slider)
	page.add_child(_setting("Thinking time", timing, "Fixed gives each move the same time. Clock shares one clock and Stockfish decides how long each move needs."))
	return page


func _build_look_page() -> Control:
	var page := _page()

	board_grid = GridContainer.new()
	board_grid.columns = 2
	board_grid.add_theme_constant_override("h_separation", 8)
	board_grid.add_theme_constant_override("v_separation", 8)
	page.add_child(_setting("Board", board_grid, "Hover to preview, click to keep."))
	_populate_chips("board", board_grid)

	piece_grid = GridContainer.new()
	piece_grid.columns = 2
	piece_grid.add_theme_constant_override("h_separation", 8)
	piece_grid.add_theme_constant_override("v_separation", 8)
	page.add_child(_setting("Pieces", piece_grid))
	_populate_chips("pieces", piece_grid)

	show_arrow_check = CheckButton.new()
	show_arrow_check.text = "Last-move arrow"
	show_arrow_check.button_pressed = true
	show_arrow_check.tooltip_text = "Draw an arrow from the square a piece left to the square it landed on."
	show_best_check = CheckButton.new()
	show_best_check.text = "Best-move arrows"
	show_best_check.button_pressed = true
	show_best_check.tooltip_text = "While Stockfish analyses, draw its three best moves as arrows: thick for the best, medium for the second, thin for the third."
	var overlays := VBoxContainer.new()
	overlays.add_theme_constant_override("separation", 4)
	overlays.add_child(show_arrow_check)
	overlays.add_child(show_best_check)
	page.add_child(_setting("Board overlays", overlays))
	return page


func _build_engine_page() -> Control:
	var page := _page()

	threads_label = _muted("Threads  1")
	threads_slider = HSlider.new()
	threads_slider.min_value = 1
	threads_slider.max_value = 8
	threads_slider.step = 1
	threads_slider.value = 1
	threads_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var threads_box := VBoxContainer.new()
	threads_box.add_theme_constant_override("separation", 4)
	threads_box.add_child(threads_label)
	threads_box.add_child(threads_slider)
	page.add_child(_setting("CPU threads", threads_box, "More threads search faster on a multi-core processor."))

	hash_opt = OptionButton.new()
	for mb in [16, 32, 64, 128, 256]:
		hash_opt.add_item("%d MB" % int(mb))
	hash_opt.selected = 2
	page.add_child(_setting("Hash memory", hash_opt))

	overhead_label = _muted("Move overhead  30 ms")
	overhead_slider = HSlider.new()
	overhead_slider.min_value = 0
	overhead_slider.max_value = 200
	overhead_slider.step = 5
	overhead_slider.value = 30
	overhead_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var overhead_box := VBoxContainer.new()
	overhead_box.add_theme_constant_override("separation", 4)
	overhead_box.add_child(overhead_label)
	overhead_box.add_child(overhead_slider)
	page.add_child(_setting("Move overhead", overhead_box, "Time reserved per move for the app. Raise it if Stockfish loses time on a clock."))

	engine_edit = LineEdit.new()
	engine_edit.placeholder_text = "Path to stockfish"
	engine_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var browse := Button.new()
	browse.text = "Browse"
	browse.pressed.connect(_browse)
	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 8)
	path_row.add_child(engine_edit)
	path_row.add_child(browse)
	engine_label = _muted("")
	var path_box := VBoxContainer.new()
	path_box.add_theme_constant_override("separation", 6)
	path_box.add_child(path_row)
	path_box.add_child(engine_label)
	engine_download_btn = Button.new()
	engine_download_btn.text = "Download Stockfish %s" % EngineSetup.VERSION
	engine_download_btn.tooltip_text = "Fetches the official Windows build from the Stockfish GitHub release and installs it for your user."
	engine_download_btn.custom_minimum_size = Vector2(0, 38)
	path_box.add_child(engine_download_btn)
	page.add_child(_setting("Engine file", path_box))
	return page


func _populate_chips(kind: String, grid: GridContainer) -> void:
	var count := Appearance.board_count() if kind == "board" else Appearance.piece_count()
	for i in count:
		var light: Color
		var dark: Color
		var chip := Button.new()
		if kind == "board":
			var colors := Appearance.board(i)
			light = colors.light
			dark = colors.dark
			chip.text = Appearance.board_name(i)
		else:
			var palette := Appearance.piece_set(i)
			light = palette.light
			dark = palette.dark
			chip.text = Appearance.piece_name(i)
		chip.icon = _pair_icon(light, dark)
		chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
		chip.clip_text = true
		chip.custom_minimum_size = Vector2(0, 40)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_entered.connect(_hover_look.bind(kind, i))
		chip.mouse_exited.connect(_unhover_look.bind(kind, i))
		chip.pressed.connect(_confirm_look.bind(kind, i))
		grid.add_child(chip)
		if kind == "board":
			board_chips.append(chip)
		else:
			piece_chips.append(chip)


func _connect_signals() -> void:
	setup_download_btn.pressed.connect(_start_download)
	engine_download_btn.pressed.connect(_start_download)
	setup_cancel_btn.pressed.connect(installer.cancel)
	installer.progress.connect(_on_download_progress)
	installer.finished.connect(_on_download_finished)
	board_view.square_clicked.connect(_on_square)
	board_area.resized.connect(_layout_board_area)
	mode_opt.item_selected.connect(_on_mode_changed)
	new_btn.pressed.connect(_ask_new_game)
	undo_btn.pressed.connect(_on_undo)
	flip_btn.pressed.connect(_on_flip)
	settings_btn.toggled.connect(func(on: bool) -> void: _set_settings_open(on))
	skill_slider.value_changed.connect(func(_v: float) -> void: _sync_engine_controls())
	time_slider.value_changed.connect(func(_v: float) -> void: _on_time_slider())
	(time_mode_btns[0] as Button).pressed.connect(_set_time_mode.bind(false))
	(time_mode_btns[1] as Button).pressed.connect(_set_time_mode.bind(true))
	show_arrow_check.toggled.connect(func(_on: bool) -> void:
		_save_settings()
		_refresh()
	)
	show_best_check.toggled.connect(func(_on: bool) -> void:
		_save_settings()
		_refresh()
	)
	show_lines_check.toggled.connect(func(on: bool) -> void:
		if view_ply >= 0:
			live_before_review = 1 if on else 0
			if on:
				_schedule_analysis()
			else:
				_pause_review_analysis()
		_save_settings()
		_refresh()
	)
	book_check.toggled.connect(func(_on: bool) -> void:
		_save_settings()
		_refresh()
	)
	book_source_opt.item_selected.connect(_on_book_source)
	skill_slider.drag_ended.connect(func(_changed: bool) -> void: _save_settings())
	time_slider.drag_ended.connect(func(_changed: bool) -> void: _save_settings())
	threads_slider.value_changed.connect(func(_v: float) -> void: _sync_engine_controls())
	overhead_slider.value_changed.connect(func(_v: float) -> void: _sync_engine_controls())
	elo_slider.value_changed.connect(func(_v: float) -> void: _sync_engine_controls())
	threads_slider.drag_ended.connect(func(_changed: bool) -> void: _save_settings())
	overhead_slider.drag_ended.connect(func(_changed: bool) -> void: _save_settings())
	elo_slider.drag_ended.connect(func(_changed: bool) -> void: _save_settings())
	hash_opt.item_selected.connect(func(_index: int) -> void: _save_settings())
	limit_check.toggled.connect(func(_on: bool) -> void:
		_sync_engine_controls()
		_save_settings()
		_update_strips()
	)
	engine_edit.focus_exited.connect(_save_settings)
	_layout_board_area()


func _show_settings_page(index: int) -> void:
	for i in settings_pages.size():
		(settings_pages[i] as Control).visible = i == index
	for i in settings_tabs.size():
		(settings_tabs[i] as Button).set_pressed_no_signal(i == index)


func _set_settings_open(on: bool) -> void:
	settings_open = on
	play_panel.visible = not on
	settings_panel.visible = on
	if settings_btn != null:
		settings_btn.set_pressed_no_signal(on)
		settings_btn.tooltip_text = "Close settings (S)" if on else "Open settings (S)"
	if not on and (preview_board >= 0 or preview_piece >= 0):
		preview_board = -1
		preview_piece = -1
		_apply_style()


func _layout_board_area() -> void:
	if board_area == null or board_view == null:
		return
	var area := board_area.size
	var reserve := BoardView.EVAL_RESERVE if board_view.show_eval else 0.0
	var chrome := (STRIP_H + STRIP_GAP) * 2.0
	var board_side := maxf(minf(area.x - reserve, area.y - chrome), 240.0)
	var total_w := board_side + reserve
	var total_h := board_side + chrome
	var left := floorf((area.x - total_w) * 0.5)
	var top := floorf((area.y - total_h) * 0.5)
	var top_panel := top_strip["panel"] as Control
	var bottom_panel := bottom_strip["panel"] as Control
	top_panel.position = Vector2(left + reserve, top)
	top_panel.size = Vector2(board_side, STRIP_H)
	board_view.position = Vector2(left, top + STRIP_H + STRIP_GAP)
	board_view.size = Vector2(total_w, board_side)
	bottom_panel.position = Vector2(left + reserve, top + STRIP_H + STRIP_GAP + board_side + STRIP_GAP)
	bottom_panel.size = Vector2(board_side, STRIP_H)
	var centre := Vector2(left + reserve + board_side * 0.5, top + STRIP_H + STRIP_GAP + board_side * 0.5)
	promo_box.reset_size()
	promo_box.position = centre - promo_box.size * 0.5
	side_box.reset_size()
	side_box.position = centre - side_box.size * 0.5



# Changing the opponent starts a new game. Against Stockfish it asks which side
# you want first, as chess sites do.
func _on_mode_changed(_index: int) -> void:
	_ask_new_game()


# The New game button: ask for a side when playing Stockfish, otherwise start.
func _ask_new_game() -> void:
	if animating:
		await board_view.animation_finished
	if not _versus():
		_start_new_game(human_white)
		return
	_cancel_promo()
	selected = -1
	side_box.visible = true
	_refresh()


func _hide_side_box() -> void:
	side_box.visible = false
	_refresh()


func _on_side_chosen(choice: String) -> void:
	var white := randi() % 2 == 0 if choice == "Random" else choice == "White"
	_start_new_game(white)


# Starts a game with you on the given side. As White you move first; as Black
# Stockfish thinks and makes the first move, then it is your turn.
func _start_new_game(white: bool) -> void:
	side_box.visible = false
	human_white = white
	board_flipped = false
	_save_settings()
	_reset_game(Pgn.START_FEN)
	_refresh()
	if _engine_should_move():
		_start_engine()

func _on_square(sq: int) -> void:
	if view_ply >= 0 or animating or engine_busy or promo_box.visible or side_box.visible or state != "" or not _human_to_move():
		return
	if selected < 0:
		_select_if_piece(sq)
		return
	if sq == selected:
		selected = -1
		_refresh()
		return
	var choices := _moves_between(selected, sq)
	if choices.is_empty():
		_select_if_piece(sq)
		return
	if choices.size() > 1:
		pending_promo = choices
		promo_box.visible = true
		return
	_commit(choices[0])


func _select_if_piece(sq: int) -> void:
	selected = sq if not _moves_from(sq).is_empty() else -1
	_refresh()


func _on_promo(piece_name: String) -> void:
	var kind := int(PROMO_KIND[piece_name])
	for move in pending_promo:
		if int(move.promo) == kind:
			_commit(move)
			return


func _cancel_promo() -> void:
	pending_promo.clear()
	if promo_box != null:
		promo_box.visible = false


func _commit(move: Dictionary) -> void:
	if animating or engine_busy or view_ply >= 0:
		return
	_stop_live()
	_cancel_promo()
	selected = -1
	recorded_result = ""
	archivable = true
	_charge_turn()
	var san := game.to_san(move)
	var origin := int(move.from)
	var target := int(move.to)
	var sign := 1 if int(game.board[origin]) > 0 else -1
	var kind := int(move.promo) if int(move.promo) != 0 else absi(int(game.board[origin]))
	var captured := int(game.board[target])
	var captured_sq := target
	if bool(move.get("ep", false)):
		captured = -sign
		captured_sq = target - 8 if sign > 0 else target + 8
	var rook_from := -1
	var rook_to := -1
	var rook_piece := 0
	if bool(move.get("castle", false)):
		if target > origin:
			rook_from = origin + 3
			rook_to = origin + 1
		else:
			rook_from = origin - 4
			rook_to = origin - 1
		rook_piece = int(game.board[rook_from])
	played.append(move.duplicate())
	sans.append(san)
	engine_error = ""
	game.make_move(move)
	animating = true
	board_view.animate(origin, target, sign * kind, captured, captured_sq, rook_from, rook_to, rook_piece)
	_refresh()
	await board_view.animation_finished
	animating = false
	_refresh()
	if state != "":
		return
	if _engine_should_move():
		_start_engine()


func _on_new_game() -> void:
	if animating:
		await board_view.animation_finished
	_reset_game(Pgn.START_FEN)
	_refresh()
	if _engine_should_move():
		_start_engine()


# Clears everything and sets the board up from a FEN. Callers refresh and, when
# it is the engine's turn, start it afterwards.
func _reset_game(fen: String) -> void:
	_archive_game()
	archivable = false
	archive_id = 0
	archived_key = ""
	side_box.visible = false
	_end_review()
	_cancel_search()
	if engine != null:
		engine.new_game()
	game.load_fen(fen)
	start_fen = fen
	start_black = not game.white_to_move
	start_number = maxi(int(game.fullmove), 1)
	game_tags = {}
	var today := Time.get_date_dict_from_system()
	game_date = "%04d.%02d.%02d" % [int(today.year), int(today.month), int(today.day)]
	recorded_result = ""
	played.clear()
	sans.clear()
	_clear_branches()
	_set_eval(0.5, "0.0", false)
	clock_stack.clear()
	_reset_clocks()
	selected = -1
	engine_error = ""
	_cancel_promo()


func _on_undo() -> void:
	if animating or engine_busy or view_ply >= 0:
		return
	if promo_box.visible:
		_cancel_promo()
		_refresh()
		return
	if played.is_empty():
		return
	var steps := 1
	if _versus() and played.size() >= 2 and _human_to_move():
		steps = 2
	for _i in steps:
		if played.is_empty():
			break
		played.pop_back()
		sans.pop_back()
	_undo_clock(steps)
	_rebuild()
	_refresh()
	if _engine_should_move():
		_start_engine()


func _rebuild() -> void:
	var moves: Array = played.duplicate()
	game.load_fen(start_fen)
	recorded_result = ""
	for move in moves:
		game.make_move(move)
	selected = -1
	engine_error = ""
	_cancel_promo()


func _start_engine() -> void:
	if engine_busy or animating or screenshot or state != "":
		return
	if _resolved_engine_path().is_empty():
		engine_error = "Stockfish was not found. Download it, choose the file, or switch to pass and play."
		_refresh()
		return
	if not _ensure_engine():
		return
	engine_busy = true
	engine_error = ""
	live_fen = ""
	_clear_branches()
	pending_info.clear()
	var options := _engine_options()
	engine.search(game.to_fen(), StockfishUci.go_from_options(options), StockfishUci.engine_settings(options))
	_refresh()


# Makes sure a UCI engine process is running for the chosen engine file.
# Failures arrive through _on_engine_failed.
func _ensure_engine() -> bool:
	var path := _resolved_engine_path()
	if path.is_empty():
		return false
	if engine == null:
		engine = UciEngine.new()
		add_child(engine)
		engine.info.connect(_on_engine_info)
		engine.best_move.connect(_on_engine_best_move)
		engine.failed.connect(_on_engine_failed)
		engine.started.connect(_on_engine_started)
	if engine.usable() and engine.path == path:
		return true
	return engine.start(path)


func _on_engine_started(_name: String) -> void:
	if engine_label != null:
		engine_label.text = _engine_caption()


func _on_engine_failed(message: String) -> void:
	engine_busy = false
	live_fen = ""
	analysis_running = false
	analysis_pending = false
	pending_info.clear()
	engine_error = message
	_refresh()


# Stops whatever the engine is doing without using the result.
func _cancel_search() -> void:
	pending_info.clear()
	live_fen = ""
	analysis_running = false
	analysis_pending = false
	engine_busy = false
	if engine != null:
		engine.stop()


func _on_engine_info(entry: Dictionary) -> void:
	if str(entry["bound"]) != "":
		return
	pending_info[int(entry["n"])] = entry


# Shows the newest line for each rank. Called once per frame, so a flood of
# updates from the engine costs no more than one redraw.
func _flush_info() -> void:
	if pending_info.is_empty():
		return
	var entries := pending_info
	pending_info = {}
	var show_lines := show_lines_check.button_pressed
	for n in entries:
		var entry := entries[n] as Dictionary
		if show_lines and int(n) <= 5:
			_apply_branch(entry)
		if int(n) == 1:
			_apply_eval(entry)
	var lead := entries.get(1, {}) as Dictionary
	if not lead.is_empty() and engine_label != null:
		engine_label.text = _engine_caption(lead)


func _on_engine_best_move(uci: String) -> void:
	if not engine_busy:
		return
	engine_busy = false
	_flush_info()
	if state != "":
		_refresh()
		return
	var move := game.match_uci(uci)
	if move.is_empty():
		if uci.is_empty() or uci == "(none)":
			engine_error = "Stockfish did not return a move."
		else:
			engine_error = "Stockfish returned %s, which is not legal here." % uci
		_refresh()
		return
	_commit(move)


func _refresh() -> void:
	legal = game.legal_moves()
	state = game.state_of(legal)
	var target_list: Array = []
	var capture_list: Array = []
	if selected >= 0:
		for move in _moves_from(selected):
			target_list.append(int(move.to))
			if int(game.board[move.to]) != 0 or bool(move.ep):
				capture_list.append(int(move.to))
	var reviewing := view_ply >= 0
	var shown := _pos()
	var last_index := (view_ply - 1) if reviewing else played.size() - 1
	var last_a := -1
	var last_b := -1
	if last_index >= 0 and last_index < played.size():
		last_a = int(played[last_index].from)
		last_b = int(played[last_index].to)
	var checked := shown.king_square(shown.white_to_move) if shown.in_check_stm() else -1
	var hot := {}
	if not reviewing and _human_to_move() and not animating and not engine_busy and not promo_box.visible and state == "":
		for move in legal:
			hot[int(move.from)] = true
		for sq in target_list:
			hot[int(sq)] = true
	board_view.show_last_arrow = show_arrow_check.button_pressed
	board_view.show_analysis_arrows = show_best_check.button_pressed
	board_view.show_position(shown.board, _bottom_is_white(), selected, target_list, capture_list, last_a, last_b, checked, hot)
	var analysis := show_lines_check.button_pressed
	branches_box.visible = analysis
	if reviewing and analysis:
		lines_hint.text = "Analysing this position. Blue arrows show its three best moves. A plus is good for %s." % ("you" if _versus() else "White")
	elif reviewing:
		lines_hint.text = "Analysis is stopped. Switch on Live to analyse this position."
	elif analysis:
		lines_hint.text = "Five best lines, live; blue arrows show the best three. A plus is good for %s." % ("you" if _versus() else "White")
	else:
		lines_hint.text = "Switch on Live for Stockfish's best lines and arrows."
	if reviewing:
		if shown.state_of(shown.legal_moves()) == "checkmate":
			_set_eval(0.0 if shown.white_to_move else 1.0, "Mate", false)
	elif state == "checkmate":
		_set_eval(0.0 if game.white_to_move else 1.0, "Mate", false)
	status_label.text = _status_text()
	_paint_status()
	moves_label.text = _moves_bbcode()
	_update_opening()
	review_bar.visible = reviewing
	review_label.text = _review_caption()
	_update_nav_buttons()
	engine_label.text = _engine_caption()
	_update_setup_card()
	undo_btn.disabled = played.is_empty() or animating or engine_busy or reviewing
	_sync_engine_controls()
	if reviewing:
		_scroll_to_ply.call_deferred()
	else:
		_scroll_moves.call_deferred()
	if state != "" and not animating:
		_archive_game()
	_update_book()


func _status_text() -> String:
	if view_ply >= 0:
		return "◷  Reviewing, %s" % _ply_name(view_ply)
	if engine_busy:
		return "●  Stockfish is thinking…"
	if engine_error != "":
		return engine_error
	if state != "":
		return game.result_text_for(state)
	var in_check := game.in_check_stm()
	if _versus():
		if _human_to_move():
			return "!  Check, your move" if in_check else "●  Your move"
		return "●  Waiting for Stockfish"
	var side := "White" if game.white_to_move else "Black"
	return "%s to move%s" % ["!  " + side if in_check else "●  " + side, ", check" if in_check else ""]


func _paint_status() -> void:
	var fg := C_TEXT
	var bg := C_RAISED
	if view_ply >= 0:
		fg = C_GOLD_SOFT
		bg = Color(C_GOLD, 0.2)
	elif engine_busy:
		fg = C_GOLD_SOFT
		bg = Color(C_GOLD, 0.2)
	elif engine_error != "":
		fg = Color("f0a090")
		bg = Color(0.88, 0.48, 0.42, 0.18)
	elif state == "checkmate":
		fg = C_GOLD_SOFT
		bg = Color(C_GOLD, 0.22)
	elif state != "":
		fg = C_MUTED
	elif game.in_check_stm():
		fg = Color("f0a090")
		bg = Color(0.88, 0.48, 0.42, 0.18)
	_tint(status_label, "font_color", fg)
	pill_style.bg_color = bg


func _clear_branches() -> void:
	for card in branch_cards:
		var score := card["score"] as Label
		score.text = "–"
		_tint(score, "font_color", Color("8a7b6a"))
		(card["depth"] as Label).text = ""
		(card["moves"] as Label).text = ""
		(card["moves"] as Label).tooltip_text = ""
	for i in analysis_moves.size():
		analysis_moves[i] = {"from": -1, "to": -1}
	board_view.set_analysis_arrows(analysis_moves)


func _apply_branch(entry: Dictionary) -> void:
	var index := int(entry["n"]) - 1
	if index < 0 or index >= branch_cards.size():
		return
	var board := _pos().clone() as ChessGame
	var number := int(board.fullmove)
	var white_turn := bool(board.white_to_move)
	var pv: PackedStringArray = entry["pv"]
	var sans := ""
	var shown := 0
	for uci in pv:
		if shown >= 14:
			sans += "…"
			break
		var move = board.match_uci(str(uci))
		if move.is_empty():
			break
		if shown == 0 and index < analysis_moves.size():
			analysis_moves[index] = {"from": int(move.from), "to": int(move.to)}
		var san: String = board.to_san(move)
		if white_turn:
			sans += "%d. %s " % [number, san]
		elif shown == 0:
			sans += "%d... %s " % [number, san]
		else:
			sans += san + " "
		board.make_move(move)
		if not white_turn:
			number += 1
		white_turn = not white_turn
		shown += 1
	var score := ""
	var good := true
	var mine := _score_sign()
	if bool(entry["has_mate"]):
		var mate := int(entry["mate"]) * mine
		good = mate > 0
		score = "+M%d" % mate if mate > 0 else "-M%d" % absi(mate)
	else:
		var cp := int(entry["cp"]) * mine
		good = cp >= 0
		score = "%+.2f" % (float(cp) / 100.0)
	var depth := int(entry.get("depth", 0))
	var card: Dictionary = branch_cards[index]
	var score_label := card["score"] as Label
	score_label.text = score
	_tint(score_label, "font_color", Color("9fd08a") if good else Color("e08a7a"))
	(card["depth"] as Label).text = "depth %d" % depth if depth > 0 else ""
	(card["moves"] as Label).text = sans.strip_edges()
	(card["moves"] as Label).tooltip_text = sans.strip_edges()
	board_view.set_analysis_arrows(analysis_moves)


# The moves played up to the shown position.
func _shown_moves() -> Array:
	var count := view_ply if view_ply >= 0 else played.size()
	return played.slice(0, mini(count, played.size()))


# Names the opening of the shown position (see OpeningNames) and says where the
# game left the known lines.
func _update_opening() -> void:
	if opening_label == null:
		return
	var moves := _shown_moves()
	var found: Dictionary = {}
	if start_fen == Pgn.START_FEN:
		found = OpeningNames.find_line(moves)
	if start_fen != Pgn.START_FEN:
		opening_label.text = "Custom start position"
		opening_note.text = ""
		opening_label.tooltip_text = ""
		return
	if moves.is_empty():
		opening_label.text = "Starting position"
		opening_note.text = "Make a move to see which opening it is."
		opening_label.tooltip_text = ""
		return
	if found.is_empty():
		opening_label.text = "No known opening yet"
		opening_note.text = ""
		opening_label.tooltip_text = ""
		return
	opening_label.text = OpeningNames.label(found)
	opening_label.tooltip_text = "%s\n%s" % [opening_label.text.replace("  ·  ", " "), found["line"]]
	var at := int(found["at"])
	if at >= moves.size():
		opening_note.text = str(found["line"])
	else:
		var later := moves.size() - at
		opening_note.text = "Left the known line after %s, %d move%s ago" % [_ply_name(at), later, "" if later == 1 else "s"]
	opening_note.tooltip_text = opening_note.text


func _moves_bbcode() -> String:
	if sans.is_empty():
		return "[color=#%s]No moves yet. %s moves first.[/color]" % [C_DIM.to_html(false), "Black" if start_black else "White"]
	var text := "[table=3]"
	var lead := 1 if start_black else 0
	var rows := (sans.size() + lead + 1) / 2
	for r in rows:
		var white_index := r * 2 - lead
		text += "[cell padding=2,3,12,3][color=#%s]%d.[/color][/cell]" % [C_DIM.to_html(false), start_number + r]
		var white_text := _san_cell(white_index) if white_index >= 0 else "[color=#%s]…[/color]" % C_DIM.to_html(false)
		text += "[cell padding=2,3,18,3]%s[/cell]" % white_text
		var black_text := _san_cell(white_index + 1) if white_index + 1 < sans.size() else ""
		text += "[cell padding=2,3,2,3]%s[/cell]" % black_text
	return text + "[/table]"


func _san_cell(index: int) -> String:
	var current := (view_ply - 1) if view_ply >= 0 else sans.size() - 1
	var plain := sans[index]
	if index == current:
		plain = "[bgcolor=#%s][color=#%s][b] %s [/b][/color][/bgcolor]" % [Color(C_GOLD, 0.28).to_html(true), C_GOLD_SOFT.to_html(false), sans[index]]
	return "[url=%d]%s[/url]" % [index + 1, plain]


func _scroll_moves() -> void:
	if moves_label == null:
		return
	moves_label.scroll_to_line(maxi(moves_label.get_line_count() - 1, 0))


func _moves_from(sq: int) -> Array:
	var found: Array = []
	for move in legal:
		if int(move.from) == sq:
			found.append(move)
	return found


func _moves_between(origin: int, target: int) -> Array:
	var found: Array = []
	for move in _moves_from(origin):
		if int(move.to) == target:
			found.append(move)
	return found


func _versus() -> bool:
	return mode_opt.selected == 0


func _human_is_white() -> bool:
	return human_white


func _bottom_is_white() -> bool:
	return _human_is_white() != board_flipped


func _on_flip() -> void:
	board_flipped = not board_flipped
	_refresh()


# ---- History: step through the moves and analyse any position -------------

func _current_ply() -> int:
	return view_ply if view_ply >= 0 else played.size()


func _ply_name(ply: int) -> String:
	if ply <= 0 or ply > sans.size():
		return "start position"
	var index := ply - 1
	var lead := 1 if start_black else 0
	var number := start_number + (index + lead) / 2
	if (index + lead) % 2 == 0:
		return "%d. %s" % [number, sans[index]]
	return "%d... %s" % [number, sans[index]]


func _review_caption() -> String:
	if view_ply < 0:
		return ""
	if view_ply == 0:
		return "Start position"
	return "Position after %s" % _ply_name(view_ply)


func _update_nav_buttons() -> void:
	if nav_buttons.size() < 4:
		return
	var busy := animating or engine_busy
	var at_start := _current_ply() <= 0
	var live := view_ply < 0
	(nav_buttons[0] as Button).disabled = busy or at_start
	(nav_buttons[1] as Button).disabled = busy or at_start
	(nav_buttons[2] as Button).disabled = busy or live
	(nav_buttons[3] as Button).disabled = busy or live


func _on_move_clicked(meta: Variant) -> void:
	_goto_ply(int(str(meta)))


func _nav_first() -> void:
	_goto_ply(0)


func _nav_prev() -> void:
	_goto_ply(_current_ply() - 1)


func _nav_next() -> void:
	if view_ply >= 0:
		_goto_ply(view_ply + 1)


func _nav_last() -> void:
	_leave_review()


# Shows the position after `ply` half-moves (0 is the start). The last ply
# means "back to the live game". Stockfish then analyses the shown position.
func _goto_ply(ply: int) -> void:
	if animating or engine_busy:
		return
	var target := clampi(ply, 0, played.size())
	if target >= played.size():
		_leave_review()
		return
	if target == view_ply:
		return
	if view_ply < 0:
		saved_eval_share = board_view.eval_share
		saved_eval_text = board_view.eval_text
		live_before_review = 1 if show_lines_check.button_pressed else 0
		show_lines_check.set_pressed_no_signal(true)
	_cancel_promo()
	selected = -1
	view_ply = target
	view_game = ChessGame.new()
	view_game.load_fen(start_fen)
	for i in target:
		view_game.make_move(played[i])
	_clear_branches()
	_refresh()
	if show_lines_check.button_pressed:
		_schedule_analysis()
	else:
		_pause_review_analysis()


func _leave_review() -> void:
	if view_ply < 0:
		return
	_end_review()
	_clear_branches()
	_set_eval(saved_eval_share, saved_eval_text, false)
	_refresh()
	if _engine_should_move():
		_start_engine()


# Forgets the reviewed position and asks any running analysis to stop. It does
# not wait for it, so this is safe to call from anywhere.
func _end_review() -> void:
	if live_before_review >= 0:
		show_lines_check.set_pressed_no_signal(live_before_review == 1)
		live_before_review = -1
	view_ply = -1
	view_game = null
	live_fen = ""
	analysis_pending = false
	pending_info.clear()
	if analysis_running:
		analysis_running = false
		if engine != null:
			engine.stop()


# Live was switched off while reviewing: stop the engine and clear its lines.
func _pause_review_analysis() -> void:
	live_fen = ""
	analysis_pending = false
	pending_info.clear()
	_clear_branches()
	if analysis_running:
		analysis_running = false
		if engine != null:
			engine.stop()


func _play_from_here() -> void:
	if view_ply < 0 or animating or engine_busy:
		return
	var ply := view_ply
	var removed := played.size() - ply
	_end_review()
	_cancel_search()
	played.resize(ply)
	sans.resize(ply)
	_undo_clock(removed)
	_rebuild()
	_clear_branches()
	_set_eval(0.5, "0.0", false)
	_after_load("Continuing from here")


func _scroll_to_ply() -> void:
	if moves_label == null or view_ply < 0 or sans.is_empty():
		return
	var lead := 1 if start_black else 0
	var rows := (sans.size() + lead + 1) / 2
	var row := (maxi(view_ply, 1) - 1 + lead) / 2
	var bar := moves_label.get_v_scroll_bar()
	var row_height := float(moves_label.get_content_height()) / float(maxi(rows, 1))
	var top := float(row) * row_height
	if top < bar.value:
		bar.value = top
	elif top + row_height > bar.value + bar.page:
		bar.value = top + row_height - bar.page


func _schedule_analysis() -> void:
	pending_info.clear()
	live_fen = ""
	analysis_running = false
	if engine != null:
		engine.stop()
	analysis_pending = true
	analysis_delay = ANALYSIS_DELAY


func _start_analysis() -> void:
	if view_ply < 0 or view_game == null or no_engine or screenshot:
		return
	if _resolved_engine_path().is_empty():
		lines_hint.text = "Stockfish is needed to analyse positions. Download it or choose the file in Settings."
		return
	if not _ensure_engine():
		return
	pending_info.clear()
	var options := _engine_options()
	options["limit_elo"] = false
	options["skill"] = 20
	options["multipv"] = 5
	engine.search(view_game.to_fen(), {"infinite": true}, StockfishUci.engine_settings(options))
	analysis_running = true


# Live analysis: while the live game is on screen and it is your turn (or you
# play a friend), Stockfish analyses the current position until it changes.
# This also restarts the analysis when you return from reviewing a move.
func _live_wanted() -> bool:
	if not show_lines_check.button_pressed or view_ply >= 0 or state != "":
		return false
	if engine_busy or animating or no_engine or screenshot or engine_error != "":
		return false
	if analysis_pending or analysis_running:
		return false
	if _versus() and not _human_to_move():
		return false
	return not _resolved_engine_path().is_empty()


func _sync_live_analysis() -> void:
	if not _live_wanted():
		_stop_live()
		return
	var fen := game.to_fen()
	if fen == live_fen:
		return
	if not _ensure_engine():
		return
	_clear_branches()
	pending_info.clear()
	var options := _engine_options()
	options["limit_elo"] = false
	options["skill"] = 20
	options["multipv"] = 5
	live_fen = fen
	engine.search(fen, {"infinite": true}, StockfishUci.engine_settings(options))


func _stop_live() -> void:
	if live_fen == "":
		return
	live_fen = ""
	pending_info.clear()
	_clear_branches()
	if engine != null:
		engine.stop()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or (library_view != null and library_view.visible):
		return
	var key := event as InputEventKey
	if not key.pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed or key.shift_pressed:
		return
	if key.keycode != KEY_LEFT and key.keycode != KEY_RIGHT and key.keycode != KEY_HOME and key.keycode != KEY_END:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and (not (focus is Button) or focus is OptionButton):
		return
	if settings_open:
		return
	match key.keycode:
		KEY_LEFT:
			_nav_prev()
		KEY_RIGHT:
			_nav_next()
		KEY_HOME:
			_nav_first()
		KEY_END:
			_nav_last()
	get_viewport().set_input_as_handled()


func _update_strips() -> void:
	if top_strip.is_empty() or bottom_strip.is_empty():
		return
	var bottom_white := _bottom_is_white()
	_fill_strip(bottom_strip, bottom_white)
	_fill_strip(top_strip, not bottom_white)


func _fill_strip(strip: Dictionary, is_white: bool) -> void:
	var engine_side := _versus() and is_white != _human_is_white()
	var name_text := "White" if is_white else "Black"
	var sub_text := ""
	if _versus():
		if engine_side:
			name_text = "Stockfish"
			if limit_check.button_pressed:
				sub_text = "Elo cap %d" % int(elo_slider.value)
			else:
				sub_text = "Level %d" % int(skill_slider.value)
		else:
			name_text = "You"
			sub_text = "White" if is_white else "Black"
	var active := (view_ply >= 0 or state == "") and _pos().white_to_move == is_white
	var style := strip["style"] as StyleBoxFlat
	style.bg_color = C_RAISED if active else C_SURFACE
	style.border_color = C_GOLD if active else Color(0, 0, 0, 0)
	(strip["name"] as Label).text = name_text
	_tint((strip["name"] as Label), "font_color", C_TEXT if active else C_MUTED)
	(strip["sub"] as Label).text = sub_text

	var dot_style := _flat(Color("f1ece4") if is_white else Color("1c1815"), 9)
	dot_style.set_border_width_all(2)
	dot_style.border_color = C_GOLD
	(strip["dot"] as Panel).add_theme_stylebox_override("panel", dot_style)

	var box := strip["captured"] as HBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var enemy_sign := -1 if is_white else 1
	var gone := _missing(enemy_sign)
	for kind_value in CAPTURE_ORDER:
		var kind := int(kind_value)
		for _i in int(gone[kind]):
			var icon := TextureRect.new()
			icon.texture = piece_texture_cache.get(enemy_sign * kind) as Texture2D
			icon.custom_minimum_size = Vector2(24, 22)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.add_child(icon)
	var lead := _material_lead()
	if (is_white and lead > 0) or (not is_white and lead < 0):
		var plus := _muted("+%d" % absi(lead))
		plus.autowrap_mode = TextServer.AUTOWRAP_OFF
		_tint(plus, "font_color", C_GOLD_SOFT)
		plus.add_theme_constant_override("outline_size", 0)
		box.add_child(plus)
		plus.custom_minimum_size = Vector2(34, 0)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	(strip["thinking"] as Label).visible = engine_busy and engine_side
	(strip["clock_panel"] as Control).visible = use_clock
	_update_clocks()


func _update_clocks() -> void:
	if top_strip.is_empty() or not use_clock:
		return
	var bottom_white := _bottom_is_white()
	(bottom_strip["clock"] as Label).text = _fmt_clock(_live_ms(white_ms if bottom_white else black_ms, bottom_white))
	(top_strip["clock"] as Label).text = _fmt_clock(_live_ms(black_ms if bottom_white else white_ms, not bottom_white))


func _missing(color_sign: int) -> Dictionary:
	var counts := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for sq in 64:
		var piece := int(_pos().board[sq])
		if piece == 0 or absi(piece) == ChessGame.KING:
			continue
		if (piece > 0) == (color_sign > 0):
			counts[absi(piece)] = int(counts[absi(piece)]) + 1
	var gone := {}
	for kind in START_COUNT:
		gone[kind] = maxi(0, int(START_COUNT[kind]) - int(counts[kind]))
	return gone


func _material_lead() -> int:
	var total := 0
	for sq in 64:
		var piece := int(_pos().board[sq])
		if piece == 0 or absi(piece) == ChessGame.KING:
			continue
		var value := int(PIECE_VALUE[absi(piece)])
		total += value if piece > 0 else -value
	return total


func _set_eval(share: float, label: String, animate: bool = true) -> void:
	if board_view == null:
		return
	board_view.eval_text = label
	if eval_tween != null and eval_tween.is_valid():
		eval_tween.kill()
	if animate and is_inside_tree():
		eval_tween = create_tween()
		eval_tween.tween_property(board_view, "eval_share", share, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		board_view.eval_share = share


func _score_sign() -> int:
	# Entries from Stockfish are for the side to move. Flip them so a plus
	# always means good for you (or for White in pass and play).
	var to_move := 1 if _pos().white_to_move else -1
	var viewer := 1 if (not _versus() or _human_is_white()) else -1
	return to_move * viewer


# The position on the board: the reviewed one when stepping through history,
# otherwise the live game.
func _pos() -> ChessGame:
	if view_ply >= 0 and view_game != null:
		return view_game
	return game


func _apply_eval(entry: Dictionary) -> void:
	var white_sign := 1 if _pos().white_to_move else -1
	var viewer := 1 if (not _versus() or _human_is_white()) else -1
	if bool(entry["has_mate"]):
		var mate := int(entry["mate"]) * white_sign
		_set_eval(1.0 if mate > 0 else 0.0, "M%d" % absi(mate))
		return
	var cp := float(int(entry["cp"]) * white_sign)
	var share := 1.0 / (1.0 + exp(-0.00368208 * cp))
	_set_eval(share, "%+.1f" % (cp * viewer / 100.0))


func _human_to_move() -> bool:
	if state != "":
		return false
	if not _versus():
		return true
	return game.white_to_move == _human_is_white()


func _engine_should_move() -> bool:
	return _versus() and state == "" and view_ply < 0 and not _human_to_move() and not animating and not engine_busy and not screenshot and not no_engine


func _engine_candidates() -> PackedStringArray:
	return EngineSetup.candidates(
		OS.get_executable_path().get_base_dir(),
		ProjectSettings.globalize_path("res://bin"),
	)

func _bundled_engine() -> String:
	for path in _engine_candidates():
		if FileAccess.file_exists(path):
			return path
	return ""


func _resolved_engine_path() -> String:
	var typed := engine_edit.text.strip_edges()
	if typed != "" and FileAccess.file_exists(typed):
		return typed
	return _bundled_engine()


func _engine_caption(entry: Dictionary = {}) -> String:
	var path := _resolved_engine_path()
	if path.is_empty():
		return "No engine file found."
	var known := engine != null and engine.path == path and engine.engine_name != ""
	var kind := ""
	if path == EngineSetup.install_path():
		kind = "Downloaded "
	elif path in _engine_candidates():
		kind = "Bundled "
	var label := engine.engine_name if known else ("Stockfish %s" % EngineSetup.VERSION if kind != "" else "engine")
	var base := "%s%s." % [kind if kind != "" else "Custom ", label]
	var stats := entry
	if stats.is_empty() and engine != null:
		stats = engine.last_entry
	if not stats.is_empty() and int(stats.get("depth", 0)) > 0:
		base += " Depth %d" % int(stats["depth"])
		if int(stats.get("nps", 0)) > 0:
			base += ", %s" % StockfishUci.format_nodes_per_second(int(stats["nps"]))
		base += "."
	return base


func _needs_engine() -> bool:
	return _versus() and _resolved_engine_path().is_empty()


func _update_setup_card() -> void:
	if setup_card == null:
		return
	var busy := installer.busy
	setup_card.visible = busy or _needs_engine()
	lines_box.visible = not setup_card.visible
	setup_download_btn.disabled = busy
	engine_download_btn.disabled = busy
	setup_cancel_btn.visible = busy and not installer.installing
	setup_progress.visible = busy
	setup_status.visible = busy or setup_error != ""
	if not busy:
		setup_status.text = setup_error
		_tint(setup_status, "font_color", Color("f0a090") if setup_error != "" else C_MUTED)


func _start_download() -> void:
	if installer.busy:
		return
	setup_error = ""
	setup_progress.value = 0.0
	setup_status.text = "Connecting…"
	_tint(setup_status, "font_color", C_MUTED)
	installer.start()
	_update_setup_card()


func _on_download_progress(received: int, total: int) -> void:
	if installer.installing:
		setup_progress.value = 100.0
		setup_status.text = "Installing and checking the engine…"
	else:
		setup_progress.value = EngineSetup.progress_ratio(received, total) * 100.0
		setup_status.text = "Downloading   " + EngineSetup.progress_text(received, total)
	_update_setup_card()


func _on_download_finished(path: String, error: String) -> void:
	if error != "":
		setup_error = error
	else:
		setup_error = ""
		engine_edit.text = path
		engine_error = ""
		_save_settings()
	_update_setup_card()
	_refresh()
	if _engine_should_move():
		_start_engine()

func _browse() -> void:
	var current := _resolved_engine_path()
	if current != "":
		dialog.current_dir = current.get_base_dir()
	dialog.popup_centered(Vector2i(960, 640))


func _build_game_io() -> void:
	last_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	save_dialog = FileDialog.new()
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.filters = PackedStringArray(["*.pgn ; Portable Game Notation"])
	save_dialog.title = "Save game"
	save_dialog.file_selected.connect(_on_save_path)
	add_child(save_dialog)

	open_dialog = FileDialog.new()
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.pgn, *.fen, *.txt ; Chess games and positions", "* ; All files"])
	open_dialog.title = "Open game"
	open_dialog.file_selected.connect(_import_file)
	add_child(open_dialog)

	notice_dialog = AcceptDialog.new()
	notice_dialog.title = "NeoChess"
	notice_dialog.dialog_autowrap = true
	notice_dialog.min_size = Vector2i(460, 0)
	add_child(notice_dialog)

	toast = PanelContainer.new()
	var style := _flat(C_RAISED, 12)
	_border(style, C_GOLD)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	toast.add_theme_stylebox_override("panel", style)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.visible = false
	toast_label = Label.new()
	toast_label.add_theme_font_size_override("font_size", 15)
	_tint(toast_label, "font_color", C_TEXT)
	toast.add_child(toast_label)
	add_child(toast)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.offset_top = -32
	toast.offset_bottom = -32
	get_window().files_dropped.connect(_on_files_dropped)


func _notify(text: String) -> void:
	if toast == null:
		return
	toast_label.text = text
	toast.size = Vector2.ZERO
	toast.modulate.a = 1.0
	toast.visible = true
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.6)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	toast_tween.tween_callback(func() -> void: toast.visible = false)


func _show_notice(title: String, text: String) -> void:
	if notice_dialog == null:
		return
	notice_dialog.title = title
	notice_dialog.dialog_text = text
	notice_dialog.popup_centered()


func _on_menu(id: int) -> void:
	match id:
		MENU_COPY_PGN:
			DisplayServer.clipboard_set(_game_pgn())
			_notify("Game copied as PGN")
		MENU_COPY_FEN:
			DisplayServer.clipboard_set(game.to_fen())
			_notify("Position copied as FEN")
		MENU_SAVE:
			save_dialog.current_dir = last_dir
			save_dialog.current_file = "neochess-%s.pgn" % game_date.replace(".", "-")
			save_dialog.popup_centered(Vector2i(960, 640))
		MENU_PASTE:
			_import_text(DisplayServer.clipboard_get(), "Pasted")
		MENU_OPEN:
			open_dialog.current_dir = last_dir
			open_dialog.popup_centered(Vector2i(960, 640))
		MENU_LIBRARY:
			_open_library()


# ---- Game library and opening book -------------------------------------------

var library_error_shown := false
var book_sources_loaded := false


func _library_file() -> String:
	if library_path != "":
		return library_path
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--library="):
			return str(arg).get_slice("=", 1)
	if settings_locked:
		return "user://test_library.db"
	return GameStore.default_path()


# The shared database connection, opened when first needed.
func _store() -> GameStore:
	if library_store != null and library_store.is_open():
		return library_store
	var opened := GameStore.new()
	if not opened.open(_library_file()):
		if not library_error_shown:
			library_error_shown = true
			_show_notice("The game library is not available", opened.error)
		return null
	library_store = opened
	library_path = opened.path
	return opened


# Packaging check: `NeoChess.exe -- --check-library=result.txt` writes whether
# the database library works in this build, then quits.
func _check_library(report: String) -> void:
	var store := _store()
	var text := "library failed"
	if store != null:
		var id := store.add_game(store.add_source("check", GameStore.KIND_IMPORT), GameStore.record({"White": "A", "Black": "B"}, PackedStringArray(["e4", "e5"]), "1-0"))
		text = "library ok %d games=%d sqlite=%s" % [id, store.count({}), str(ClassDB.class_exists("SQLite"))]
	# Release builds once turned "\ufeff" into an empty string, which dropped the
	# first character of every PGN line. Check the real parsers in this build.
	var sample := "[Event \"x\"]\n[White \"A\"]\n\n1. e4 e5 2. Nf3\nNc6 1-0\n\n[Event \"y\"]\n\n1. d4 d5 *\n"
	var parsed := Pgn.parse(sample)
	text += " | pgn=%s moves=%d" % [str(parsed["ok"]), (parsed["sans"] as Array).size()]
	var sample_path := OS.get_user_data_dir().path_join("check_sample.pgn")
	var sample_file := FileAccess.open(sample_path, FileAccess.WRITE)
	if sample_file != null:
		sample_file.store_string(sample)
		sample_file.close()
		var reader := PgnReader.new(FileAccess.open(sample_path, FileAccess.READ))
		var first := reader.next_game()
		var second := reader.next_game()
		text += " openings=%d" % OpeningNames.count()
		text += " reader=%s/%d/%d" % [str((first.get("tags", {}) as Dictionary).get("White", "?")), (first.get("sans", PackedStringArray()) as PackedStringArray).size(), (second.get("sans", PackedStringArray()) as PackedStringArray).size()]
		DirAccess.remove_absolute(sample_path)
	var file := FileAccess.open(report, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
	get_tree().quit()


func _open_library(select_source: int = 0) -> void:
	if animating:
		return
	if _store() == null:
		return
	_set_settings_open(false)
	library_view.show_library(select_source)


# Shows a stored game in the review mode, from the first move.
func _open_library_game(stored: Dictionary, white_bottom: bool) -> void:
	if animating:
		await board_view.animation_finished
	var fen := str(stored["start_fen"]) if str(stored["start_fen"]) != "" else Pgn.START_FEN
	# Replay the moves on a scratch board first, so a damaged game is reported
	# without touching the game on the board.
	var probe: ChessGame = ChessGame.setup(fen)
	var moves: Array = []
	var tokens: PackedStringArray = stored["sans"]
	for index in tokens.size():
		var found := Pgn.find_move(probe, tokens[index])
		if not str(found["error"]).is_empty():
			_show_notice("Could not open the game", "Move %d (%s) of this game is not legal, so it may be damaged in the library. Delete it there and import the file again." % [index + 1, tokens[index]])
			return
		var move: Dictionary = found["move"]
		moves.append(move.duplicate())
		probe.make_move(move)
	_reset_game(fen)
	game_tags = (stored["extra"] as Dictionary).duplicate()
	for pair in [["Event", "event"], ["Site", "site"], ["Date", "date"], ["White", "white"], ["Black", "black"], ["ECO", "eco"], ["Opening", "opening"]]:
		var value := str(stored.get(str(pair[1]), ""))
		if value != "" and value != "?":
			game_tags[str(pair[0])] = value
	for pair in [["WhiteElo", "white_elo"], ["BlackElo", "black_elo"]]:
		if int(stored.get(str(pair[1]), 0)) > 0:
			game_tags[str(pair[0])] = str(int(stored[str(pair[1])]))
	for move in moves:
		sans.append(game.to_san(move))
		played.append(move)
		game.make_move(move)
	recorded_result = str(stored["result"]) if str(stored["result"]) != "*" else ""
	_after_load("Opened from the library: %d moves" % moves.size(), false)
	human_white = white_bottom
	board_flipped = false
	_refresh()
	_goto_ply(0)


# Saves the current game to "My games" (again, with the new moves, when it
# has already been saved). Games loaded from files and the library are not
# saved a second time.
func _archive_game() -> void:
	if not archive_enabled or not archivable or sans.size() < 2:
		return
	var result := _game_result()
	var key := "%d|%s" % [sans.size(), result]
	if key == archived_key:
		return
	var store := _store()
	if store == null:
		return
	var info := _game_info()
	if not info.has("Event"):
		info["Event"] = "NeoChess game"
	if not info.has("Site"):
		info["Site"] = "NeoChess"
	if start_fen != Pgn.START_FEN:
		info["FEN"] = start_fen
	var row := GameStore.record(info, PackedStringArray(sans), result)
	if archive_id > 0:
		store.delete_games([archive_id])
	archive_id = store.add_game(store.mine_source(), row)
	archived_key = key
	book_key = ""


func _on_sources_changed() -> void:
	book_sources_loaded = false
	book_key = ""
	_update_book()


func _on_games_deleted(ids: Array) -> void:
	if archive_id > 0 and ids.has(archive_id):
		archive_id = 0
		archived_key = ""


func _on_imported(source_name: String, added: int) -> void:
	if added > 0 and not book_check.button_pressed:
		book_check.button_pressed = true
		_notify("Opening book switched on: %s" % source_name)


func _build_book_card() -> Control:
	book_card = PanelContainer.new()
	book_card.add_theme_stylebox_override("panel", _card_style())
	book_card.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	book_card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	book_title = Label.new()
	book_title.text = "Opening book"
	book_title.add_theme_font_size_override("font_size", 17)
	book_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tint(book_title, "font_color", C_GOLD_SOFT)
	head.add_child(book_title)
	book_source_opt = OptionButton.new()
	book_source_opt.custom_minimum_size = Vector2(150, 0)
	book_source_opt.fit_to_longest_item = false
	book_source_opt.tooltip_text = "Which games the book counts"
	book_source_opt.add_item("All games")
	head.add_child(book_source_opt)
	book_hint = _muted("")
	col.add_child(book_hint)
	for i in BOOK_ROWS:
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(0, 28)
		row.visible = false
		row.pressed.connect(_on_book_row.bind(i))
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 0)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(stack)
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.add_child(line)
		var name_label := Label.new()
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tint(name_label, "font_color", C_MUTED)
		stack.add_child(name_label)
		var move_label := Label.new()
		move_label.custom_minimum_size = Vector2(58, 0)
		move_label.add_theme_font_size_override("font_size", 16)
		move_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tint(move_label, "font_color", C_TEXT)
		line.add_child(move_label)
		var count_label := Label.new()
		count_label.custom_minimum_size = Vector2(52, 0)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tint(count_label, "font_color", C_MUTED)
		line.add_child(count_label)
		var bar := ResultBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		var score_label := Label.new()
		score_label.custom_minimum_size = Vector2(42, 0)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tint(score_label, "font_color", C_MUTED)
		line.add_child(score_label)
		col.add_child(row)
		book_bars.append({"row": row, "move": move_label, "count": count_label, "bar": bar, "score": score_label, "name": name_label})
	return book_card


# The moves of the shown position from the standard start, or null when the
# book does not apply (a game set up from a FEN).
func _book_line() -> Variant:
	if start_fen != Pgn.START_FEN:
		return null
	var count := view_ply if view_ply >= 0 else sans.size()
	var line := PackedStringArray()
	for i in mini(count, sans.size()):
		line.append(sans[i])
	return line


func _book_sources() -> Array:
	var index := book_source_opt.selected
	if index <= 0 or index >= book_source_ids.size():
		return []
	return [int(book_source_ids[index])]


func _load_book_sources() -> void:
	book_sources_loaded = true
	var store := _store()
	book_source_ids = [0]
	book_source_opt.clear()
	book_source_opt.add_item("All games")
	var chosen := 0
	if store != null:
		for entry in store.sources():
			var source: Dictionary = entry
			if int(source["games"]) <= 0:
				continue
			book_source_opt.add_item(str(source["name"]))
			book_source_ids.append(int(source["id"]))
			if str(source["name"]) == book_source_name:
				chosen = book_source_ids.size() - 1
	book_source_opt.select(chosen)


func _on_book_source(index: int) -> void:
	book_source_name = "" if index <= 0 else book_source_opt.get_item_text(index)
	book_key = ""
	_save_settings()
	_update_book()


func _update_book() -> void:
	if book_card == null:
		return
	var on := book_check.button_pressed
	book_card.visible = on
	if not on:
		return
	var line: Variant = _book_line()
	if line == null:
		_show_book([], "The book covers games from the standard starting position.")
		book_key = ""
		return
	var moves: PackedStringArray = line
	if moves.size() >= GameStore.LINE_PLIES:
		_show_book([], "Past the book: it covers the first %d moves of a game." % (GameStore.LINE_PLIES / 2))
		book_key = ""
		return
	var store := _store()
	if store == null:
		_show_book([], "The game library is not available.")
		return
	if not book_sources_loaded:
		_load_book_sources()
	var sources := _book_sources()
	var key := "%s#%s" % [" ".join(moves), str(sources)]
	if key == book_key:
		return
	book_key = key
	book_hint.text = "Looking up…" if book_rows.is_empty() else book_hint.text
	book_query.db_path = store.path
	book_query.ask(key, moves, sources)


func _on_book_answer(key: String, rows: Array) -> void:
	if key != book_key:
		return
	var total := 0
	for entry in rows:
		total += int((entry as Dictionary)["games"])
	var hint := ""
	if rows.is_empty():
		var store := _store()
		if store != null and store.total_games() == 0:
			hint = "Your library is empty. Open Game ▸ Game library to import a database."
		else:
			hint = "No game in the library goes on from here."
	else:
		hint = "%s games continue from here." % _compact_count(total)
		if _book_can_play():
			hint += " Click a move to play it."
	_show_book(rows, hint)


func _show_book(rows: Array, hint: String) -> void:
	book_rows = rows
	book_hint.text = hint
	book_hint.visible = hint != ""
	for i in book_bars.size():
		var entry: Dictionary = book_bars[i]
		var row_button := entry["row"] as Button
		if i >= rows.size():
			row_button.visible = false
			continue
		var data: Dictionary = rows[i]
		var games := int(data["games"])
		var white := int(data["white"])
		var draw := int(data["draw"])
		var black := int(data["black"])
		row_button.visible = true
		(entry["move"] as Label).text = str(data["move"])
		var named := OpeningNames.find_after(_pos(), str(data["move"])) if start_fen == Pgn.START_FEN else {}
		(entry["name"] as Label).text = str(named.get("name", ""))
		(entry["name"] as Label).visible = not named.is_empty()
		(entry["name"] as Label).tooltip_text = OpeningNames.label(named)
		row_button.custom_minimum_size = Vector2(0, 38 if not named.is_empty() else 28)
		(entry["count"] as Label).text = _compact_count(games)
		(entry["bar"] as ResultBar).set_counts(white, draw, black)
		var score := (float(white) + float(draw) * 0.5) / float(maxi(games, 1))
		(entry["score"] as Label).text = "%d%%" % roundi(score * 100.0)
		row_button.tooltip_text = "%s games: White won %d%%, draw %d%%, Black won %d%%" % [_compact_count(games), roundi(100.0 * white / maxf(games, 1)), roundi(100.0 * draw / maxf(games, 1)), roundi(100.0 * black / maxf(games, 1))]
		row_button.disabled = false


func _book_can_play() -> bool:
	return view_ply < 0 and not animating and not engine_busy and state == "" and _human_to_move() and not promo_box.visible and not side_box.visible


func _on_book_row(index: int) -> void:
	if index >= book_rows.size() or not _book_can_play():
		return
	var san := str((book_rows[index] as Dictionary)["move"])
	for move in legal:
		if game.to_san(move) == san:
			_commit(move)
			return


func _compact_count(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	if value >= 10000:
		return "%dk" % roundi(value / 1000.0)
	if value >= 1000:
		return "%.1fk" % (value / 1000.0)
	return str(value)


# The current game as PGN text (Seven Tag Roster plus FEN for set-up starts).
func _game_pgn() -> String:
	return Pgn.export_game(_game_info(), sans, _game_result(), start_fen)


# The result of the game so far: 1-0, 0-1, 1/2-1/2 or * while it is going on.
func _game_result() -> String:
	var current := game.state_of(game.legal_moves())
	var result := recorded_result if recorded_result != "" else "*"
	if current != "":
		result = Pgn.result_for(current, game.white_to_move)
	return result


# The tags describing the current game.
func _game_info() -> Dictionary:
	var white := "Player"
	var black := "Player"
	if _versus():
		var engine_name := "Stockfish %s" % EngineSetup.VERSION
		if _human_is_white():
			black = engine_name
		else:
			white = engine_name
	else:
		white = "Player 1"
		black = "Player 2"
	var info := {"Date": game_date, "White": white, "Black": black}
	if use_clock:
		info["TimeControl"] = str(clock_minutes * 60)
	if start_fen == Pgn.START_FEN:
		var opening := OpeningNames.find_line(played)
		if not opening.is_empty():
			info["ECO"] = opening["eco"]
			info["Opening"] = opening["name"]
	info.merge(game_tags, true)
	return info


func _on_save_path(path: String) -> void:
	var target := path if path.get_extension() != "" else path + ".pgn"
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		_show_notice("Could not save the game", "NeoChess could not write %s." % target)
		return
	file.store_string(_game_pgn())
	file.close()
	last_dir = target.get_base_dir()
	_notify("Saved %s" % target.get_file())


func _on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	var big := files.size() > 1 or files[0].get_extension().to_lower() == "zip"
	if not big:
		var probe := FileAccess.open(files[0], FileAccess.READ)
		if probe != null:
			big = probe.get_length() > Pgn.MAX_BYTES
			probe.close()
	if library_view.visible or (big and _store() != null):
		if not library_view.visible:
			_open_library()
		library_view.import_files(files)
		return
	_import_file(files[0])


func _import_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_notice("Could not open the file", "NeoChess could not read %s." % path)
		return
	if file.get_length() > Pgn.MAX_BYTES:
		file.close()
		_show_notice("Could not open the file", "%s is too large to be a single game." % path.get_file())
		return
	var text := file.get_as_text()
	file.close()
	last_dir = path.get_base_dir()
	_import_text(text, "Opened %s" % path.get_file())


func _looks_like_fen(text: String) -> bool:
	return not text.contains("\n") and not text.begins_with("[") and text.count("/") == 7


# Loads a PGN game or a FEN position. Returns true when something was loaded.
func _import_text(text: String, source: String, review: bool = false) -> bool:
	if animating:
		_notify("Wait for the move to finish, then try again.")
		return false
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		_notify("Nothing to import. Copy a PGN game or a FEN position first.")
		return false
	if _looks_like_fen(trimmed):
		var problem := ChessGame.fen_error(trimmed)
		if problem != "":
			_show_notice("Could not load the position", problem)
			return false
		_reset_game(trimmed)
		start_fen = game.to_fen()
		_after_load("%s: position loaded" % source)
		return true
	var parsed := Pgn.parse(text)
	if not bool(parsed["ok"]):
		_show_notice("Could not import the game", str(parsed["error"]))
		return false
	_reset_game(str(parsed["start_fen"]))
	game_tags = (parsed["headers"] as Dictionary).duplicate()
	for key in ["FEN", "SetUp", "Result"]:
		game_tags.erase(key)
	for move in parsed["moves"]:
		played.append((move as Dictionary).duplicate())
		game.make_move(move as Dictionary)
	for san in parsed["sans"]:
		sans.append(str(san))
	recorded_result = str(parsed["result"]) if str(parsed["result"]) != "*" else ""
	var count := sans.size()
	var summary := "%d move%s" % [count, "" if count == 1 else "s"]
	if int(parsed["game_count"]) > 1:
		summary += ", first of %d games" % int(parsed["game_count"])
	_after_load("%s: %s loaded" % [source, summary], not review)
	return true


func _after_load(message: String, resume: bool = true) -> void:
	var legal_now := game.legal_moves()
	if _versus() and game.state_of(legal_now) == "":
		human_white = game.white_to_move
	_refresh()
	_notify(message)
	if resume and _engine_should_move():
		_start_engine()


func _on_engine_file(path: String) -> void:
	engine_edit.text = path
	engine_error = ""
	setup_error = ""
	_save_settings()
	_refresh()
	if _engine_should_move():
		_start_engine()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var saved_path := str(cfg.get_value("engine", "path", ""))
	if saved_path != "":
		engine_edit.text = saved_path
	skill_slider.set_value_no_signal(float(cfg.get_value("engine", "skill", skill_slider.value)))
	fixed_movetime = int(cfg.get_value("engine", "movetime", fixed_movetime))
	clock_minutes = clampi(int(cfg.get_value("engine", "clock_minutes", clock_minutes)), 1, 30)
	use_clock = bool(cfg.get_value("engine", "use_clock", false))
	threads_slider.set_value_no_signal(float(cfg.get_value("engine", "threads", threads_slider.value)))
	overhead_slider.set_value_no_signal(float(cfg.get_value("engine", "overhead", overhead_slider.value)))
	elo_slider.set_value_no_signal(float(cfg.get_value("engine", "elo", elo_slider.value)))
	limit_check.button_pressed = bool(cfg.get_value("engine", "limit_elo", false))
	_select_hash(int(cfg.get_value("engine", "hash", 64)))
	mode_opt.selected = int(cfg.get_value("game", "mode", 0))
	human_white = int(cfg.get_value("game", "color", 0)) == 0
	board_index = clampi(int(cfg.get_value("look", "board", 0)), 0, Appearance.board_count() - 1)
	piece_index = clampi(int(cfg.get_value("look", "pieces", 0)), 0, Appearance.piece_count() - 1)
	show_arrow_check.button_pressed = bool(cfg.get_value("view", "arrow", true))
	show_best_check.button_pressed = bool(cfg.get_value("view", "best_arrows", true))
	show_lines_check.button_pressed = bool(cfg.get_value("view", "lines", false))
	book_check.set_pressed_no_signal(bool(cfg.get_value("view", "book", false)))
	book_source_name = str(cfg.get_value("view", "book_source", ""))


func _save_settings() -> void:
	if settings_locked:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("engine", "path", engine_edit.text.strip_edges())
	cfg.set_value("engine", "skill", int(skill_slider.value))
	cfg.set_value("engine", "movetime", fixed_movetime)
	cfg.set_value("engine", "clock_minutes", clock_minutes)
	cfg.set_value("engine", "use_clock", use_clock)
	cfg.set_value("engine", "threads", int(threads_slider.value))
	cfg.set_value("engine", "hash", _hash_choices()[hash_opt.selected])
	cfg.set_value("engine", "overhead", int(overhead_slider.value))
	cfg.set_value("engine", "limit_elo", limit_check.button_pressed)
	cfg.set_value("engine", "elo", int(elo_slider.value))
	cfg.set_value("game", "mode", mode_opt.selected)
	cfg.set_value("game", "color", 0 if human_white else 1)
	cfg.set_value("look", "board", board_index)
	cfg.set_value("look", "pieces", piece_index)
	cfg.set_value("view", "arrow", show_arrow_check.button_pressed)
	cfg.set_value("view", "best_arrows", show_best_check.button_pressed)
	var lines_on := show_lines_check.button_pressed if live_before_review < 0 else live_before_review == 1
	cfg.set_value("view", "lines", lines_on)
	cfg.set_value("view", "book", book_check.button_pressed)
	cfg.set_value("view", "book_source", book_source_name)
	cfg.save(SETTINGS_PATH)


func _prepare_shot() -> void:
	var args := OS.get_cmdline_user_args()
	board_index = 3
	for arg in args:
		if str(arg).begins_with("--board="):
			board_index = int(str(arg).get_slice("=", 1))
	piece_index = 0
	show_arrow_check.set_pressed_no_signal(true)
	show_best_check.set_pressed_no_signal(true)
	show_lines_check.set_pressed_no_signal("--no-lines" not in args)
	for uci in ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5c6", "d7c6"]:
		var move := game.match_uci(uci)
		sans.append(game.to_san(move))
		played.append(move.duplicate())
		game.make_move(move)
	use_clock = true
	white_ms = 4 * 60 * 1000 + 12000
	black_ms = 3 * 60 * 1000 + 47000
	turn_started_ms = Time.get_ticks_msec()
	_apply_time_mode()
	_apply_style()
	_refresh()
	var sample_text := (
		"info depth 18 multipv 1 score cp 28 pv e1g1 f7f6 d2d4 e5d4 f3d4 c6c5 d4e2 c8g4\n" +
		"info depth 18 multipv 2 score cp 21 pv d2d3 f8d6 b1d2 g8e7 d2c4 e8g8\n" +
		"info depth 17 multipv 3 score cp 8 pv f3e5 d8d4 e5f3 d4e4 d1e2 e4e2\n" +
		"info depth 17 multipv 4 score cp -4 pv d2d4 e5d4 d1d4 d8d4 f3d4 c6c5\n" +
		"info depth 16 multipv 5 score cp -19 pv b1c3 f8d6 d2d3 g8f6 c1g5 h7h6\n"
	)
	if "--review" in args:
		_goto_ply(6)
		sample_text = (
			"info depth 21 multipv 1 score cp 31 pv b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 a4b3 d7d6\n" +
			"info depth 21 multipv 2 score cp 27 pv b5c6 d7c6 d2d3 f8d6 b1d2 g8e7\n" +
			"info depth 20 multipv 3 score cp 22 pv d2d3 g8f6 b5a4 f8e7 e1g1 e8g8\n" +
			"info depth 20 multipv 4 score cp 12 pv c2c3 g8f6 b5a4 f8e7 e1g1 e8g8\n" +
			"info depth 19 multipv 5 score cp 4 pv b5a4 d7d6 c2c3 g8f6 e1g1 f8e7\n"
		)
	var sample := StockfishUci.principal_lines(sample_text, 5)
	for entry in sample:
		_apply_branch(entry as Dictionary)
	_apply_eval(sample[0] as Dictionary)
	if "--setup" in args:
		setup_card.visible = true
		lines_box.visible = false
		setup_progress.visible = true
		setup_progress.value = 42.0
		setup_status.visible = true
		setup_status.text = "Downloading   33.8 MB of 80.5 MB"
		setup_cancel_btn.visible = true
	if "--newgame" in args:
		side_box.visible = true
	if "--book" in args:
		book_check.set_pressed_no_signal(true)
		book_key = ""
		_refresh()
		await get_tree().create_timer(2.5).timeout
	if "--library" in args:
		_open_library()
		await get_tree().create_timer(0.5).timeout
	if "--settings" in args:
		_set_settings_open(true)
		if "--play" in args:
			_show_settings_page(0)
		else:
			_show_settings_page(1)
			preview_board = 5
			_apply_style()
	await get_tree().process_frame
	_layout_board_area()
	if eval_tween != null and eval_tween.is_valid():
		eval_tween.kill()
	board_view.eval_share = 1.0 / (1.0 + exp(-0.00368208 * 28.0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.tools/preview.png")
	image.save_png(path)
	get_tree().quit()


func _make_theme() -> Theme:
	var made := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	made.default_font = font
	made.default_font_size = 15

	var button := _flat(Color("3a3128"), 8)
	var button_hover := _flat(Color("4a3d32"), 8)
	var button_down := _flat(Color("2a231c"), 8)
	var button_off := _flat(Color("2a241e"), 8)
	var field := _flat(Color("241c17"), 8)
	var field_focus := _flat(Color("241c17"), 8)
	_border(field_focus, Color("c6a15b"))
	field_focus.set_border_width_all(1)
	var popup := _flat(Color("2a231c"), 8)
	var popup_hover := _flat(Color("c6a15b"), 6)

	_theme_color(made, "font_color", "Label", Color("f4ede4"))
	_theme_color(made, "font_color", "CheckButton", Color("f4ede4"))
	_theme_color(made, "font_hover_color", "CheckButton", Color("fff8ee"))
	_theme_color(made, "font_color", "Button", Color("f4ede4"))
	_theme_color(made, "font_hover_color", "Button", Color("fff8ee"))
	_theme_color(made, "font_pressed_color", "Button", Color("f4ede4"))
	_theme_color(made, "font_disabled_color", "Button", Color("8a7b6a"))
	made.set_stylebox("normal", "Button", button)
	made.set_stylebox("hover", "Button", button_hover)
	made.set_stylebox("pressed", "Button", button_down)
	made.set_stylebox("disabled", "Button", button_off)
	made.set_stylebox("normal", "OptionButton", button)
	made.set_stylebox("hover", "OptionButton", button_hover)
	made.set_stylebox("pressed", "OptionButton", button_down)
	_theme_color(made, "font_color", "LineEdit", Color("f4ede4"))
	_theme_color(made, "font_placeholder_color", "LineEdit", Color("8a7b6a"))
	_theme_color(made, "caret_color", "LineEdit", Color("e4c37a"))
	made.set_stylebox("normal", "LineEdit", field)
	made.set_stylebox("focus", "LineEdit", field_focus)
	_theme_color(made, "default_color", "RichTextLabel", Color("f4ede4"))
	_theme_color(made, "font_color", "PopupMenu", Color("f4ede4"))
	_theme_color(made, "font_hover_color", "PopupMenu", Color("1c140c"))
	made.set_stylebox("panel", "PopupMenu", popup)
	made.set_stylebox("hover", "PopupMenu", popup_hover)

	var track := _flat(Color("3a3128"), 4)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	var fill := _flat(Color("c6a15b"), 4)
	made.set_stylebox("slider", "HSlider", track)
	made.set_stylebox("grabber_area", "HSlider", fill)
	made.set_stylebox("grabber_area_highlight", "HSlider", fill)

	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.set_border_width_all(2)
	_border(ring, C_GOLD_SOFT)
	ring.set_corner_radius_all(8)
	for kind in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		made.set_stylebox("focus", kind, ring)
	return made


func _card_style() -> StyleBoxFlat:
	var box := _flat(C_SURFACE, 12)
	_border(box, C_LINE)
	box.set_border_width_all(1)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


func _token_of(color: Color) -> String:
	for key in pal:
		if (pal[key] as Color) == color:
			return str(key)
	return ""


func _bind(obj: Object, prop: String, color: Color) -> void:
	var key := "%d|%s" % [obj.get_instance_id(), prop]
	var token := _token_of(color)
	if token == "":
		bindings.erase(key)
		return
	bindings[key] = [weakref(obj), prop, token]


func _tint(node: Control, key: String, color: Color) -> void:
	node.add_theme_color_override(key, color)
	_bind(node, "theme_override_colors/" + key, color)


func _theme_color(target: Theme, key: String, type_name: String, color: Color) -> void:
	target.set_color(key, type_name, color)
	_bind(target, type_name + "|" + key, color)


func _border(box: StyleBoxFlat, color: Color) -> void:
	box.border_color = color
	_bind(box, "border_color", color)


func _set_bound(obj: Object, prop: String, color: Color) -> void:
	if obj is Theme:
		var parts := prop.split("|")
		(obj as Theme).set_color(parts[1], parts[0], color)
	elif prop.begins_with("theme_override_colors/"):
		(obj as Control).add_theme_color_override(prop.get_slice("/", 1), color)
	else:
		obj.set(prop, color)


func _apply_palette(index: int) -> void:
	if index == palette_key:
		return
	palette_key = index
	var fresh := Appearance.palette(index)
	for key in bindings.keys():
		var entry: Array = bindings[key]
		var obj: Object = (entry[0] as WeakRef).get_ref()
		if obj == null:
			bindings.erase(key)
			continue
		_set_bound(obj, str(entry[1]), fresh[str(entry[2])] as Color)
	pal = fresh
	C_BG = pal["bg"]
	C_SURFACE = pal["surface"]
	C_RAISED = pal["raised"]
	C_LINE = pal["line"]
	C_GOLD = pal["gold"]
	C_GOLD_SOFT = pal["gold_soft"]
	C_TEXT = pal["text"]
	C_MUTED = pal["muted"]
	C_DIM = pal["dim"]
	if moves_label == null or status_label == null:
		return
	_paint_status()
	moves_label.text = _moves_bbcode()
	_mark_chips()
	_update_strips()
	_scroll_moves.call_deferred()

func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	_bind(box, "bg_color", color)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _hover_look(kind: String, index: int) -> void:
	if kind == "board":
		preview_board = index
		preview_piece = -1
	else:
		preview_piece = index
		preview_board = -1
	_apply_style()


func _unhover_look(kind: String, index: int) -> void:
	var current := preview_board if kind == "board" else preview_piece
	if current != index:
		return
	preview_board = -1
	preview_piece = -1
	_apply_style()


func _confirm_look(kind: String, index: int) -> void:
	if kind == "board":
		board_index = index
	else:
		piece_index = index
	preview_board = -1
	preview_piece = -1
	_apply_style()
	_save_settings()


func _shown_board() -> int:
	return preview_board if preview_board >= 0 else board_index


func _shown_piece() -> int:
	return preview_piece if preview_piece >= 0 else piece_index


func _apply_style() -> void:
	var shown_board := clampi(_shown_board(), 0, Appearance.board_count() - 1)
	var shown_piece := clampi(_shown_piece(), 0, Appearance.piece_count() - 1)
	var colors := Appearance.board(shown_board)
	_apply_palette(shown_board)
	piece_texture_cache = PieceArt.textures_for(shown_piece)
	board_view.apply_style(colors, piece_texture_cache)
	_mark_chips()
	_update_strips()


func _mark_chips() -> void:
	_mark_group(board_chips, board_index)
	_mark_group(piece_chips, piece_index)


func _mark_group(chips: Array, chosen: int) -> void:
	for i in chips.size():
		var chip := chips[i] as Button
		if i == chosen:
			var picked := _flat(pal["picked"] as Color, 8)
			_border(picked, C_GOLD)
			picked.set_border_width_all(2)
			chip.add_theme_stylebox_override("normal", picked)
			chip.add_theme_stylebox_override("hover", picked)
		else:
			chip.remove_theme_stylebox_override("normal")
			chip.remove_theme_stylebox_override("hover")


func _engine_options() -> Dictionary:
	return {
		"skill": int(skill_slider.value),
		"movetime": fixed_movetime,
		"clock": use_clock,
		"wtime": maxi(white_ms, 100),
		"btime": maxi(black_ms, 100),
		"inc": 0,
		"threads": int(threads_slider.value),
		"hash": _hash_choices()[hash_opt.selected],
		"overhead": int(overhead_slider.value),
		"limit_elo": limit_check.button_pressed,
		"elo": int(elo_slider.value),
		"multipv": 5 if show_lines_check.button_pressed else 1,
	}


func _hash_choices() -> Array:
	return [16, 32, 64, 128, 256]


func _select_hash(mb: int) -> void:
	var choices := _hash_choices()
	var best := 0
	for i in choices.size():
		if int(choices[i]) == mb:
			hash_opt.selected = i
			return
		if absi(int(choices[i]) - mb) < absi(int(choices[best]) - mb):
			best = i
	hash_opt.selected = best


func _process(delta: float) -> void:
	if use_clock:
		_update_clocks()
	if analysis_pending:
		analysis_delay -= delta
		if analysis_delay <= 0.0:
			analysis_pending = false
			_start_analysis()
	_sync_live_analysis()
	_flush_info()


func _set_time_mode(clock: bool) -> void:
	if clock == use_clock:
		return
	if use_clock:
		clock_minutes = clampi(int(time_slider.value), 1, 30)
	else:
		fixed_movetime = int(time_slider.value)
	use_clock = not use_clock
	if use_clock and played.is_empty():
		_reset_clocks()
	_apply_time_mode()
	_save_settings()
	_refresh()


func _on_time_slider() -> void:
	if use_clock:
		clock_minutes = clampi(int(time_slider.value), 1, 30)
		if played.is_empty():
			_reset_clocks()
	else:
		fixed_movetime = int(time_slider.value)
	_sync_engine_controls()
	if use_clock:
		_refresh()


func _apply_time_mode() -> void:
	time_slider.set_block_signals(true)
	if use_clock:
		time_caption.text = "Minutes per side"
		time_slider.min_value = 1
		time_slider.max_value = 30
		time_slider.step = 1
		time_slider.value = clock_minutes
	else:
		time_caption.text = "Time per move"
		time_slider.min_value = 100
		time_slider.max_value = 2000
		time_slider.step = 50
		time_slider.value = fixed_movetime
	time_slider.set_block_signals(false)
	(time_mode_btns[1] as Button).set_pressed_no_signal(use_clock)
	(time_mode_btns[0] as Button).set_pressed_no_signal(not use_clock)
	set_process(true)
	_sync_engine_controls()


func _reset_clocks() -> void:
	var budget := clock_minutes * 60 * 1000
	white_ms = budget
	black_ms = budget
	turn_started_ms = Time.get_ticks_msec()


func _charge_turn() -> void:
	if not use_clock:
		return
	clock_stack.append({"w": white_ms, "b": black_ms})
	var elapsed := Time.get_ticks_msec() - turn_started_ms
	if elapsed < 0:
		elapsed = 0
	if game.white_to_move:
		white_ms = maxi(0, white_ms - elapsed)
	else:
		black_ms = maxi(0, black_ms - elapsed)
	turn_started_ms = Time.get_ticks_msec()


func _undo_clock(steps: int) -> void:
	var snap: Dictionary = {}
	for _i in steps:
		if clock_stack.is_empty():
			break
		snap = clock_stack.pop_back()
	if not snap.is_empty():
		white_ms = int(snap.w)
		black_ms = int(snap.b)
	turn_started_ms = Time.get_ticks_msec()


func _live_ms(stored: int, for_white: bool) -> int:
	if not use_clock or state != "" or game.white_to_move != for_white:
		return stored
	return maxi(0, stored - (Time.get_ticks_msec() - turn_started_ms))


func _fmt_clock(ms: int) -> String:
	var total := maxi(ms, 0) / 1000
	return "%d:%02d" % [total / 60, total % 60]


func _sync_engine_controls() -> void:
	var limited := limit_check.button_pressed
	skill_slider.editable = not limited
	elo_label.visible = limited
	elo_slider.visible = limited
	if limited:
		skill_label.text = "Elo cap"
	else:
		skill_label.text = "Level %d" % int(skill_slider.value)
	if use_clock:
		time_label.text = "%d min" % clock_minutes
	else:
		time_label.text = "%.2f s" % (fixed_movetime / 1000.0)
	threads_label.text = "Threads  %d" % int(threads_slider.value)
	overhead_label.text = "Move overhead  %d ms" % int(overhead_slider.value)
	elo_label.text = "Elo cap  %d" % int(elo_slider.value)
	_update_strips()


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	_tint(label, "font_color", Color("e4c37a"))
	return label


func _pair_icon(light: Color, dark: Color) -> Texture2D:
	var image := Image.create(28, 16, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 14, 16), light)
	image.fill_rect(Rect2i(14, 0, 14, 16), dark)
	return ImageTexture.create_from_image(image)


func _slider_block(label: Label, slider: HSlider) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(110, 0)
	box.add_child(label)
	box.add_child(slider)
	return box


func _swatch(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(28, 22)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _muted(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	_tint(label, "font_color", Color("b3a394"))
	return label


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(C_GOLD, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rule
