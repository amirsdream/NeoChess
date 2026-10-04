extends "res://tests/test_base.gd"

# The game library inside the real main scene: games are saved when they end
# or are replaced, the library window lists, opens and deletes them, imports run
# in the background, and the opening book follows the moves on the board.
# Everything happens in a temporary database, never in your own library.

var main: Control
var work := ""
var db := ""


func run() -> void:
	work = OS.get_user_data_dir().path_join("test_library_app")
	DirAccess.make_dir_recursive_absolute(work)
	db = work.path_join("library.db")
	_clean()
	var scene := load("res://scenes/main.tscn") as PackedScene
	main = scene.instantiate() as Control
	main.library_path = db
	root.add_child(main)
	await process_frame
	await process_frame
	main.archive_enabled = true
	main.mode_opt.selected = 1
	main._refresh()

	await _saving_games()
	await _library_window()
	await _importing()
	await _opening_book()
	await _cancelling()
	await _damaged_game()

	main.queue_free()
	await process_frame
	_clean()


func _clean() -> void:
	var dir := DirAccess.open(work)
	if dir == null:
		return
	for file in dir.get_files():
		DirAccess.remove_absolute(work.path_join(file))


func _until(condition: Callable, frames: int = 600) -> bool:
	var waited := 0
	while not condition.call() and waited < frames:
		await process_frame
		waited += 1
	return condition.call()


func _play(pairs: Array) -> void:
	for pair in pairs:
		main._on_square(int((pair as Array)[0]))
		main._on_square(int((pair as Array)[1]))
		await _until(func() -> bool: return not main.animating, 200)


func _searched(view: LibraryView) -> void:
	await process_frame
	await _until(func() -> bool: return not view.is_searching(), 600)


func _store() -> GameStore:
	return main._store()


func _saving_games() -> void:
	expect("the library starts empty", _store().count({}), 0)
	await _play([[12, 28], [52, 36], [6, 21]])
	expect("a running game is not saved yet", _store().count({}), 0)
	main._on_new_game()
	expect("starting over saves the unfinished game", _store().count({}), 1)
	var saved: Dictionary = _store().search({}, 5)[0]
	expect("saved moves", int(saved["plies"]), 3)
	expect("saved as unfinished", str(saved["result"]), "*")
	expect("saved under My games", int(saved["source_id"]), _store().mine_source())

	await _play([[12, 28]])
	main._on_new_game()
	expect("a single move is not worth saving", _store().count({}), 1)

	# Fool's mate: f3 e5 g4 Qh4#
	await _play([[13, 21], [52, 36], [14, 30], [59, 31]])
	expect("the game is over", main.state, "checkmate")
	expect("a finished game is saved at once", _store().count({}), 2)
	var mate: Dictionary = _store().search({"result": "0-1"}, 5)[0]
	expect("result recorded", str(mate["result"]), "0-1")
	expect("players recorded", str(mate["white"]), "Player 1")
	expect("opening line stored", _store().game(int(mate["id"]))["sans"], PackedStringArray(["f3", "e5", "g4", "Qh4#"]))
	main._refresh()
	main._on_new_game()
	expect("starting over does not save it twice", _store().count({}), 2)

	main._import_text("[White \"Ann\"]\n[Black \"Bob\"]\n\n1. e4 e5 2. Nf3 Nc6 1-0\n", "Test")
	main._on_new_game()
	expect("imported games are not saved as yours", _store().count({}), 2)
	expect("My games counts them", int(_store().source(_store().mine_source())["games"]), 2)


func _library_window() -> void:
	var view: LibraryView = main.library_view
	main._open_library()
	await _searched(view)
	expect("the window opens", view.visible, true)
	expect("both games are listed", view.tree.get_root().get_child_count(), 2)
	expect("the total is shown", view.total, 2)
	expect_true("collections are listed", view.source_list.item_count >= 2)
	view.result_opt.select(3)
	view._reload_games(0)
	await _searched(view)
	expect("filtering by result", view.tree.get_root().get_child_count(), 1)
	view.result_opt.select(0)
	view.search_edit.text = "nobody"
	view._reload_games(0)
	await _searched(view)
	expect("a search without matches", view.total, 0)
	expect("the list explains itself", view.empty_label.visible, true)
	view._clear_filters()
	await _searched(view)
	expect("clearing the filters brings the games back", view.total, 2)

	# Review the mate.
	view.result_opt.select(3)
	view._reload_games(0)
	await _searched(view)
	view.tree.get_root().get_child(0).select(0)
	view._update_buttons()
	expect("one game selected enables review", view.open_btn.disabled, false)
	view._open_selected()
	await _until(func() -> bool: return main.view_ply == 0, 60)
	expect("the window closes", view.visible, false)
	expect("the game is loaded", ",".join(main.sans), "f3,e5,g4,Qh4#")
	expect("it opens in review at the first position", main.view_ply, 0)
	expect("the board is not turned around", main.board_flipped, false)
	main._nav_next()
	expect("the arrow keys step through it", main.view_ply, 1)
	main._on_new_game()
	expect("reviewing and leaving does not save a copy", _store().count({}), 2)

	# Delete one game.
	main._open_library()
	await _searched(view)
	var ids: Array = [int(_store().search({"result": "*"}, 5)[0]["id"])]
	view.pending_delete = ids
	view._do_delete()
	await _searched(view)
	expect("deleting removes the game", _store().count({}), 1)
	expect("the list is reloaded", view.total, 1)
	view.hide_library()
	expect("the window closes again", view.visible, false)


