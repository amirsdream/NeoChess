extends "res://tests/test_base.gd"

# The UCI helpers are pure functions: no engine and no files are needed.

const Fish = preload("res://scripts/stockfish_uci.gd")


func run() -> void:
	_go_commands()
	_settings()
	_option_commands()
	_info_parsing()
	_principal_lines()
	_option_lines()
	_formatting()


func _go_commands() -> void:
	expect("fixed time", Fish.go_command({"movetime": 300}), "go movetime 300")
	expect("default time", Fish.go_command({}), "go movetime 400")
	expect("time floor", Fish.go_command({"movetime": 1}), "go movetime 50")
	expect("infinite", Fish.go_command({"infinite": true}), "go infinite")
	expect("infinite wins over the clock", Fish.go_command({"infinite": true, "clock": true, "movetime": 5}), "go infinite")
	expect("clock", Fish.go_command({"clock": true, "wtime": 180000, "btime": 120000, "inc": 2000}), "go wtime 180000 btime 120000 winc 2000 binc 2000")
	expect("clock floor", Fish.go_command({"clock": true, "wtime": 0, "btime": 0}), "go wtime 50 btime 50 winc 0 binc 0")
	expect("depth", Fish.go_command({"depth": 18}), "go depth 18")
	expect("clock beats movetime", Fish.go_command({"clock": true, "movetime": 300}).contains("movetime"), false)

	expect("budget for a fixed time", Fish.time_budget_ms({"movetime": 300}), 20300)
	expect("budget for the clock", Fish.time_budget_ms({"clock": true, "wtime": 5000, "btime": 9000}), 29000)
	expect("no budget for analysis", Fish.time_budget_ms({"infinite": true}), 0)
	expect("budget for depth", Fish.time_budget_ms({"depth": 20}) > 0, true)

	var go := Fish.go_from_options({"clock": true, "wtime": 111, "btime": 222, "inc": 3})
	expect("go from clock options", go, {"clock": true, "wtime": 111, "btime": 222, "inc": 3})
	expect("go from fixed options", Fish.go_from_options({"clock": false, "movetime": 750}), {"movetime": 750})


func _settings() -> void:
	var level := Fish.engine_settings({"skill": 12, "threads": 4, "hash": 128, "overhead": 40, "multipv": 3})
	expect("threads", level["Threads"], 4)
	expect("hash", level["Hash"], 128)
	expect("overhead", level["Move Overhead"], 40)
	expect("multipv", level["MultiPV"], 3)
	expect("skill level", level["Skill Level"], 12)
	expect("strength unlimited", level["UCI_LimitStrength"], false)
	expect("no elo when unlimited", level.has("UCI_Elo"), false)

	var elo := Fish.engine_settings({"limit_elo": true, "elo": 1800})
	expect("strength limited", elo["UCI_LimitStrength"], true)
	expect("elo value", elo["UCI_Elo"], 1800)
	expect("no skill when limited", elo.has("Skill Level"), false)
	expect("elo clamps low", Fish.engine_settings({"limit_elo": true, "elo": 100})["UCI_Elo"], 1320)
	expect("elo clamps high", Fish.engine_settings({"limit_elo": true, "elo": 9000})["UCI_Elo"], 3190)

	var wild := Fish.engine_settings({"skill": 99, "threads": 99, "hash": 100000, "overhead": 99999, "multipv": 99})
	expect("skill clamps", wild["Skill Level"], 20)
	expect("threads clamp", wild["Threads"], 16)
	expect("hash clamp", wild["Hash"], 1024)
	expect("overhead clamp", wild["Move Overhead"], 5000)
	expect("multipv clamp", wild["MultiPV"], 5)
	var defaults := Fish.engine_settings({})
	expect("default multipv", defaults["MultiPV"], 1)
	expect("default threads", defaults["Threads"], 1)


func _option_commands() -> void:
	expect("number option", Fish.option_command("Hash", 64), "setoption name Hash value 64")
	expect("bool true", Fish.option_command("UCI_LimitStrength", true), "setoption name UCI_LimitStrength value true")
	expect("bool false", Fish.option_command("UCI_LimitStrength", false), "setoption name UCI_LimitStrength value false")
	expect("name with spaces", Fish.option_command("Skill Level", 5), "setoption name Skill Level value 5")
	var spin := {"type": "spin", "min": 1, "max": 10}
	expect("spin clamps low", Fish.coerce_option(spin, -5), 1)
	expect("spin clamps high", Fish.coerce_option(spin, 99), 10)
	expect("spin keeps", Fish.coerce_option(spin, 7), 7)
	expect("spin without limits", Fish.coerce_option({"type": "spin"}, 123456), 123456)
	expect("check becomes bool", Fish.coerce_option({"type": "check"}, 1), true)
	expect("string stays text", Fish.coerce_option({"type": "string"}, 5), "5")


