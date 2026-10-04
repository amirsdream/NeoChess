extends "res://tests/test_base.gd"

# Plays real positions through Stockfish with the UciEngine class. Skipped when
# no engine is installed, so the rest of the suite still runs on a fresh checkout.

const Rules = preload("res://scripts/chess_game.gd")
const Fish = preload("res://scripts/stockfish_uci.gd")

const SETTINGS := {"Threads": 1, "Hash": 16, "MultiPV": 1, "Skill Level": 20, "UCI_LimitStrength": false}

var seen: Dictionary = {}


func run() -> void:
	await _bad_engines()
	var path := EngineSetup.first_existing(EngineSetup.candidates(
		OS.get_executable_path().get_base_dir(),
		ProjectSettings.globalize_path("res://bin"),
		EngineSetup.platform(),
	))
	if path.is_empty():
		skip("engine tests (no Stockfish found; run dev/fetch_stockfish.ps1)")
		return
	await _handshake(path)
	await _opening(path)
	await _forced_mate(path)
	await _multipv(path)
	await _strength_options(path)
	await _stop_and_replace(path)
	await _new_game_and_reuse(path)
	await _shutdown(path)
	await _review_in_the_app()
	await _choosing_a_side()


# Creates an engine node that records everything it emits in `seen`.
func _make() -> UciEngine:
	var engine := UciEngine.new()
	root.add_child(engine)
	seen = {"started": "", "failed": "", "best": [], "infos": [], "failures": 0}
	engine.started.connect(func(n: String) -> void: seen["started"] = n)
	engine.failed.connect(func(m: String) -> void:
		seen["failed"] = m
		seen["failures"] = int(seen["failures"]) + 1
	)
	engine.best_move.connect(func(m: String) -> void: (seen["best"] as Array).append(m))
	engine.info.connect(func(e: Dictionary) -> void: (seen["infos"] as Array).append(e))
	return engine


func _until(condition: Callable, timeout_ms: int = 15000) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout_ms:
		if condition.call():
			return true
		await process_frame
		OS.delay_msec(5)
	return condition.call()


func _bests() -> Array:
	return seen["best"] as Array


func _infos() -> Array:
	return seen["infos"] as Array


func _finish(engine: UciEngine) -> void:
	engine.shutdown()
	engine.queue_free()
	await process_frame


func _bad_engines() -> void:
	var missing := _make()
	var launched := missing.start("C:/definitely/not/here/stockfish")
	expect("missing file does not launch", launched, false)
	expect("missing file reports failure", String(seen["failed"]).contains("not found"), true)
	expect("missing file state", missing.state, UciEngine.State.FAILED)
	expect("failed engine is not usable", missing.usable(), false)
	await _finish(missing)

	# A real program that is not a UCI engine: it must be reported, not hang.
	var impostor := _make()
	var program := OS.get_executable_path() if OS.get_name() == "Windows" else "/bin/ls"
	if FileAccess.file_exists(program) and OS.get_name() != "Windows":
		var started := impostor.start(program)
		if started:
			var failed := await _until(func() -> bool: return int(seen["failures"]) > 0, 8000)
			expect("a program that is not an engine is rejected", failed, true)
			expect("rejection names the file", String(seen["failed"]).contains("ls"), true)
	await _finish(impostor)


func _handshake(path: String) -> void:
	var engine := _make()
	expect("engine launches", engine.start(path), true)
	expect("handshake begins", engine.state, UciEngine.State.STARTING)
	var ready := await _until(func() -> bool: return engine.state == UciEngine.State.IDLE)
	expect("handshake finishes", ready, true)
	expect_true("engine reports its name", String(seen["started"]).to_lower().contains("stockfish"), "(%s)" % seen["started"])
	expect("name is kept", engine.engine_name, seen["started"])
	expect_true("author is reported", engine.engine_author != "")
	expect("hash option is known", engine.has_option("Hash"), true)
	expect("threads option is known", engine.has_option("Threads"), true)
	expect("multipv option is known", engine.has_option("MultiPV"), true)
	expect("strength option is known", engine.has_option("UCI_LimitStrength"), true)
	expect("unknown option is not", engine.has_option("No Such Option"), false)
	var hash_spec: Dictionary = engine.options["Hash"]
	expect("hash is a spin", hash_spec["type"], "spin")
	expect_true("hash range is known", int(hash_spec["max"]) > int(hash_spec["min"]))
	expect("usable once started", engine.usable(), true)
	expect("not searching when idle", engine.is_searching(), false)
	await _finish(engine)


