class_name UciEngine
extends Node

# A running UCI chess engine (Stockfish or any other) that stays alive between
# searches. It talks to the engine over its standard input and output, which
# works the same on Windows, Linux and macOS, and needs no helper scripts.
#
# Typical use:
#   engine.start(path)                       # starts the process, UCI handshake
#   engine.search(fen, go, settings)         # best move, or infinite analysis
#   engine.info    -> one line of analysis (MultiPV index, score, depth, pv)
#   engine.best_move -> the finished search
#   engine.failed  -> it could not start, stopped answering or exited
#
# Searches never overlap: asking for a new one while the engine is busy sends
# "stop" and starts the new one once the engine has acknowledged it, so lines
# from the old position can never be mistaken for the new one.

signal started(engine_name: String)
signal info(entry: Dictionary)
signal best_move(uci: String)
signal failed(message: String)

enum State { OFF, STARTING, IDLE, SEARCHING, STOPPING, FAILED }

const HANDSHAKE_MS := 20000
const STOP_GRACE_MS := 8000

var path := ""
var engine_name := ""
var engine_author := ""
var options: Dictionary = {}
var state := State.OFF
var last_entry: Dictionary = {}

var _pid := -1
var _stdio: FileAccess
var _stderr_io: FileAccess
var _reader: Thread
var _err_reader: Thread
var _mutex := Mutex.new()
var _inbox := PackedStringArray()
var _eof := false
var _stderr_text := ""
var _applied: Dictionary = {}
var _job: Dictionary = {}
var _queued: Dictionary = {}
var _fresh_game := false
var _started_ms := 0
var _deadline_ms := 0


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	shutdown()


# True while there is a process that can be given work.
func usable() -> bool:
	return state == State.STARTING or state == State.IDLE or state == State.SEARCHING or state == State.STOPPING


func is_searching() -> bool:
	return state == State.SEARCHING or state == State.STOPPING


func has_option(option_name: String) -> bool:
	return options.has(option_name)


# Starts the engine process and the UCI handshake. Failures also arrive
# through the failed signal. Returns true when the process was launched.
func start(exe_path: String) -> bool:
	shutdown()
	path = exe_path
	options = {}
	engine_name = ""
	engine_author = ""
	last_entry = {}
	_applied = {}
	_job = {}
	_queued = {}
	_fresh_game = false
	_stderr_text = ""
	_eof = false
	_inbox = PackedStringArray()
	if not FileAccess.file_exists(exe_path):
		_fail("The engine file was not found: %s" % exe_path)
		return false
	var spawned := OS.execute_with_pipe(exe_path, PackedStringArray())
	if spawned.is_empty():
		var hint := ""
		if OS.get_name() != "Windows":
			hint = " Check that the file is executable."
		_fail("Could not start %s.%s" % [exe_path.get_file(), hint])
		return false
	_pid = int(spawned["pid"])
	_stdio = spawned["stdio"]
	_stderr_io = spawned["stderr"]
	_reader = Thread.new()
	_reader.start(_read_stdout)
	_err_reader = Thread.new()
	_err_reader.start(_read_stderr)
	state = State.STARTING
	_started_ms = Time.get_ticks_msec()
	_send("uci")
	set_process(true)
	return true


# Asks for a search. fen is the position, go describes the search (see
# StockfishUci.go_command) and settings are UCI options to apply first; options
# the engine does not have are skipped.
func search(fen: String, go: Dictionary, settings: Dictionary = {}) -> void:
	var job := {"fen": fen, "go": go, "settings": settings}
	match state:
		State.STARTING, State.STOPPING:
			_queued = job
		State.IDLE:
			_begin(job)
		State.SEARCHING:
			_queued = job
			_stop_search()


# Ends the current search without reporting its result.
func stop() -> void:
	_queued = {}
	if state == State.SEARCHING:
		_stop_search()


# Forget what the engine learned (hash tables) before the next search.
func new_game() -> void:
	_fresh_game = true
	if state == State.IDLE:
		_flush_new_game()
	elif state == State.SEARCHING:
		stop()


# Ends the process and joins the reader threads. Safe to call at any time.
func shutdown() -> void:
	if _pid >= 0:
		if _stdio != null and not _eof:
			_stdio.store_line("quit")
			_stdio.flush()
		var waited := 0
		while waited < 1000 and OS.is_process_running(_pid):
			OS.delay_msec(10)
			waited += 10
		if OS.is_process_running(_pid):
			OS.kill(_pid)
	if _reader != null and _reader.is_started():
		_reader.wait_to_finish()
	if _err_reader != null and _err_reader.is_started():
		_err_reader.wait_to_finish()
	_reader = null
	_err_reader = null
	_stdio = null
	_stderr_io = null
	_pid = -1
	_job = {}
	_queued = {}
	state = State.OFF
	set_process(false)


