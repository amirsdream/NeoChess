class_name LibraryView
extends Control

# The game library window: browse, search, review, export and delete the games
# in the SQLite library, and import big PGN databases in the background.
# `app` is the main scene; it provides the database connection and the theme
# helpers so this window follows the board theme.

signal open_game(stored: Dictionary, white_bottom: bool)
signal closed
signal sources_changed
signal games_deleted(ids: Array)
signal message(text: String)
signal imported(source_name: String, added: int)

const PAGE := 100
const RESULT_CHOICES := [["Any result", ""], ["White won", "1-0"], ["Draw", "1/2-1/2"], ["Black won", "0-1"]]
const SORT_CHOICES := [["Newest first", "date"], ["Oldest first", "oldest"], ["Highest rated", "rating"], ["Longest games", "length"]]
const RATING_CHOICES := [["Any rating", 0], ["1800+", 1800], ["2000+", 2000], ["2200+", 2200], ["2400+", 2400], ["2600+", 2600]]

var app: Control
var importer: GameImporter
var downloader: DatabaseDownloader

var source_list: ItemList
var source_ids: Array = []
var search_edit: LineEdit
var result_opt: OptionButton
var sort_opt: OptionButton
var rating_opt: OptionButton
var year_from_edit: LineEdit
var year_to_edit: LineEdit
var tree: Tree
var empty_label: Label
var page_label: Label
var prev_btn: Button
var next_btn: Button
var open_btn: Button
var export_btn: Button
var delete_btn: Button
var remove_btn: Button
var info_label: Label
var progress_box: Control
var progress_bar: ProgressBar
var progress_label: Label
var progress_cancel: Button
var download_box: PanelContainer
var month_opt: OptionButton
var download_hint: Label
var import_dialog: FileDialog
var export_dialog: FileDialog
var confirm: ConfirmationDialog
var search_timer: Timer

var page := 0
var total := 0
var all_games := 0
var query_thread: Thread
var query_busy := false
var query_next := {}
var rows: Dictionary = {}
var pending_delete: Array = []
var import_queue: Array = []
var current_job: Dictionary = {}
var download_job: Dictionary = {}
var last_dir := ""


func _init(main: Control) -> void:
	app = main
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_build()
	importer = GameImporter.new()
	add_child(importer)
	importer.finished.connect(_on_import_finished)
	downloader = DatabaseDownloader.new()
	add_child(downloader)
	downloader.progress.connect(_on_download_progress)
	downloader.finished.connect(_on_download_finished)
	set_process(false)


func _exit_tree() -> void:
	query_next = {}
	if query_thread != null and query_thread.is_started():
		query_thread.wait_to_finish()


func is_busy() -> bool:
	return importer.running or downloader.busy or not import_queue.is_empty()


# --- showing and hiding ------------------------------------------------------

func show_library(select_source: int = 0) -> void:
	visible = true
	download_box.visible = false
	_reload_sources(select_source)
	_reload_games(0)
	search_edit.grab_focus()
	set_process(true)


func hide_library() -> void:
	if not visible:
		return
	visible = false
	download_box.visible = false
	set_process(is_busy())
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if download_box.visible:
			download_box.visible = false
		else:
			hide_library()
		get_viewport().set_input_as_handled()


# --- building the window -----------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(edge, 28)
	add_child(margin)

	var card := PanelContainer.new()
	var style: StyleBoxFlat = app._flat(app.C_SURFACE, 16)
	app._border(style, app.C_GOLD)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	margin.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	col.add_child(_build_head())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_build_sources())
	body.add_child(_build_games())

	progress_box = _build_progress()
	col.add_child(progress_box)

	download_box = _build_download_box()
	add_child(download_box)

	import_dialog = FileDialog.new()
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	import_dialog.filters = PackedStringArray(["*.pgn, *.zip ; Chess game databases", "* ; All files"])
	import_dialog.title = "Import games"
	import_dialog.files_selected.connect(import_files)
	add_child(import_dialog)

	export_dialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = PackedStringArray(["*.pgn ; Portable Game Notation"])
	export_dialog.title = "Export games"
	export_dialog.file_selected.connect(_on_export_path)
	add_child(export_dialog)

	confirm = ConfirmationDialog.new()
	confirm.title = "Delete games"
	confirm.dialog_autowrap = true
	confirm.min_size = Vector2i(440, 0)
	confirm.confirmed.connect(_do_delete)
	add_child(confirm)

	search_timer = Timer.new()
	search_timer.one_shot = true
	search_timer.wait_time = 0.3
	search_timer.timeout.connect(func() -> void: _reload_games(0))
	add_child(search_timer)


