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
	main.color_opt.selected = 0
	main.game.reset()
	expect("white to move, white player", main._score_sign(), 1)
	main.color_opt.selected = 1
	expect("white to move, black player", main._score_sign(), -1)
	main.game.make_move(main.game.match_uci("e2e4"))
	expect("black to move, black player", main._score_sign(), 1)
	main.color_opt.selected = 0
	expect("black to move, white player", main._score_sign(), -1)
	main.mode_opt.selected = 1
	main.color_opt.selected = 1
	expect("pass and play uses White's view", main._score_sign(), -1)
	main.game.reset()
	expect("pass and play white to move", main._score_sign(), 1)