func _process(_delta: float) -> void:
	_mutex.lock()
	var batch := _inbox
	_inbox = PackedStringArray()
	var ended := _eof
	_mutex.unlock()
	for line in batch:
		_handle(line)
	if ended and (state == State.STARTING or state == State.IDLE or state == State.SEARCHING or state == State.STOPPING):
		_exited()
		return
	_check_timeouts()


func _handle(line: String) -> void:
	if line.begins_with("info "):
		if state != State.SEARCHING:
			return
		var entry := StockfishUci.parse_info(line)
		if entry.is_empty():
			return
		last_entry = entry
		info.emit(entry)
	elif line.begins_with("bestmove"):
		_on_best_move(line)
	elif line == "uciok":
		_on_uciok()
	elif line.begins_with("id name "):
		engine_name = line.substr(8)
	elif line.begins_with("id author "):
		engine_author = line.substr(10)
	elif line.begins_with("option name "):
		var spec := StockfishUci.parse_option(line)
		if not spec.is_empty():
			options[str(spec["name"])] = spec


func _on_uciok() -> void:
	if state != State.STARTING:
		return
	state = State.IDLE
	started.emit(engine_name)
	if not _queued.is_empty():
		var job := _queued
		_queued = {}
		_begin(job)


func _on_best_move(line: String) -> void:
	var words := line.split(" ", false)
	var move := str(words[1]) if words.size() > 1 else ""
	match state:
		State.SEARCHING:
			state = State.IDLE
			_job = {}
			_deadline_ms = 0
			best_move.emit(move)
		State.STOPPING:
			state = State.IDLE
			_job = {}
			_deadline_ms = 0
			if not _queued.is_empty():
				var job := _queued
				_queued = {}
				_begin(job)
			else:
				_flush_new_game()


func _begin(job: Dictionary) -> void:
	_flush_new_game()
	_apply(job["settings"] as Dictionary)
	_send("position fen %s" % str(job["fen"]))
	var go := job["go"] as Dictionary
	_send(StockfishUci.go_command(go))
	_job = job
	state = State.SEARCHING
	var budget := StockfishUci.time_budget_ms(go)
	_deadline_ms = Time.get_ticks_msec() + budget if budget > 0 else 0


func _stop_search() -> void:
	_send("stop")
	state = State.STOPPING
	_deadline_ms = Time.get_ticks_msec() + STOP_GRACE_MS


func _flush_new_game() -> void:
	if not _fresh_game:
		return
	_fresh_game = false
	_send("ucinewgame")
	_send("isready")


func _apply(settings: Dictionary) -> void:
	for option_name in settings:
		var spec: Dictionary = options.get(option_name, {})
		if spec.is_empty():
			continue
		var value = StockfishUci.coerce_option(spec, settings[option_name])
		if _applied.get(option_name, spec.get("default")) == value:
			continue
		_applied[option_name] = value
		_send(StockfishUci.option_command(str(option_name), value))


func _send(command: String) -> void:
	if _stdio == null or _eof:
		return
	_stdio.store_line(command)
	_stdio.flush()


func _check_timeouts() -> void:
	var now := Time.get_ticks_msec()
	if state == State.STARTING and now - _started_ms > HANDSHAKE_MS:
		_fail("%s did not answer as a UCI chess engine." % path.get_file())
	elif (state == State.SEARCHING or state == State.STOPPING) and _deadline_ms > 0 and now > _deadline_ms:
		_fail("The engine stopped responding.")


func _exited() -> void:
	var was_starting := state == State.STARTING
	var detail := _stderr_text.strip_edges()
	var message := "%s is not a UCI chess engine." % path.get_file() if was_starting else "The engine stopped unexpectedly."
	if detail != "":
		message += " " + detail.get_slice("\n", 0)
	_fail(message)


func _fail(message: String) -> void:
	var failing := path
	shutdown()
	path = failing
	state = State.FAILED
	failed.emit(message)


func _read_stdout() -> void:
	while true:
		var text := _stdio.get_line()
		if text.is_empty() and _stdio.get_error() != OK:
			break
		text = text.strip_edges()
		if text.is_empty():
			continue
		_mutex.lock()
		_inbox.append(text)
		_mutex.unlock()
	_mutex.lock()
	_eof = true
	_mutex.unlock()


func _read_stderr() -> void:
	while true:
		var text := _stderr_io.get_line()
		if text.is_empty() and _stderr_io.get_error() != OK:
			break
		if _stderr_text.length() < 2000:
			_stderr_text += text + "\n"
