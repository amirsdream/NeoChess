extends "res://tests/test_base.gd"

# Loads the real main scene and plays through it in pass and play. Run with
# "-- --no-engine" so no Stockfish process is started (run_tests.ps1 does).
# It never calls the code paths that save settings, so your own are untouched.

var main: Control


func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	expect_true("scene loads", scene != null)
	main = scene.instantiate() as Control
	root.add_child(main)
	await process_frame
	await process_frame
	_structure()
	await _play_moves()
	_undo_and_new_game()
	_game_import_export()
	await _history_review()
	_palette_follows_board()
	_setup_card()
	_scores_follow_the_player()
	main.queue_free()
	await process_frame


func _structure() -> void:
	expect_true("board view exists", main.board_view != null)
	expect_true("status label exists", main.status_label != null)
	expect("five branch cards", main.branch_cards.size(), 5)
	expect("three settings pages", main.settings_pages.size(), 3)
	expect("board chips", main.board_chips.size(), Appearance.board_count())
	expect("piece chips", main.piece_chips.size(), Appearance.piece_count())
	expect("starts on move one", main.played.size(), 0)
	expect("twenty legal moves", main.legal.size(), 20)
	expect("settings start closed", main.settings_open, false)
	main.mode_opt.selected = 1
	main._refresh()
	expect_true("pass and play status", main.status_label.text.contains("White"))


func _play_moves() -> void:
	for pair in [[12, 28], [52, 36], [6, 21]]:
		main._on_square(int(pair[0]))
		expect("selected %d" % int(pair[0]), main.selected, int(pair[0]))
		main._on_square(int(pair[1]))
		var waited := 0
		while main.animating and waited < 200:
			await process_frame
			waited += 1
		expect("animation finished", main.animating, false)
	expect("three plies played", main.played.size(), 3)
	expect("san list", ",".join(main.sans), "e4,e5,Nf3")
	expect("fen after moves", main.game.to_fen(), "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2")
	expect_true("move list shows the last move", main.moves_label.text.contains("Nf3"))
	main._on_square(0)
	expect("black cannot move white's piece", main.selected, -1)
	main._on_square(12)
	expect("illegal click does nothing", main.played.size(), 3)