func _info_parsing() -> void:
	var line := "info depth 18 seldepth 25 multipv 2 score cp -34 nodes 1234567 nps 2345678 hashfull 120 tbhits 0 time 526 pv e2e4 e7e5 g1f3 b8c6"
	var entry := Fish.parse_info(line)
	expect("rank", entry["n"], 2)
	expect("depth", entry["depth"], 18)
	expect("selective depth", entry["seldepth"], 25)
	expect("score", entry["cp"], -34)
	expect("not mate", entry["has_mate"], false)
	expect("nodes", entry["nodes"], 1234567)
	expect("speed", entry["nps"], 2345678)
	expect("hash use", entry["hashfull"], 120)
	expect("time", entry["time"], 526)
	expect("pv", ",".join(entry["pv"]), "e2e4,e7e5,g1f3,b8c6")
	expect("no bound", entry["bound"], "")

	var mate := Fish.parse_info("info depth 9 multipv 1 score mate -3 pv d8h4")
	expect("mate flag", mate["has_mate"], true)
	expect("mate distance", mate["mate"], -3)

	expect("lower bound", Fish.parse_info("info depth 9 multipv 1 score cp 50 lowerbound pv e2e4")["bound"], "lower")
	expect("upper bound", Fish.parse_info("info depth 9 multipv 1 score cp 50 upperbound pv e2e4")["bound"], "upper")
	expect("rank defaults to one", Fish.parse_info("info depth 3 score cp 1 pv a2a3")["n"], 1)
	expect("promotion", Fish.parse_info("info depth 3 multipv 1 score cp 1 pv e7e8q")["pv"][0], "e7e8q")
	expect("windows line ending", Fish.parse_info("info depth 3 multipv 1 score cp 7 pv a2a3\r\n").is_empty(), false)
	expect("no pv", Fish.parse_info("info depth 3 score cp 1").is_empty(), true)
	expect("progress line", Fish.parse_info("info depth 12 currmove e2e4 currmovenumber 1").is_empty(), true)
	expect("string line", Fish.parse_info("info string NNUE evaluation using nn.nnue").is_empty(), true)
	expect("bestmove", Fish.parse_info("bestmove e2e4 ponder e7e5").is_empty(), true)
	expect("garbage", Fish.parse_info("hello").is_empty(), true)
	var long_pv := "info depth 40 multipv 1 score cp 1 pv " + " ".join(PackedStringArray(["e2e4"]).duplicate()) + " e7e5".repeat(60)
	expect("pv is capped", (Fish.parse_info(long_pv)["pv"] as PackedStringArray).size(), Fish.MAX_PV_MOVES)


func _principal_lines() -> void:
	var sample := "info depth 12 multipv 1 score cp 35 nodes 1000 pv e2e4 e7e5 g1f3\n" \
		+ "info depth 12 multipv 2 score mate -3 pv d2d4\n" \
		+ "info string NNUE evaluation using nn.nnue\n" \
		+ "bestmove e2e4 ponder e7e5\n"
	var lines := Fish.principal_lines(sample, 5)
	expect("two lines", lines.size(), 2)
	expect("line number", int(lines[0]["n"]), 1)
	expect("first move", str(lines[0]["pv"][0]), "e2e4")
	expect("pv length", (lines[0]["pv"] as PackedStringArray).size(), 3)
	expect("cp", int(lines[0]["cp"]), 35)
	expect("mate score", int(lines[1]["mate"]), -3)

	var latest := "info depth 5 multipv 1 score cp 10 pv e2e4\ninfo depth 9 multipv 1 score cp 44 pv d2d4 d7d5\n"
	var newest := Fish.principal_lines(latest, 5)
	expect("keeps the newest line", int(newest[0]["depth"]), 9)
	expect("limit drops extra lines", Fish.principal_lines(sample, 1).size(), 1)
	var sparse := Fish.principal_lines("info depth 8 multipv 3 score cp -20 pv c2c4\n", 5)
	expect("sparse result", sparse.size(), 1)
	expect("sparse keeps number", int(sparse[0]["n"]), 3)
	expect("empty input", Fish.principal_lines("", 5).size(), 0)


func _option_lines() -> void:
	var hash_spec := Fish.parse_option("option name Hash type spin default 16 min 1 max 33554432")
	expect("option name", hash_spec["name"], "Hash")
	expect("option type", hash_spec["type"], "spin")
	expect("option default", hash_spec["default"], 16)
	expect("option min", hash_spec["min"], 1)
	expect("option max", hash_spec["max"], 33554432)
	var skill := Fish.parse_option("option name Skill Level type spin default 20 min 0 max 20")
	expect("name with a space", skill["name"], "Skill Level")
	var check := Fish.parse_option("option name UCI_LimitStrength type check default false")
	expect("check type", check["type"], "check")
	expect("check default", check["default"], false)
	var combo := Fish.parse_option("option name Style type combo default Normal var Solid var Normal var Risky")
	expect("combo default", combo["default"], "Normal")
	expect("combo choices", ",".join(combo["vars"]), "Solid,Normal,Risky")
	var text := Fish.parse_option("option name EvalFile type string default <empty>")
	expect("string default", text["default"], "<empty>")
	var button := Fish.parse_option("option name Clear Hash type button")
	expect("button has a name", button["name"], "Clear Hash")
	expect("button type", button["type"], "button")
	expect("not an option", Fish.parse_option("id name Stockfish 19").is_empty(), true)
	expect("broken option", Fish.parse_option("option name Broken").is_empty(), true)


func _formatting() -> void:
	expect("nodes per second", Fish.format_nodes_per_second(2345678), "2.3 Mn/s")
	expect("thousands", Fish.format_nodes_per_second(45300), "45 kn/s")
	expect("small", Fish.format_nodes_per_second(800), "800 n/s")