func _build_head() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Game library"
	title.add_theme_font_size_override("font_size", 22)
	app._tint(title, "font_color", app.C_GOLD_SOFT)
	head.add_child(title)
	info_label = Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app._tint(info_label, "font_color", app.C_MUTED)
	head.add_child(info_label)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(88, 36)
	close.pressed.connect(hide_library)
	head.add_child(close)
	return head


func _build_sources() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(250, 0)
	col.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "Collections"
	title.add_theme_font_size_override("font_size", 16)
	app._tint(title, "font_color", app.C_GOLD_SOFT)
	col.add_child(title)
	source_list = ItemList.new()
	source_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_list.select_mode = ItemList.SELECT_SINGLE
	source_list.item_selected.connect(func(_index: int) -> void: _on_source_selected())
	col.add_child(source_list)
	var import_btn := Button.new()
	import_btn.text = "Import games…"
	import_btn.tooltip_text = "Add a PGN file or a zip of PGN files. You can also drop files on the window."
	import_btn.custom_minimum_size = Vector2(0, 38)
	import_btn.pressed.connect(_on_import_pressed)
	col.add_child(import_btn)
	var download_btn := Button.new()
	download_btn.text = "Download a database…"
	download_btn.tooltip_text = "Free games of strong players from Lichess"
	download_btn.custom_minimum_size = Vector2(0, 38)
	download_btn.pressed.connect(_show_download)
	col.add_child(download_btn)
	remove_btn = Button.new()
	remove_btn.text = "Remove collection"
	remove_btn.custom_minimum_size = Vector2(0, 38)
	remove_btn.pressed.connect(_on_remove_source)
	col.add_child(remove_btn)
	return col