func _undo_and_new_game() -> void:
	main._on_undo()
	expect("undo takes one move in pass and play", main.played.size(), 2)
	expect("undo restores the position", main.game.to_fen(), "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2")
	main._on_new_game()
	expect("new game clears moves", main.played.size(), 0)
	expect("new game resets the board", main.game.to_fen(), "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	main._on_flip()
	expect("flip turns the board", main.board_flipped, true)
	main._on_flip()
	expect("flip back", main.board_flipped, false)


func _game_import_export() -> void:
	expect_true("game menu exists", main.menu_btn != null)
	expect("menu entries", main.menu_btn.get_popup().item_count, 8)

	var game_text := "[White \"Ann\"]\n[Black \"Bob\"]\n[Event \"Club\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0\n"
	expect("import succeeds", main._import_text(game_text, "Test"), true)
	expect("imported plies", main.played.size(), 6)
	expect("imported sans", ",".join(main.sans), "e4,e5,Nf3,Nc6,Bb5,a6")
	expect("imported position", main.game.to_fen(), "r1bqkbnr/1ppp1ppp/p1n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4")
	expect_true("move list shows imported moves", main.moves_label.text.contains("Bb5"))
	var exported: String = main._game_pgn()
	expect_true("export keeps the players", exported.contains("[White \"Ann\"]") and exported.contains("[Black \"Bob\"]"))
	expect_true("export keeps other tags", exported.contains("[Event \"Club\"]"))
	expect_true("export keeps the recorded result", exported.contains("[Result \"1-0\"]") and exported.strip_edges().ends_with("1-0"))
	var again := Pgn.parse(exported)
	expect("export parses again", bool(again["ok"]), true)
	expect("export round trips the moves", ",".join(again["sans"]), ",".join(main.sans))

	main._on_square(1)
	expect("play continues after import", main.selected, 1)
	main._on_new_game()
	expect("game tags cleared on new game", main.game_tags.size(), 0)
	expect_true("fresh export has the standard tags", main._game_pgn().contains("[White \"Player 1\"]"))
	expect_true("fresh export ends unfinished", main._game_pgn().strip_edges().ends_with("*"))

	var fen := "4k3/8/8/8/8/8/4P3/4K3 b - - 3 41"
	expect("position import succeeds", main._import_text(fen, "Test"), true)
	expect("position loaded", main.game.to_fen(), fen)
	expect("black moves first", main.game.white_to_move, false)
	expect_true("no moves yet message names black", main.moves_label.text.contains("Black moves first"))
	main.sans.append("Kd7")
	main.played.append(main.game.match_uci("e8d7"))
	main.game.make_move(main.played[0])
	main._refresh()
	expect_true("move list continues the numbering", main.moves_label.text.contains("41."))
	var from_fen: String = main._game_pgn()
	expect_true("export carries the start position", from_fen.contains("[FEN \"" + fen + "\"]") and from_fen.contains("[SetUp \"1\"]"))
	expect_true("export numbers from the start position", from_fen.contains("41... Kd7"))
	main._on_undo()
	expect("undo returns to the start position", main.game.to_fen(), fen)

	expect("garbage is refused", main._import_text("this is not chess", "Test"), false)
	expect("position unchanged after a failed import", main.game.to_fen(), fen)
	expect("bad position is refused", main._import_text("8/8/8/8/8/8/8/8 w - - 0 1", "Test"), false)
	expect("empty clipboard is refused", main._import_text("   ", "Test"), false)
	main._on_new_game()
	expect("new game returns to the standard start", main.game.to_fen(), Pgn.START_FEN)


func _history_review() -> void:
	main.mode_opt.selected = 1
	main._import_text("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *", "Test")
	var live_fen: String = main.game.to_fen()
	expect("starts live", main.view_ply, -1)
	expect("review bar hidden while live", main.review_bar.visible, false)
	expect_true("moves are clickable", main.moves_label.text.contains("[url=3]"))
	expect_true("live row is highlighted", main.moves_label.text.contains("[url=6][bgcolor"))

	main._goto_ply(3)
	expect("reviewing ply 3", main.view_ply, 3)
	expect("review position", main.view_game.to_fen(), "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2")
	expect("live game is untouched", main.game.to_fen(), live_fen)
	expect("board shows the reviewed position", main.board_view.board == main.view_game.board, true)
	expect("last move marked is the reviewed one", main.board_view.last_to, 21)
	expect("review bar visible", main.review_bar.visible, true)
	expect_true("review caption names the move", main.review_label.text.contains("2. Nf3"))
	expect_true("status says reviewing", main.status_label.text.contains("Reviewing"))
	expect_true("highlight moved to the reviewed move", main.moves_label.text.contains("[url=3][bgcolor"))
	expect("lines are shown while reviewing", main.branches_box.visible, true)
	expect("analysis is scheduled", main.analysis_pending, true)
	expect("analysis not started without an engine", main.analysis_running, false)
	expect("undo is disabled while reviewing", main.undo_btn.disabled, true)

	main._on_square(1)
	expect("board is read only while reviewing", main.selected, -1)
	main._on_undo()
	expect("undo does nothing while reviewing", main.played.size(), 6)

	main._nav_prev()
	expect("previous move", main.view_ply, 2)
	main._nav_next()
	expect("next move", main.view_ply, 3)
	main._nav_first()
	expect("first position", main.view_ply, 0)
	expect("start position shown", main.view_game.to_fen(), Pgn.START_FEN)
	expect_true("start caption", main.review_label.text.contains("Start"))
	main._nav_prev()
	expect("cannot go before the start", main.view_ply, 0)
	expect("no last move at the start", main.board_view.last_to, -1)
	main._on_move_clicked("4")
	expect("clicking a move jumps to it", main.view_ply, 4)
	expect("black to move name", main._ply_name(4), "2... Nc6")
	expect("white move name", main._ply_name(5), "3. Bb5")
	expect("start name", main._ply_name(0), "start position")

	main._nav_last()
	expect("back to live", main.view_ply, -1)
	expect("live position unchanged", main.game.to_fen(), live_fen)
	expect("review bar hidden again", main.review_bar.visible, false)
	main._on_move_clicked("6")
	expect("clicking the last move stays live", main.view_ply, -1)

	main._goto_ply(2)
	main._on_new_game()
	expect("new game leaves the review", main.view_ply, -1)
	expect("new game cancels the analysis", main.analysis_pending, false)

	main._import_text("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *", "Test")
	main._goto_ply(2)
	main._play_from_here()
	expect("play from here leaves the review", main.view_ply, -1)
	expect("later moves are dropped", ",".join(main.sans), "e4,e5")
	expect("position is rebuilt", main.game.to_fen(), "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2")
	main._on_square(6)
	expect("play continues from there", main.selected, 6)

	main._import_text("[SetUp \"1\"]\n[FEN \"4k3/8/8/8/8/8/4P3/4K3 b - - 3 41\"]\n\n41... Kd7 42. Kd2 Ke6 *\n", "Test")
	main._goto_ply(1)
	expect("review from a black start", main.view_game.to_fen(), "8/3k4/8/8/8/8/4P3/4K3 w - - 4 42")
	expect("black start name", main._ply_name(1), "41... Kd7")
	expect("white reply name", main._ply_name(2), "42. Kd2")
	main._nav_last()
	main._on_new_game()
	await process_frame


func _palette_follows_board() -> void:
	main._apply_palette(0)
	var walnut_bg: Color = main.C_BG
	main._apply_palette(2)
	expect_true("palette changes with the board", main.C_BG != walnut_bg)
	expect("palette gold is the board trim", main.C_GOLD, Appearance.board(2)["trim"])
	expect("background node recolored", (main.get_child(0) as ColorRect).color, main.C_BG)
	main._apply_palette(2)
	expect("same board is a no-op", main.palette_key, 2)
	for i in Appearance.board_count():
		main._apply_palette(i)
	expect("every palette applies", main.palette_key, Appearance.board_count() - 1)
	main._apply_palette(0)


func _setup_card() -> void:
	main.mode_opt.selected = 0
	main.engine_edit.text = "C:/does/not/exist/stockfish.exe"
	var has_engine: bool = not main._resolved_engine_path().is_empty()
	main._update_setup_card()
	expect("download card matches engine presence", main.setup_card.visible, not has_engine)
	expect("analysis hidden while the card shows", main.lines_box.visible, has_engine)
	main.mode_opt.selected = 1
	main._update_setup_card()
	expect("no card in pass and play", main.setup_card.visible, false)
	main.mode_opt.selected = 0
	main.engine_edit.text = ""


func _scores_follow_the_player() -> void:
	main.mode_opt.selected = 0
	main.human_white = true
	main.game.reset()
	expect("white to move, white player", main._score_sign(), 1)
	main.human_white = false
	expect("white to move, black player", main._score_sign(), -1)
	main.game.make_move(main.game.match_uci("e2e4"))
	expect("black to move, black player", main._score_sign(), 1)
	main.human_white = true
	expect("black to move, white player", main._score_sign(), -1)
	main.mode_opt.selected = 1
	main.human_white = false
	expect("pass and play uses White's view", main._score_sign(), -1)
	main.game.reset()
	expect("pass and play white to move", main._score_sign(), 1)
