extends "res://tests/test_base.gd"

# Plays real positions through Stockfish. Skipped when no engine is installed,
# so the rest of the suite still runs on a fresh checkout.

const Rules = preload("res://scripts/chess_game.gd")
const Fish = preload("res://scripts/stockfish_uci.gd")


func run() -> void:
	var path := EngineSetup.first_existing(EngineSetup.candidates(
		OS.get_executable_path().get_base_dir(),
		ProjectSettings.globalize_path("res://bin"),
	))
	if path.is_empty():
		skip("engine tests (no Stockfish found; run dev/fetch_stockfish.ps1)")
		return
	_opening(path)
	_forced_mate(path)
	_multipv(path)
	_strength_options(path)


func _opening(path: String) -> void:
	var game := Rules.new()
	var uci := Fish.best_move(path, game.to_fen(), {"skill": 20, "movetime": 300, "threads": 1, "hash": 16})
	expect_true("opening move is legal", not game.match_uci(uci).is_empty(), "(got '%s')" % uci)
	expect_true("search reached some depth", Fish.last_depth >= 6, "(depth %d)" % Fish.last_depth)


func _forced_mate(path: String) -> void:
	var game = Rules.setup("6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
	var uci := Fish.best_move(path, game.to_fen(), {"skill": 20, "movetime": 300, "threads": 1, "hash": 16})
	expect("finds back rank mate", uci, "a1a8")
	var black = Rules.setup("7k/8/8/8/8/5q2/8/6K1 b - - 0 1")
	var reply := Fish.best_move(path, black.to_fen(), {"skill": 20, "movetime": 300, "threads": 1, "hash": 16})
	expect_true("black finds a legal move", not black.match_uci(reply).is_empty(), "(got '%s')" % reply)


func _multipv(path: String) -> void:
	var game := Rules.new()
	Fish.best_move(path, game.to_fen(), {"skill": 20, "movetime": 400, "multipv": 5, "threads": 1, "hash": 16})
	var lines: Array = Fish.principal_lines(Fish.last_log, 5)
	expect("five lines reported", lines.size(), 5)
	for entry in lines:
		var first := str((entry["pv"] as PackedStringArray)[0])
		expect_true("line %d starts with a legal move" % int(entry["n"]), not game.match_uci(first).is_empty(), "(%s)" % first)
	var moves := {}
	for entry in lines:
		moves[str((entry["pv"] as PackedStringArray)[0])] = true
	expect("lines start with different moves", moves.size(), 5)


func _strength_options(path: String) -> void:
	var game := Rules.new()
	var capped := Fish.best_move(path, game.to_fen(), {"limit_elo": true, "elo": 1400, "movetime": 200, "threads": 1, "hash": 16})
	expect_true("elo capped search answers", not game.match_uci(capped).is_empty(), "(got '%s')" % capped)
	var clocked := Fish.best_move(path, game.to_fen(), {"clock": true, "wtime": 4000, "btime": 4000, "inc": 0, "threads": 1, "hash": 16})
	expect_true("clock search answers", not game.match_uci(clocked).is_empty(), "(got '%s')" % clocked)