func _build_games() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	col.add_child(filters)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Search player, event or opening"
	search_edit.clear_button_enabled = true
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.text_changed.connect(func(_text: String) -> void: search_timer.start())
	filters.add_child(search_edit)
	result_opt = _choices(RESULT_CHOICES)
	filters.add_child(result_opt)
	rating_opt = _choices(RATING_CHOICES)
	filters.add_child(rating_opt)
	sort_opt = _choices(SORT_CHOICES)
	filters.add_child(sort_opt)

	var years := HBoxContainer.new()
	years.add_theme_constant_override("separation", 8)
	col.add_child(years)
	var year_label := Label.new()
	year_label.text = "Played between"
	app._tint(year_label, "font_color", app.C_MUTED)
	years.add_child(year_label)
	year_from_edit = _year_edit("from")
	years.add_child(year_from_edit)
	var and_label := Label.new()
	and_label.text = "and"
	app._tint(and_label, "font_color", app.C_MUTED)
	years.add_child(and_label)
	year_to_edit = _year_edit("to")
	years.add_child(year_to_edit)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	years.add_child(spacer)
	var clear := Button.new()
	clear.text = "Clear filters"
	clear.pressed.connect(_clear_filters)
	years.add_child(clear)

	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = Vector2(0, 260)
	col.add_child(holder)
	tree = Tree.new()
	tree.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree.columns = 6
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_MULTI
	tree.allow_reselect = true
	var titles := ["Date", "White", "Black", "Result", "Opening", "Moves"]
	var widths := [90, 190, 190, 62, 190, 56]
	for i in titles.size():
		tree.set_column_title(i, str(titles[i]))
		tree.set_column_expand(i, i == 1 or i == 2 or i == 4)
		tree.set_column_custom_minimum_width(i, int(widths[i]))
		tree.set_column_clip_content(i, true)
	tree.item_activated.connect(_open_selected)
	tree.multi_selected.connect(func(_item: TreeItem, _column: int, _selected: bool) -> void: _update_buttons())
	tree.item_selected.connect(_update_buttons)
	tree.nothing_selected.connect(_update_buttons)
	holder.add_child(tree)
	empty_label = Label.new()
	empty_label.set_anchors_preset(Control.PRESET_CENTER)
	empty_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	empty_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.custom_minimum_size = Vector2(420, 0)
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app._tint(empty_label, "font_color", app.C_MUTED)
	holder.add_child(empty_label)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	col.add_child(foot)
	prev_btn = Button.new()
	prev_btn.text = "‹ Previous"
	prev_btn.pressed.connect(func() -> void: _reload_games(page - 1))
	foot.add_child(prev_btn)
	page_label = Label.new()
	page_label.custom_minimum_size = Vector2(190, 0)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app._tint(page_label, "font_color", app.C_MUTED)
	foot.add_child(page_label)
	next_btn = Button.new()
	next_btn.text = "Next ›"
	next_btn.pressed.connect(func() -> void: _reload_games(page + 1))
	foot.add_child(next_btn)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	delete_btn = Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(_on_delete_pressed)
	foot.add_child(delete_btn)
	export_btn = Button.new()
	export_btn.text = "Export PGN…"
	export_btn.pressed.connect(_on_export_pressed)
	foot.add_child(export_btn)
	open_btn = Button.new()
	open_btn.text = "Review game"
	open_btn.custom_minimum_size = Vector2(130, 38)
	app._make_primary(open_btn, 10)
	open_btn.pressed.connect(_open_selected)
	foot.add_child(open_btn)
	return col


func _build_progress() -> Control:
	var box := HBoxContainer.new()
	box.visible = false
	box.add_theme_constant_override("separation", 12)
	progress_label = Label.new()
	progress_label.custom_minimum_size = Vector2(330, 0)
	progress_label.clip_text = true
	app._tint(progress_label, "font_color", app.C_TEXT)
	box.add_child(progress_label)
	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_bar.show_percentage = false
	progress_bar.max_value = 1.0
	box.add_child(progress_bar)
	progress_cancel = Button.new()
	progress_cancel.text = "Cancel"
	progress_cancel.pressed.connect(_cancel_work)
	box.add_child(progress_cancel)
	return box


func _build_download_box() -> PanelContainer:
	var box := PanelContainer.new()
	box.visible = false
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style: StyleBoxFlat = app._flat(app.C_RAISED, 14)
	app._border(style, app.C_GOLD)
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(430, 0)
	col.add_theme_constant_override("separation", 10)
	box.add_child(col)
	var title := Label.new()
	title.text = "Lichess Elite database"
	title.add_theme_font_size_override("font_size", 20)
	app._tint(title, "font_color", app.C_GOLD_SOFT)
	col.add_child(title)
	var about := Label.new()
	about.text = "Rated games of strong players (2400+ against 2200+) played on Lichess, one month per download. Each month holds about 300,000 games and takes one to two minutes to add."
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app._tint(about, "font_color", app.C_MUTED)
	col.add_child(about)
	var pick := HBoxContainer.new()
	pick.add_theme_constant_override("separation", 8)
	col.add_child(pick)
	var month_label := Label.new()
	month_label.text = "Month"
	pick.add_child(month_label)
	month_opt = OptionButton.new()
	month_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for month in DatabaseDownloader.months():
		month_opt.add_item(month)
	pick.add_child(month_opt)
	download_hint = Label.new()
	download_hint.text = "The download is 70 to 260 MB. Source: database.nikonoel.fr, games from lichess.org (CC0)."
	download_hint.add_theme_font_size_override("font_size", 13)
	download_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app._tint(download_hint, "font_color", app.C_DIM)
	col.add_child(download_hint)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	var go := Button.new()
	go.text = "Download and add"
	go.custom_minimum_size = Vector2(0, 40)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app._make_primary(go, 10)
	go.pressed.connect(_start_download)
	buttons.add_child(go)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(90, 40)
	cancel.pressed.connect(func() -> void: download_box.visible = false)
	buttons.add_child(cancel)
	return box