func _sample_games(count: int) -> String:
	var text := ""
	var lines := [
		"1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0",
		"1. e4 c5 2. Nf3 d6 3. d4 cxd4 0-1",
		"1. d4 d5 2. c4 e6 3. Nc3 Nf6 1/2-1/2",
		"1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 1-0",
	]
	for i in count:
		text += "[Event \"Test %d\"]\n[Site \"?\"]\n[Date \"2024.01.%02d\"]\n[White \"Player%d\"]\n[Black \"Rival%d\"]\n[WhiteElo \"%d\"]\n[Result \"%s\"]\n\n%s\n\n" % [
			i, 1 + i % 28, i, i, 2000 + i % 500, str(lines[i % 4]).split(" ")[-1], lines[i % 4]]
	return text


func _write(file_name: String, text: String) -> String:
	var path := work.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func _importing() -> void:
	var view: LibraryView = main.library_view
	var before: int = _store().count({})
	main.book_check.set_pressed_no_signal(false)
	var path := _write("club.pgn", _sample_games(40))
	view.import_files(PackedStringArray([path]))
	expect("the import starts in the background", view.is_busy(), true)
	await _until(func() -> bool: return not view.is_busy(), 1200)
	expect("every game was added", _store().count({}), before + 40)
	var club: Dictionary = {}
	for entry in _store().sources():
		if str((entry as Dictionary)["name"]) == "club":
			club = entry
	expect("a collection named after the file", int(club.get("games", 0)), 40)
	expect("the opening book switches on after an import", main.book_check.button_pressed, true)

	await _until(func() -> bool: return not view.is_busy(), 10)
	view.import_files(PackedStringArray([path]))
	await _until(func() -> bool: return not view.is_busy(), 1200)
	expect("importing the same file again adds nothing", _store().count({}), before + 40)

	# A zip holding two PGN files.
	var zip_path := work.path_join("pack.zip")
	var packer := ZIPPacker.new()
	expect("zip created", packer.open(zip_path), OK)
	packer.start_file("one.pgn")
	packer.write_file(_sample_games(10).to_utf8_buffer())
	packer.close_file()
	packer.start_file("readme.txt")
	packer.write_file("not chess".to_utf8_buffer())
	packer.close_file()
	packer.start_file("two.pgn")
	packer.write_file(_sample_games(5).replace("Player", "Zip").to_utf8_buffer())
	packer.close_file()
	packer.close()
	view.import_files(PackedStringArray([zip_path]))
	await _until(func() -> bool: return not view.is_busy(), 1200)
	expect("games from every pgn in the zip", _store().count({"text": "Zip"}) + _store().count({"text": "Player"}) > 0, true)
	var pack: Dictionary = {}
	for entry in _store().sources():
		if str((entry as Dictionary)["name"]) == "pack":
			pack = entry
	expect("zip import: the games of both files are added once", int(pack.get("games", 0)), 15)
	expect("the temporary files are removed", FileAccess.file_exists(OS.get_user_data_dir().path_join("import_0.pgn")), false)

	var broken := _write("broken.zip", "this is not a zip file")
	var seen: Array = []
	view.message.connect(func(text: String) -> void: seen.append(text))
	view.import_files(PackedStringArray([broken]))
	await _until(func() -> bool: return not view.is_busy(), 600)
	expect_true("a broken zip is reported", not seen.is_empty() and str(seen[-1]).begins_with("Import failed"), str(seen))
	var odd := _write("notes.docx", "x")
	view.import_files(PackedStringArray([odd]))
	expect("other file types are refused", view.is_busy(), false)

	var zst := _write("games.pgn.zst", "x")
	view.import_files(PackedStringArray([zst]))
	await _until(func() -> bool: return not view.is_busy(), 600)
	expect_true("zst is explained", str(seen[-1]).contains("zst") or str(seen[-1]).contains("not a PGN"), str(seen))


