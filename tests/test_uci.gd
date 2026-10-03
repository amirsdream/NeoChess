extends "res://tests/test_base.gd"

const Fish = preload("res://scripts/stockfish_uci.gd")

const START := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"


func run() -> void:
	_commands()
	_parsing()
	_missing_engine()


func _commands() -> void:
	var fixed: String = Fish._commands(START, {"clock": false, "skill": 20, "movetime": 300})
	expect("starts with uci", fixed.begins_with("uci\n"), true)
	expect("ends with newline", fixed.ends_with("\n"), true)
	expect("position line", fixed.contains("position fen " + START), true)
	expect("fixed go", fixed.contains("go movetime 300"), true)
	expect("skill level", fixed.contains("setoption name Skill Level value 20"), true)
	expect("strength unlimited", fixed.contains("UCI_LimitStrength value false"), true)
	expect("isready before position", fixed.find("isready") < fixed.find("position fen"), true)
	expect("go is last", fixed.rfind("go ") > fixed.find("position fen"), true)

	var clock: String = Fish._commands(START, {"clock": true, "wtime": 180000, "btime": 120000, "inc": 2000})
	expect("clock go", clock.contains("go wtime 180000 btime 120000 winc 2000 binc 2000"), true)
	expect("clock has no movetime", clock.contains("go movetime"), false)

	var elo: String = Fish._commands(START, {"limit_elo": true, "elo": 1800})
	expect("elo limit on", elo.contains("UCI_LimitStrength value true"), true)
	expect("elo value", elo.contains("UCI_Elo value 1800"), true)
	expect("elo mode skips skill level", elo.contains("Skill Level"), false)

	var low: String = Fish._commands(START, {"limit_elo": true, "elo": 100})
	expect("elo clamps low", low.contains("UCI_Elo value 1320"), true)
	var high: String = Fish._commands(START, {"limit_elo": true, "elo": 9000})
	expect("elo clamps high", high.contains("UCI_Elo value 3190"), true)

	var wild: String = Fish._commands(START, {"skill": 99, "threads": 99, "hash": 100000, "overhead": 99999, "multipv": 99, "movetime": 1})
	expect("skill clamps", wild.contains("Skill Level value 20"), true)
	expect("threads clamp", wild.contains("Threads value 16"), true)
	expect("hash clamp", wild.contains("Hash value 1024"), true)
	expect("overhead clamp", wild.contains("Move Overhead value 5000"), true)
	expect("multipv clamp", wild.contains("MultiPV value 5"), true)
	expect("movetime floor", wild.contains("go movetime 50"), true)

	var defaults: String = Fish._commands(START, {})
	expect("default multipv", defaults.contains("MultiPV value 1"), true)
	expect("default threads", defaults.contains("Threads value 1"), true)
	expect("default movetime", defaults.contains("go movetime 400"), true)

	var multi: String = Fish._commands(START, {"multipv": 5})
	expect("multipv option", multi.contains("setoption name MultiPV value 5"), true)


func _parsing() -> void:
	var sample := "info depth 12 multipv 1 score cp 35 nodes 1000 pv e2e4 e7e5 g1f3\n" \
		+ "info depth 12 multipv 2 score mate -3 pv d2d4\n" \
		+ "info string NNUE evaluation using nn.nnue\n" \
		+ "bestmove e2e4 ponder e7e5\n"
	var lines: Array = Fish.principal_lines(sample, 5)
	expect("two lines", lines.size(), 2)
	expect("line number", int(lines[0]["n"]), 1)
	expect("first move", str(lines[0]["pv"][0]), "e2e4")
	expect("pv length", (lines[0]["pv"] as PackedStringArray).size(), 3)
	expect("cp", int(lines[0]["cp"]), 35)
	expect("cp is not mate", bool(lines[0]["has_mate"]), false)
	expect("depth", int(lines[0]["depth"]), 12)
	expect("mate score", int(lines[1]["mate"]), -3)
	expect("mate flag", bool(lines[1]["has_mate"]), true)

	var latest := "info depth 5 multipv 1 score cp 10 pv e2e4\ninfo depth 9 multipv 1 score cp 44 pv d2d4 d7d5\n"
	var newest: Array = Fish.principal_lines(latest, 5)
	expect("keeps the newest line", int(newest[0]["depth"]), 9)
	expect("newest score", int(newest[0]["cp"]), 44)

	var limited: Array = Fish.principal_lines(sample, 1)
	expect("limit drops extra lines", limited.size(), 1)

	var gap := "info depth 8 multipv 3 score cp -20 pv c2c4\n"
	var sparse: Array = Fish.principal_lines(gap, 5)
	expect("sparse result", sparse.size(), 1)
	expect("sparse keeps number", int(sparse[0]["n"]), 3)

	expect("empty input", Fish.principal_lines("", 5).size(), 0)
	expect("no pv", Fish.principal_lines("info depth 3 score cp 1\n", 5).size(), 0)
	expect("promotion moves parse", str(Fish.principal_lines("info depth 3 multipv 1 score cp 1 pv e7e8q\n", 5)[0]["pv"][0]), "e7e8q")
	expect("windows line endings", Fish.principal_lines("info depth 3 multipv 1 score cp 7 pv a2a3\r\n", 5).size(), 1)
	expect("max depth", Fish._max_depth("info depth 3 pv a\ninfo depth 17 pv b\ninfo depth 9 pv c\n"), 17)
	expect("max depth empty", Fish._max_depth(""), 0)


func _missing_engine() -> void:
	expect("empty path", Fish.best_move("", START, {}), "")
	expect("empty path message", Fish.last_log, "Engine file not found.")
	expect("missing file", Fish.best_move("C:/definitely/not/here/stockfish.exe", START, {}), "")
	expect("missing file depth", Fish.last_depth, 0)
	expect("log paths", Fish.stream_log_path(), Fish.output_log_path() + ".stream")