func _opening(path: String) -> void:
	var game := Rules.new()
	var engine := _make()
	engine.start(path)
	engine.search(game.to_fen(), {"movetime": 300}, SETTINGS)
	expect("search queued during startup", engine.state, UciEngine.State.STARTING)
	var done := await _until(func() -> bool: return not _bests().is_empty())
	expect("search answers", done, true)
	var uci := String(_bests()[0]) if done else ""
	expect_true("opening move is legal", not game.match_uci(uci).is_empty(), "(got '%s')" % uci)
	expect_true("lines streamed in", _infos().size() > 2, "(%d)" % _infos().size())
	var depth := int((_infos().back() as Dictionary)["depth"])
	expect_true("search reached some depth", depth >= 6, "(depth %d)" % depth)
	expect("idle afterwards", engine.state, UciEngine.State.IDLE)
	await _finish(engine)


func _forced_mate(path: String) -> void:
	var white = Rules.setup("6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
	var engine := _make()
	engine.start(path)
	engine.search(white.to_fen(), {"movetime": 300}, SETTINGS)
	await _until(func() -> bool: return not _bests().is_empty())
	expect("finds back rank mate", String(_bests()[0]) if not _bests().is_empty() else "", "a1a8")
	var mate_line := false
	for entry in _infos():
		if bool((entry as Dictionary)["has_mate"]) and int((entry as Dictionary)["mate"]) == 1:
			mate_line = true
	expect("reports mate in one", mate_line, true)

	var black = Rules.setup("7k/8/8/8/8/5q2/8/6K1 b - - 0 1")
	seen["best"] = []
	engine.search(black.to_fen(), {"movetime": 300}, SETTINGS)
	await _until(func() -> bool: return not _bests().is_empty())
	var reply := String(_bests()[0]) if not _bests().is_empty() else ""
	expect_true("black finds a legal move", not black.match_uci(reply).is_empty(), "(got '%s')" % reply)
	await _finish(engine)


func _multipv(path: String) -> void:
	var game := Rules.new()
	var engine := _make()
	engine.start(path)
	var settings := SETTINGS.duplicate()
	settings["MultiPV"] = 5
	engine.search(game.to_fen(), {"movetime": 600}, settings)
	await _until(func() -> bool: return not _bests().is_empty())
	var latest := {}
	for entry in _infos():
		latest[int((entry as Dictionary)["n"])] = entry
	expect("five lines reported", latest.size(), 5)
	var moves := {}
	for n in latest:
		var first := str(((latest[n] as Dictionary)["pv"] as PackedStringArray)[0])
		expect_true("line %d starts with a legal move" % int(n), not game.match_uci(first).is_empty(), "(%s)" % first)
		moves[first] = true
	expect("lines start with different moves", moves.size(), 5)

	# Dropping back to one line is applied to the same running engine.
	seen["best"] = []
	seen["infos"] = []
	engine.search(game.to_fen(), {"movetime": 300}, SETTINGS)
	await _until(func() -> bool: return not _bests().is_empty())
	var ranks := {}
	for entry in _infos():
		ranks[int((entry as Dictionary)["n"])] = true
	expect("single line again", ranks.keys(), [1])
	await _finish(engine)


func _strength_options(path: String) -> void:
	var game := Rules.new()
	var engine := _make()
	engine.start(path)
	engine.search(game.to_fen(), {"movetime": 200}, {"UCI_LimitStrength": true, "UCI_Elo": 1400, "Threads": 1, "Hash": 16})
	await _until(func() -> bool: return not _bests().is_empty())
	var capped := String(_bests()[0]) if not _bests().is_empty() else ""
	expect_true("elo capped search answers", not game.match_uci(capped).is_empty(), "(got '%s')" % capped)

	seen["best"] = []
	engine.search(game.to_fen(), {"clock": true, "wtime": 4000, "btime": 4000, "inc": 0}, SETTINGS)
	await _until(func() -> bool: return not _bests().is_empty())
	var clocked := String(_bests()[0]) if not _bests().is_empty() else ""
	expect_true("clock search answers", not game.match_uci(clocked).is_empty(), "(got '%s')" % clocked)

	seen["best"] = []
	engine.search(game.to_fen(), {"depth": 8}, SETTINGS)
	await _until(func() -> bool: return not _bests().is_empty())
	expect_true("depth search answers", not _bests().is_empty())
	expect_true("depth search reaches its depth", int((engine.last_entry as Dictionary).get("depth", 0)) >= 8)
	await _finish(engine)


# An infinite search keeps streaming until it is stopped, and a new request
# while one is running replaces it without old lines leaking through.
func _stop_and_replace(path: String) -> void:
	var game := Rules.new()
	var engine := _make()
	engine.start(path)
	var multi := SETTINGS.duplicate()
	multi["MultiPV"] = 3
	engine.search(game.to_fen(), {"infinite": true}, multi)
	var deep := await _until(func() -> bool:
		return not _infos().is_empty() and int((_infos().back() as Dictionary)["depth"]) >= 10
	)
	expect("infinite analysis keeps streaming", deep, true)
	expect("no answer while analysing", _bests().is_empty(), true)
	expect("is searching", engine.is_searching(), true)

	engine.stop()
	var settled := await _until(func() -> bool: return engine.state == UciEngine.State.IDLE, 6000)
	expect("stop settles quickly", settled, true)
	expect("stop is silent", _bests().is_empty(), true)

	# Replace a running search with one for a different position.
	var after = Rules.new()
	after.make_move(after.match_uci("e2e4"))
	seen["infos"] = []
	engine.search(game.to_fen(), {"infinite": true}, multi)
	await _until(func() -> bool: return _infos().size() > 3)
	seen["infos"] = []
	engine.search(after.to_fen(), {"movetime": 300}, SETTINGS)
	await _until(func() -> bool: return not _bests().is_empty())
	expect("replacement answers once", _bests().size(), 1)
	var reply := String(_bests()[0]) if not _bests().is_empty() else ""
	expect_true("replacement answer fits the new position", not after.match_uci(reply).is_empty(), "(got '%s')" % reply)
	var stale := false
	for entry in _infos():
		var first := str(((entry as Dictionary)["pv"] as PackedStringArray)[0])
		if after.match_uci(first).is_empty():
			stale = true
	expect("no lines from the old position", stale, false)

	# Many rapid replacements must still end with exactly the last answer.
	seen["best"] = []
	for i in 6:
		engine.search(game.to_fen(), {"infinite": true}, SETTINGS)
	engine.search(after.to_fen(), {"movetime": 200}, SETTINGS)
	await _until(func() -> bool: return not _bests().is_empty())
	await _until(func() -> bool: return false, 400)
	expect("rapid requests give one answer", _bests().size(), 1)
	await _finish(engine)


func _new_game_and_reuse(path: String) -> void:
	var game := Rules.new()
	var engine := _make()
	engine.start(path)
	for round in 3:
		seen["best"] = []
		engine.new_game()
		engine.search(game.to_fen(), {"movetime": 100}, SETTINGS)
		await _until(func() -> bool: return not _bests().is_empty())
		expect("round %d answers" % round, _bests().size(), 1)
	await _finish(engine)


func _shutdown(path: String) -> void:
	var engine := _make()
	engine.start(path)
	await _until(func() -> bool: return engine.state == UciEngine.State.IDLE)
	engine.search(Rules.new().to_fen(), {"infinite": true}, SETTINGS)
	await _until(func() -> bool: return not _infos().is_empty())
	var pid: int = engine._pid
	expect_true("engine process is running", OS.is_process_running(pid))
	engine.shutdown()
	expect("process ends with shutdown", OS.is_process_running(pid), false)
	expect("shutdown resets the state", engine.state, UciEngine.State.OFF)
	engine.shutdown()
	expect("shutdown twice is harmless", engine.state, UciEngine.State.OFF)
	# It can be started again afterwards.
	expect("restart works", engine.start(engine.path), true)
	var ready := await _until(func() -> bool: return engine.state == UciEngine.State.IDLE)
	expect("restart handshake", ready, true)
	await _finish(engine)


# The real window: step back through a game and watch Stockfish analyse each
# position, then come back to the live game.
func _review_in_the_app() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate() as Control
	root.add_child(main)
	await process_frame
	await process_frame
	main.no_engine = false
	main.mode_opt.selected = 1
	main.show_lines_check.set_pressed_no_signal(true)
	main._import_text("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *", "Test")
	var live_fen: String = main.game.to_fen()

	main._goto_ply(2)
	var first := await _wait_for_lines(main)
	expect_true("review shows a line for the first position", first != "", "(none arrived)")
	expect("analysis is running while reviewing", main.analysis_running, true)
	var arrows := 0
	for arrow in main.board_view.analysis_arrows:
		if int((arrow as Dictionary)["from"]) >= 0:
			arrows += 1
	expect_true("real analysis draws three arrows", arrows == 3, "(%d)" % arrows)
	var first_move := String((main.branch_cards[0]["moves"] as Label).text)
	expect_true("lines are for the reviewed position", first_move.begins_with("2. "), "(%s)" % first_move)
	expect_true("the score is a signed number or mate", String((main.branch_cards[0]["score"] as Label).text).length() > 1)
	expect_true("engine card names the engine and speed", String(main.engine_label.text).to_lower().contains("n/s"), "(%s)" % main.engine_label.text)

	main._goto_ply(3)
	for _i in 5:
		await process_frame
	expect("old lines are cleared when the position changes", String((main.branch_cards[0]["moves"] as Label).text), "")
	var second := await _wait_for_lines(main)
	expect_true("review shows a line for the next position", second != "")
	var black_line := String((main.branch_cards[0]["moves"] as Label).text)
	expect_true("black to move lines use the ellipsis", black_line.begins_with("2... "), "(%s)" % black_line)
	expect("live game untouched by the review", main.game.to_fen(), live_fen)

	# Switching Live off while reviewing stops the engine, and stepping on does not restart it.
	main.show_lines_check.button_pressed = false
	expect("Live off stops the review analysis", main.analysis_running, false)
	main._goto_ply(3)
	for _i in 30:
		await process_frame
	expect("stepping does not analyse while Live is off", main.analysis_running, false)
	expect("no lines are shown while Live is off", main.branches_box.visible, false)
	main.show_lines_check.button_pressed = true
	var resumed := await _wait_for_lines(main)
	expect_true("switching Live on analyses again", resumed != "" and main.analysis_running, "(none arrived)")

	main._nav_last()
	expect("leaving the review", main.view_ply, -1)
	var waited := 0
	while main.analysis_running and waited < 300:
		await process_frame
		waited += 1
	expect("review analysis ends when the review ends", main.analysis_running, false)

	# Back in the live game the analysis starts again, for the live position.
	var live := await _wait_for_lines(main)
	expect_true("live analysis restarts after the review", live != "", "(none arrived)")
	expect("live analysis tracks the live position", main.live_fen, main.game.to_fen())
	expect_true("lines are for the live position", String((main.branch_cards[0]["moves"] as Label).text).begins_with("4. "), "(%s)" % (main.branch_cards[0]["moves"] as Label).text)

	# Reviewing again pauses it, and leaving resumes it.
	main._goto_ply(1)
	await process_frame
	expect("live analysis yields to the review", main.live_fen, "")
	main._nav_last()
	var again := await _wait_for_lines(main)
	expect_true("live analysis resumes again", again != "")

	# Playing a move analyses the new position.
	var reply: Dictionary = main.game.match_uci("e1g1")
	main._commit(reply)
	var after := await _wait_for_lines(main)
	expect_true("analysis follows the game", after != "")
	expect_true("lines are for the new position", String((main.branch_cards[0]["moves"] as Label).text).begins_with("4... "), "(%s)" % (main.branch_cards[0]["moves"] as Label).text)

	# Switching Live off stops it.
	main.show_lines_check.set_pressed_no_signal(false)
	for _i in 5:
		await process_frame
	expect("turning Live off ends the analysis", main.live_fen, "")
	main.queue_free()
	await process_frame


# New game asks which side you want. White: Stockfish waits for your first
# move. Black: Stockfish thinks and makes the first move, then you play.
func _choosing_a_side() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate() as Control
	root.add_child(main)
	await process_frame
	await process_frame
	main.no_engine = false
	main.show_lines_check.set_pressed_no_signal(true)
	main.use_clock = false
	main.fixed_movetime = 200
	main.mode_opt.select(0)
	main._on_new_game()
	for _i in 20:
		await process_frame

	# The question appears, and the game waits for the answer.
	main._ask_new_game()
	expect("new game asks for a side", main.side_box.visible, true)
	var before: int = main.played.size()
	main._on_square(main.game.name_sq("e2"))
	expect("the board is locked while asking", main.selected, -1)
	main._hide_side_box()
	expect("cancel closes the question", main.side_box.visible, false)
	expect("cancel keeps the game", main.played.size(), before)

	main._ask_new_game()
	main._on_side_chosen("White")
	expect("choosing closes the question", main.side_box.visible, false)
	for _i in 60:
		await process_frame
		OS.delay_msec(10)
	expect("white: stockfish waits for you", main.played.size(), 0)
	expect("white: it is your move", main._human_to_move(), true)
	expect("white: the board is not turned", main._bottom_is_white(), true)

	main._on_square(main.game.name_sq("e2"))
	main._on_square(main.game.name_sq("e4"))
	var thinking := await _until(func() -> bool: return main.engine_busy or main.played.size() == 2, 5000)
	expect("white: stockfish starts thinking after your move", thinking, true)
	var replied := await _until(func() -> bool: return main.played.size() == 2 and not main.animating and not main.engine_busy, 10000)
	expect("white: stockfish answers your first move", replied, true)

	# Black: Stockfish opens.
	main._ask_new_game()
	main._on_side_chosen("Black")
	var started := await _until(func() -> bool: return main.played.size() == 1 and not main.animating, 10000)
	expect("black: stockfish makes the first move", started, true)
	expect("black: the game restarted", main.start_fen, Pgn.START_FEN)
	expect("black: it is your move after Stockfish's", main._human_to_move(), true)
	expect("black: you play the black pieces", main.game.white_to_move, false)
	expect("black: the board is turned", main._bottom_is_white(), false)
	expect("black: the side is remembered", main.human_white, false)

	var reply := _any_move(main)
	main._on_square(int(reply.from))
	main._on_square(int(reply.to))
	var answered := await _until(func() -> bool: return main.played.size() == 3 and not main.animating and not main.engine_busy, 10000)
	expect("black: stockfish answers your move", answered, true)

	# Random picks one of the two sides and either way the game is sensible.
	main._ask_new_game()
	main._on_side_chosen("Random")
	var settled := await _until(func() -> bool: return not main.engine_busy and not main.animating and main._human_to_move(), 10000)
	expect("random: ends up with you to move", settled, true)
	expect("random: stockfish opened only if you are Black", main.played.size(), 0 if main.human_white else 1)

	# Two people on one computer: no question, no engine.
	main.mode_opt.select(1)
	main.mode_opt.item_selected.emit(1)
	for _i in 10:
		await process_frame
	expect("pass and play: no question", main.side_box.visible, false)
	expect("pass and play: no engine move", main.played.size(), 0)
	expect("pass and play: not searching", main.engine_busy, false)

	# Going back to Stockfish asks again.
	main.mode_opt.select(0)
	main.mode_opt.item_selected.emit(0)
	expect("switching to Stockfish asks for a side", main.side_box.visible, true)
	main.queue_free()
	await process_frame

func _any_move(main: Control) -> Dictionary:
	for move in main.game.legal_moves():
		return move
	return {}


func _wait_for_lines(main: Control) -> String:
	var waited := 0
	while waited < 1500:
		await process_frame
		waited += 1
		var text := String((main.branch_cards[0]["moves"] as Label).text)
		if text != "" and int(String((main.branch_cards[0]["depth"] as Label).text).trim_prefix("depth ")) >= 6:
			return text
		OS.delay_msec(10)
	return ""