func _choices(items: Array) -> OptionButton:
	var option := OptionButton.new()
	for item in items:
		option.add_item(str((item as Array)[0]))
	option.item_selected.connect(func(_index: int) -> void: _reload_games(0))
	return option


func _year_edit(hint: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = hint
	edit.custom_minimum_size = Vector2(76, 0)
	edit.max_length = 4
	edit.text_changed.connect(func(_text: String) -> void: search_timer.start())
	return edit


func _clear_filters() -> void:
	search_edit.text = ""
	result_opt.select(0)
	rating_opt.select(0)
	sort_opt.select(0)
	year_from_edit.text = ""
	year_to_edit.text = ""
	_reload_games(0)


# --- collections -------------------------------------------------------------

func _store() -> GameStore:
	return app._store()


func selected_source() -> int:
	var picked := source_list.get_selected_items()
	if picked.is_empty() or int(picked[0]) >= source_ids.size():
		return 0
	return int(source_ids[picked[0]])


func _reload_sources(select_id: int = -1) -> void:
	var keep := select_id if select_id >= 0 else selected_source()
	source_list.clear()
	source_ids = [0]
	var all_total := 0
	var store := _store()
	var list: Array = store.sources() if store != null else []
	for entry in list:
		all_total += int((entry as Dictionary)["games"])
	source_list.add_item("All games  ·  %s" % _thousands(all_total))
	for entry in list:
		var source: Dictionary = entry
		source_list.add_item("%s  ·  %s" % [source["name"], _thousands(int(source["games"]))])
		source_ids.append(int(source["id"]))
	var index := source_ids.find(keep)
	source_list.select(maxi(index, 0))
	_update_remove_button()


func _on_source_selected() -> void:
	_update_remove_button()
	_reload_games(0)


func _update_remove_button() -> void:
	var id := selected_source()
	var store := _store()
	var entry: Dictionary = store.source(id) if (store != null and id > 0) else {}
	remove_btn.disabled = entry.is_empty() or str(entry.get("kind", "")) == GameStore.KIND_MINE
	remove_btn.tooltip_text = "Delete this collection and every game in it" if not remove_btn.disabled else "Select an imported collection to remove it"


func _on_remove_source() -> void:
	var id := selected_source()
	var store := _store()
	if store == null or id <= 0:
		return
	var entry := store.source(id)
	if entry.is_empty():
		return
	pending_delete = []
	confirm.title = "Remove collection"
	confirm.dialog_text = "Remove \"%s\" and its %s games from the library? The original file is not touched." % [entry["name"], _thousands(int(entry["games"]))]
	confirm.set_meta("source", id)
	confirm.popup_centered()


# --- listing games -----------------------------------------------------------

func filters() -> Dictionary:
	var f := {"sort": str((SORT_CHOICES[sort_opt.selected] as Array)[1])}
	var source := selected_source()
	if source > 0:
		f["sources"] = [source]
	f["text"] = search_edit.text.strip_edges()
	f["result"] = str((RESULT_CHOICES[result_opt.selected] as Array)[1])
	f["min_elo"] = int((RATING_CHOICES[rating_opt.selected] as Array)[1])
	f["year_from"] = year_from_edit.text.to_int()
	f["year_to"] = year_to_edit.text.to_int()
	return f


# Asks for a page of games. The database is searched on a worker thread, so a
# library of millions of games never freezes the window; only the newest
# question is answered.
func _reload_games(new_page: int) -> void:
	if _store() == null:
		return
	query_next = {"filters": filters(), "page": new_page}
	if not query_busy:
		_launch_query()


func is_searching() -> bool:
	return query_busy or not query_next.is_empty()


func _launch_query() -> void:
	if query_next.is_empty():
		return
	var job := query_next
	query_next = {}
	query_busy = true
	page_label.text = "Searching…"
	if query_thread != null and query_thread.is_started():
		query_thread.wait_to_finish()
	query_thread = Thread.new()
	query_thread.start(_query_work.bind(job, _store_path()))


func _query_work(job: Dictionary, db_path: String) -> void:
	var answer := {"filters": job["filters"], "found": [], "total": 0, "all": 0, "page": 0}
	var store := GameStore.new()
	if store.open(db_path):
		var f: Dictionary = job["filters"]
		var total_found := store.count(f)
		var pages := maxi(ceili(float(total_found) / float(PAGE)), 1)
		var wanted := clampi(int(job["page"]), 0, pages - 1)
		answer["total"] = total_found
		answer["page"] = wanted
		answer["found"] = store.search(f, PAGE, wanted * PAGE)
		answer["all"] = store.total_games()
		store.close()
	_query_done.call_deferred(answer)


func _query_done(answer: Dictionary) -> void:
	if query_thread != null and query_thread.is_started():
		query_thread.wait_to_finish()
	query_busy = false
	if not query_next.is_empty():
		_launch_query()
		return
	_show_results(answer)


func _show_results(answer: Dictionary) -> void:
	var f: Dictionary = answer["filters"]
	var found: Array = answer["found"]
	total = int(answer["total"])
	page = int(answer["page"])
	var pages := maxi(ceili(float(total) / float(PAGE)), 1)
	tree.clear()
	rows = {}
	var root := tree.create_item()
	for entry in found:
		var row: Dictionary = entry
		var item := tree.create_item(root)
		var id := int(row["id"])
		rows[id] = row
		item.set_metadata(0, id)
		item.set_text(0, str(row["date"]).replace("????.??.??", ""))
		item.set_text(1, _player(str(row["white"]), int(row["white_elo"])))
		item.set_text(2, _player(str(row["black"]), int(row["black_elo"])))
		item.set_text(3, _result_text(str(row["result"])))
		item.set_text_alignment(3, HORIZONTAL_ALIGNMENT_CENTER)
		var opening := str(row["opening"])
		if opening == "" or opening == "?":
			opening = str(row["eco"])
		item.set_text(4, opening)
		item.set_text(5, str((int(row["plies"]) + 1) / 2))
		item.set_text_alignment(5, HORIZONTAL_ALIGNMENT_RIGHT)
	var first := page * PAGE + 1
	if total == 0:
		page_label.text = "No games"
	else:
		page_label.text = "%s–%s of %s" % [_thousands(first), _thousands(first + found.size() - 1), _thousands(total)]
	prev_btn.disabled = page <= 0
	next_btn.disabled = page >= pages - 1
	all_games = int(answer["all"])
	_update_empty_message(f)
	_update_buttons()
	info_label.text = "%s games" % _thousands(all_games)


func _update_empty_message(f: Dictionary) -> void:
	empty_label.visible = total == 0
	if total > 0:
		return
	var filtered: bool = str(f["text"]) != "" or str(f["result"]) != "" or int(f["min_elo"]) > 0 or int(f["year_from"]) > 0 or int(f["year_to"]) > 0
	if filtered:
		empty_label.text = "No games match these filters."
	elif all_games == 0:
		empty_label.text = "Your library is empty.\n\nGames you play are saved here automatically. Import a PGN file, or download a free database of strong players' games."
	else:
		empty_label.text = "This collection has no games."


func _update_buttons() -> void:
	var count := _selected_ids().size()
	open_btn.disabled = count != 1
	export_btn.disabled = count == 0
	delete_btn.disabled = count == 0
	delete_btn.text = "Delete" if count <= 1 else "Delete %d" % count
	export_btn.text = "Export PGN…" if count <= 1 else "Export %d…" % count


func _selected_ids() -> Array:
	var ids: Array = []
	if tree == null:
		return ids
	var item := tree.get_next_selected(null)
	while item != null:
		ids.append(int(item.get_metadata(0)))
		item = tree.get_next_selected(item)
	return ids


func _player(name: String, elo: int) -> String:
	return name if elo <= 0 else "%s (%d)" % [name, elo]


func _result_text(result: String) -> String:
	return "½-½" if result == "1/2-1/2" else result


func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out


# --- opening, exporting, deleting ---------------------------------------------

func _open_selected() -> void:
	var ids := _selected_ids()
	if ids.size() != 1:
		return
	var id := int(ids[0])
	var store := _store()
	var stored := store.game(id)
	if stored.is_empty():
		message.emit("That game could not be read.")
		return
	var row: Dictionary = rows.get(id, {})
	var white_bottom := not str(row.get("white", "")).begins_with("Stockfish")
	visible = false
	set_process(is_busy())
	open_game.emit(stored, white_bottom)
	closed.emit()


func _on_export_pressed() -> void:
	var ids := _selected_ids()
	if ids.is_empty():
		return
	export_dialog.current_dir = last_dir if last_dir != "" else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	export_dialog.current_file = "neochess-games.pgn" if ids.size() > 1 else "neochess-game.pgn"
	export_dialog.popup_centered(Vector2i(960, 640))


func _on_export_path(path: String) -> void:
	var target := path if path.get_extension() != "" else path + ".pgn"
	var parts := PackedStringArray()
	var store := _store()
	for id in _selected_ids():
		parts.append(store.pgn_of(int(id)).strip_edges())
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		message.emit("Could not write %s" % target)
		return
	file.store_string("\n\n".join(parts) + "\n")
	file.close()
	last_dir = target.get_base_dir()
	message.emit("Exported %d game%s to %s" % [parts.size(), "" if parts.size() == 1 else "s", target.get_file()])


func _on_delete_pressed() -> void:
	pending_delete = _selected_ids()
	if pending_delete.is_empty():
		return
	if confirm.has_meta("source"):
		confirm.remove_meta("source")
	confirm.title = "Delete games"
	confirm.dialog_text = "Delete %s from the library? This cannot be undone." % ("this game" if pending_delete.size() == 1 else "these %d games" % pending_delete.size())
	confirm.popup_centered()


func _do_delete() -> void:
	var store := _store()
	if store == null:
		return
	if confirm.has_meta("source"):
		var id := int(confirm.get_meta("source"))
		confirm.remove_meta("source")
		var entry := store.source(id)
		store.remove_source(id)
		message.emit("Removed %s" % entry.get("name", "the collection"))
		sources_changed.emit()
		_reload_sources(0)
		_reload_games(0)
		return
	var removed := store.delete_games(pending_delete)
	games_deleted.emit(pending_delete.duplicate())
	pending_delete = []
	message.emit("Deleted %d game%s" % [removed, "" if removed == 1 else "s"])
	sources_changed.emit()
	_reload_sources()
	_reload_games(page)


# --- importing ----------------------------------------------------------------

func _on_import_pressed() -> void:
	import_dialog.current_dir = last_dir if last_dir != "" else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	import_dialog.popup_centered(Vector2i(960, 640))


# Adds PGN files (or zips of them) to the library, one after the other.
func import_files(paths: PackedStringArray) -> void:
	for path in paths:
		var extension := path.get_extension().to_lower()
		if extension not in ["pgn", "zip", "txt"]:
			message.emit("%s is not a PGN or zip file." % path.get_file())
			continue
		last_dir = path.get_base_dir()
		import_queue.append({"path": path, "name": path.get_file().get_basename(), "delete_after": false})
	_next_import()


func _next_import() -> void:
	if importer.running or import_queue.is_empty():
		return
	current_job = import_queue.pop_front()
	if not importer.start(str(current_job["path"]), str(current_job["name"]), _store_path()):
		message.emit("An import is already running.")
		return
	progress_box.visible = true
	progress_cancel.disabled = false
	set_process(true)


func _store_path() -> String:
	return _store().path


func _on_import_finished(result: Dictionary) -> void:
	var job := current_job
	current_job = {}
	if bool(job.get("delete_after", false)) and FileAccess.file_exists(str(job["path"])):
		DirAccess.remove_absolute(str(job["path"]))
	var name := str(result.get("source", ""))
	if not bool(result["ok"]):
		message.emit("Import failed: %s" % result["error"])
	elif bool(result["cancelled"]):
		message.emit("Import cancelled. %s games were kept." % _thousands(int(result["added"])))
	elif int(result["added"]) == 0:
		message.emit("%s: no new games (%s already in the library)." % [name, _thousands(int(result["read"]) - int(result["skipped"]))])
	else:
		var text := "Added %s games to %s" % [_thousands(int(result["added"])), name]
		if int(result["skipped"]) > 0:
			text += " (%s skipped: other chess variants)" % _thousands(int(result["skipped"]))
		message.emit(text)
	if bool(result["cancelled"]):
		import_queue.clear()
	progress_box.visible = is_busy()
	sources_changed.emit()
	if bool(result["ok"]):
		imported.emit(name, int(result["added"]))
	if visible:
		_reload_sources(int(result.get("source_id", 0)) if int(result.get("added", 0)) > 0 else -1)
		_reload_games(0)
	_next_import()
	if not is_busy() and not visible:
		set_process(false)


func _cancel_work() -> void:
	import_queue.clear()
	progress_cancel.disabled = true
	if downloader.busy:
		downloader.cancel()
	if importer.running:
		importer.cancel()


# --- downloading --------------------------------------------------------------

func _show_download() -> void:
	if is_busy():
		message.emit("Wait for the current import to finish first.")
		return
	download_box.visible = true


func _start_download() -> void:
	download_box.visible = false
	var month := month_opt.get_item_text(month_opt.selected)
	var target := DatabaseDownloader.download_dir().path_join("lichess_elite_%s.zip" % month)
	download_job = {"path": target, "name": "Lichess Elite %s" % month, "month": month}
	progress_box.visible = true
	progress_cancel.disabled = false
	progress_label.text = "Downloading Lichess Elite %s…" % month
	progress_bar.value = 0.0
	progress_bar.indeterminate = true
	set_process(true)
	downloader.start(DatabaseDownloader.url_for(month), target)


func _on_download_progress(received: int, total_bytes: int) -> void:
	if total_bytes > 0:
		progress_bar.indeterminate = false
		progress_bar.value = float(received) / float(total_bytes)
		progress_label.text = "Downloading %s  ·  %d of %d MB" % [download_job.get("name", ""), received / 1048576, total_bytes / 1048576]
	else:
		progress_bar.indeterminate = true
		progress_label.text = "Downloading %s  ·  %d MB" % [download_job.get("name", ""), received / 1048576]


func _on_download_finished(path: String, error: String) -> void:
	progress_bar.indeterminate = false
	if error != "":
		message.emit(error)
		progress_box.visible = is_busy()
		download_job = {}
		return
	import_queue.append({"path": path, "name": str(download_job.get("name", "Lichess Elite")), "delete_after": true})
	download_job = {}
	_next_import()


func _process(_delta: float) -> void:
	if importer != null and importer.running:
		var counted := importer.counters()
		progress_bar.indeterminate = false
		progress_bar.value = importer.progress()
		var name := str(current_job.get("name", importer.source_name))
		if str(counted["stage"]) == "Unpacking":
			progress_label.text = "Unpacking %s…" % name
			progress_bar.indeterminate = true
		else:
			progress_label.text = "Adding %s  ·  %s games" % [name, _thousands(int(counted["read"]))]
	elif not is_busy() and not visible:
		set_process(false)