func _opening_book() -> void:
	var view: LibraryView = main.library_view
	for entry in _store().sources():
		var source: Dictionary = entry
		if str(source["name"]) != "club":
			_store().remove_source(int(source["id"]))
	main._on_sources_changed()
	main._on_new_game()
	main.book_check.set_pressed_no_signal(true)
	main.book_key = ""
	main._refresh()
	expect("the book card is visible", main.book_card.visible, true)
	await _until(func() -> bool: return not main.book_rows.is_empty() and int((main.book_rows[0] as Dictionary)["games"]) == 30, 300)
	var first: Dictionary = main.book_rows[0]
	expect("the most played first move leads", str(first["move"]), "e4")
	expect("with its game count", int(first["games"]), 30)
	expect("and its results", int(first["white"]) + int(first["draw"]) + int(first["black"]), 30)
	expect("second choice", str((main.book_rows[1] as Dictionary)["move"]), "d4")
	expect("rows are shown", (main.book_bars[0]["row"] as Button).visible, true)
	expect("unused rows are hidden", (main.book_bars[2]["row"] as Button).visible, false)

	main._on_book_row(0)
	await _until(func() -> bool: return not main.animating, 200)
	expect("clicking a book move plays it", ",".join(main.sans), "e4")
	await _until(func() -> bool: return main.book_rows.size() > 0 and str((main.book_rows[0] as Dictionary)["move"]) == "e5", 300)
	expect("the book follows the game", str((main.book_rows[0] as Dictionary)["move"]), "e5")
	expect("replies counted", int((main.book_rows[0] as Dictionary)["games"]), 20)

	main._goto_ply(0)
	await _until(func() -> bool: return main.book_rows.size() > 0 and str((main.book_rows[0] as Dictionary)["move"]) == "e4", 300)
	expect("the book also follows a review", str((main.book_rows[0] as Dictionary)["move"]), "e4")
	main._on_book_row(0)
	expect("book moves cannot be played while reviewing", main.sans.size(), 1)
	main._leave_review()

	main._import_text("[SetUp \"1\"]\n[FEN \"4k3/8/8/8/8/8/4P3/4K3 b - - 3 41\"]\n\n41... Kd7 42. Kd2 Ke6 *\n", "Test")
	main._refresh()
	expect_true("games from a set-up position have no book", main.book_hint.text.contains("standard"), main.book_hint.text)
	main._on_new_game()

	var deep := PackedStringArray()
	for i in 12:
		deep.append("Nf3" if i % 2 == 0 else "Nf6")
	expect("lines past the book depth are not looked up", _store().explorer(deep, []).size(), 0)

	main.book_source_opt.select(1)
	main._on_book_source(1)
	expect("a collection can be chosen", main.book_source_name, "club")
	expect("and it restricts the question", main._book_sources().size(), 1)
	main.book_check.set_pressed_no_signal(false)
	main._refresh()
	expect("switching the book off hides it", main.book_card.visible, false)
	view.hide_library()


func _cancelling() -> void:
	var view: LibraryView = main.library_view
	var path := _write("big.pgn", _sample_games(6000))
	var before: int = _store().count({})
	view.import_files(PackedStringArray([path]))
	view._cancel_work()
	await _until(func() -> bool: return not view.is_busy(), 1200)
	expect("a cancelled import stops", view.importer.running, false)
	expect_true("and keeps no more than the file holds", _store().count({}) <= before + 6000)
	view.import_files(PackedStringArray([path]))
	await _until(func() -> bool: return not view.is_busy(), 2400)
	expect("the import works again afterwards", _store().count({}), before + 6000)

	# A missing database folder, a deleted collection while the book is on.
	main.library_view.hide_library()


func _damaged_game() -> void:
	main._on_new_game()
	await _play([[12, 28], [52, 36]])
	var store := _store()
	var bad := GameStore.record({"White": "X", "Black": "Y", "Date": "2020.01.01"}, PackedStringArray(["e4", "Event:", "e5"]), "1-0")
	var id := store.add_game(store.mine_source(), bad)
	expect_true("the damaged game is in the library", id > 0)
	main._open_library_game(store.game(id), true)
	await process_frame
	expect("opening a damaged game leaves the board alone", ",".join(main.sans), "e4,e5")
	expect("and does not start a review", main.view_ply, -1)
	var illegal := GameStore.record({"White": "X", "Black": "Z", "Date": "2020.01.02"}, PackedStringArray(["e4", "e4"]), "1-0")
	main._open_library_game(store.game(store.add_game(store.mine_source(), illegal)), true)
	await process_frame
	expect("an illegal move is refused the same way", ",".join(main.sans), "e4,e5")