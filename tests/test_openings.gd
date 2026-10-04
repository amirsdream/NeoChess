extends "res://tests/test_base.gd"

# Opening names (OpeningNames), their display in the app, and the arrows for
# Stockfish's three best moves. Run with "-- --no-engine".

var main: Control


func run() -> void:
	_data()
	_names()
	await _in_the_app()
	await _best_move_arrows()


func _play(sans_text: String) -> Array:
	var game := ChessGame.new()
	var moves: Array = []
	for token in sans_text.split(" ", false):
		var move: Dictionary = Pgn.find_move(game, token).get("move", {})
		if move.is_empty():
			expect_true("test line is legal: %s" % token, false)
			break
		moves.append(move)
		game.make_move(move)
	return moves


func _data() -> void:
	expect_true("thousands of named openings", OpeningNames.count() > 3000, "(%d)" % OpeningNames.count())
	expect_true("long lines are covered", OpeningNames.longest_line() >= 30, "(%d)" % OpeningNames.longest_line())


func _names() -> void:
	var ruy := OpeningNames.find_line(_play("e4 e5 Nf3 Nc6 Bb5 a6"))
	expect_true("Ruy Lopez is recognised", str(ruy.get("name", "")).begins_with("Ruy Lopez"), "(%s)" % str(ruy))
	expect_true("with a C ECO code", str(ruy.get("eco", "")).begins_with("C"))
	expect("reached at the last move", int(ruy.get("at", 0)), 6)
	expect_true("the label has code and name", OpeningNames.label(ruy).contains(str(ruy["eco"])) and OpeningNames.label(ruy).contains(str(ruy["name"])))

	var sicilian := OpeningNames.find_line(_play("e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6"))
	expect_true("Najdorf is recognised", str(sicilian.get("name", "")).contains("Najdorf"), "(%s)" % str(sicilian))

	# The same position by two move orders has the same name.
	var one := OpeningNames.find_line(_play("e4 e5 Nf3 Nc6"))
	var two := OpeningNames.find_line(_play("Nf3 Nc6 e4 e5"))
	expect_true("a transposition is named", not one.is_empty())
	expect("by position, not move order", str(two.get("name", "")), str(one.get("name", "x")))

	# Leaving the known lines keeps the last name and says where it was left.
	var gone := OpeningNames.find_line(_play("e4 e5 Nf3 Nc6 Bb5 a6 Ba4 Nf6 O-O Be7 Re1 b5 Bb3 d6 c3 O-O h3 Bb7 d4 Re8 Nbd2 Bf8 a4 h6 Bc2 exd4 cxd4 Nb4 Bb1 c5 d5 Nd7"))
	expect_true("a deep line still has a name", not gone.is_empty())
	expect_true("and says it was left earlier", int(gone.get("at", 99)) < 32, "(at %s)" % str(gone.get("at")))

	expect("no moves, no opening", OpeningNames.find_line([]).size(), 0)

	var game := ChessGame.new()
	for move in _play("e4 e5 Nf3 Nc6"):
		game.make_move(move)
	var after := OpeningNames.find_after(game, "Bb5")
	expect_true("the move Bb5 leads to the Ruy Lopez", str(after.get("name", "")).begins_with("Ruy Lopez"), "(%s)" % str(after))
	expect("the game is not changed", game.to_fen(), "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3")
	expect("an illegal move names nothing", OpeningNames.find_after(game, "Ke5").is_empty(), true)


func _start_main() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	main = scene.instantiate() as Control
	root.add_child(main)


func _in_the_app() -> void:
	_start_main()
	await process_frame
	await process_frame
	main.mode_opt.selected = 1
	main._refresh()
	expect("the start has no opening yet", main.opening_label.text, "Starting position")
	for pair in [[12, 28], [52, 36], [6, 21], [57, 42], [5, 33]]:
		main._on_square(int(pair[0]))
		main._on_square(int(pair[1]))
		var waited := 0
		while main.animating and waited < 200:
			await process_frame
			waited += 1
	expect("five plies played", main.played.size(), 5)
	expect_true("the opening is named", main.opening_label.text.contains("Ruy Lopez"), "(%s)" % main.opening_label.text)
	expect_true("the line is shown", main.opening_note.text.contains("Bb5"), "(%s)" % main.opening_note.text)

	main._goto_ply(2)
	expect_true("reviewing an earlier move names that position", main.opening_label.text.contains("King's Pawn"), "(%s)" % main.opening_label.text)
	main._goto_ply(0)
	expect("the start again", main.opening_label.text, "Starting position")
	main._nav_last()

	var info: Dictionary = main._game_info()
	expect_true("saved games carry the opening", str(info.get("Opening", "")).contains("Ruy Lopez") and str(info.get("ECO", "")).begins_with("C"), "(%s)" % str(info))
	main._on_new_game()
	expect("a new game clears the name", main.opening_label.text, "Starting position")
	main.queue_free()
	await process_frame


func _entry(n: int, uci: String, cp: int) -> Dictionary:
	return {"n": n, "pv": PackedStringArray([uci]), "has_mate": false, "mate": 0, "cp": cp, "depth": 12}


func _best_move_arrows() -> void:
	_start_main()
	await process_frame
	await process_frame
	main._refresh()
	var view: BoardView = main.board_view
	expect_true("no arrows without analysis", view.analysis_arrows.is_empty())

	main._apply_branch(_entry(2, "d2d4", 20))
	main._apply_branch(_entry(1, "e2e4", 30))
	main._apply_branch(_entry(3, "g1f3", 10))
	main._apply_branch(_entry(4, "c2c4", 5))
	expect("the best move is the first arrow", [view.analysis_arrows[0]["from"], view.analysis_arrows[0]["to"]], [12, 28])
	expect("the second move is the second arrow", [view.analysis_arrows[1]["from"], view.analysis_arrows[1]["to"]], [11, 27])
	expect("the third move is the third arrow", [view.analysis_arrows[2]["from"], view.analysis_arrows[2]["to"]], [6, 21])
	expect("only three arrows", view.analysis_arrows.size(), 3)

	var widths: Array = []
	for style in BoardView.ANALYSIS_ARROWS:
		widths.append(float((style as Array)[1]))
	expect_true("the best arrow is the thickest, the third the thinnest", widths[0] > widths[1] and widths[1] > widths[2], "(%s)" % str(widths))
	var alphas: Array = []
	for style in BoardView.ANALYSIS_ARROWS:
		alphas.append(((style as Array)[0] as Color).a)
	expect_true("and the best is the most opaque", alphas[0] > alphas[1] and alphas[1] > alphas[2])

	main.show_best_check.button_pressed = false
	expect("arrows can be switched off", view.show_analysis_arrows, false)
	main.show_best_check.button_pressed = true
	expect("and on", view.show_analysis_arrows, true)

	main._clear_branches()
	expect("arrows go when the lines clear", [view.analysis_arrows[0]["from"], view.analysis_arrows[1]["from"], view.analysis_arrows[2]["from"]], [-1, -1, -1])
	main.queue_free()
	await process_frame
