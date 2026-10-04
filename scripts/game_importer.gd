class_name GameImporter
extends Node

# Loads a PGN file (or a .zip holding PGN files) into the game library on a
# worker thread, so the window stays responsive while hundreds of thousands of
# games are read. Poll games_added / progress() every frame for a progress bar.
#
#   importer.finished.connect(func(result): ...)
#   importer.start("C:/lichess_elite_2023-12.zip", "Lichess Elite 2023-12")

signal finished(result: Dictionary)

const BATCH := 2000

var running := false
var stage := ""
var source_name := ""

var _thread: Thread
var _mutex := Mutex.new()
var _cancel := false
var _read := 0
var _added := 0
var _skipped := 0
var _bytes_done := 0
var _bytes_total := 0
var _temp_files: Array = []


func _exit_tree() -> void:
	cancel()
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


# Starts importing. Returns false when an import is already running.
func start(file_path: String, name_for_source: String, db_path: String = "") -> bool:
	if running:
		return false
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	running = true
	source_name = name_for_source
	stage = "Starting"
	_cancel = false
	_read = 0
	_added = 0
	_skipped = 0
	_bytes_done = 0
	_bytes_total = 0
	_temp_files = []
	var target := db_path if db_path != "" else GameStore.default_path()
	_thread = Thread.new()
	_thread.start(_work.bind(file_path, name_for_source, target))
	return true


func cancel() -> void:
	_mutex.lock()
	_cancel = true
	_mutex.unlock()


# Games read, games added (new ones), bytes processed and the total.
func counters() -> Dictionary:
	_mutex.lock()
	var snapshot := {"read": _read, "added": _added, "skipped": _skipped, "bytes_done": _bytes_done, "bytes_total": _bytes_total, "stage": stage}
	_mutex.unlock()
	return snapshot


func progress() -> float:
	var counted := counters()
	var total := int(counted["bytes_total"])
	return 0.0 if total <= 0 else clampf(float(counted["bytes_done"]) / float(total), 0.0, 1.0)


func _set_stage(text: String) -> void:
	_mutex.lock()
	stage = text
	_mutex.unlock()


func _cancelled() -> bool:
	_mutex.lock()
	var value := _cancel
	_mutex.unlock()
	return value


func _work(file_path: String, name_for_source: String, db_path: String) -> void:
	var result := {"ok": false, "error": "", "added": 0, "read": 0, "skipped": 0, "source_id": 0, "cancelled": false, "source": name_for_source}
	var store := GameStore.new()
	if not store.open(db_path):
		result["error"] = store.error
		_finish.call_deferred(result)
		return
	var pgn_files: Array = []
	if file_path.get_extension().to_lower() == "zip":
		_set_stage("Unpacking")
		var unpacked := _unpack(file_path)
		if str(unpacked["error"]) != "":
			result["error"] = unpacked["error"]
			store.close()
			_finish.call_deferred(result)
			return
		pgn_files = unpacked["files"]
		_temp_files = pgn_files.duplicate()
	elif file_path.get_extension().to_lower() == "zst":
		result["error"] = "Compressed .zst files are not supported. Unpack the file first, or use a .pgn or .zip."
		store.close()
		_finish.call_deferred(result)
		return
	else:
		pgn_files = [file_path]
	var total := 0
	for pgn_path in pgn_files:
		var probe := FileAccess.open(str(pgn_path), FileAccess.READ)
		if probe != null:
			total += int(probe.get_length())
			probe.close()
	_mutex.lock()
	_bytes_total = total
	_mutex.unlock()
	if total == 0:
		result["error"] = "The file is empty or could not be read."
		store.close()
		_cleanup_temp()
		_finish.call_deferred(result)
		return

	var source_id := store.add_source(name_for_source, GameStore.KIND_IMPORT, file_path)
	result["source_id"] = source_id
	_set_stage("Importing")
	var base := 0
	var rows: Array = []
	for pgn_path in pgn_files:
		var file := FileAccess.open(str(pgn_path), FileAccess.READ)
		if file == null:
			continue
		var reader := PgnReader.new(file)
		while not _cancelled():
			var game := reader.next_game()
			if game.is_empty():
				break
			var row := GameStore.record_from(game)
			_mutex.lock()
			_read += 1
			if row.is_empty():
				_skipped += 1
			_mutex.unlock()
			if not row.is_empty():
				rows.append(row)
			if rows.size() >= BATCH:
				_flush(store, source_id, rows, base + reader.position())
				rows = []
		base += int(file.get_length())
		file.close()
		if _cancelled():
			break
	if not rows.is_empty():
		_flush(store, source_id, rows, _bytes_done)
	store.refresh_count(source_id)
	_cleanup_temp()
	store.close()
	_mutex.lock()
	result["added"] = _added
	result["read"] = _read
	result["skipped"] = _skipped
	_mutex.unlock()
	result["cancelled"] = _cancelled()
	result["ok"] = true
	_finish.call_deferred(result)


func _flush(store: GameStore, source_id: int, rows: Array, bytes: int) -> void:
	var added := store.add_games(source_id, rows)
	_mutex.lock()
	_added += added
	_bytes_done = bytes
	_mutex.unlock()


# Extracts the PGN files of a zip archive into the user folder.
func _unpack(zip_path: String) -> Dictionary:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return {"error": "The file is not a valid zip archive.", "files": []}
	var files: Array = []
	var index := 0
	for entry in reader.get_files():
		if _cancelled():
			break
		if not str(entry).to_lower().ends_with(".pgn"):
			continue
		var data := reader.read_file(str(entry))
		var target := OS.get_user_data_dir().path_join("import_%d.pgn" % index)
		var out := FileAccess.open(target, FileAccess.WRITE)
		if out == null:
			reader.close()
			return {"error": "Could not unpack the archive (is the disk full?).", "files": files}
		out.store_buffer(data)
		out.close()
		files.append(target)
		index += 1
	reader.close()
	if files.is_empty() and not _cancelled():
		return {"error": "The zip file contains no .pgn file.", "files": []}
	return {"error": "", "files": files}


func _cleanup_temp() -> void:
	for temp in _temp_files:
		DirAccess.remove_absolute(str(temp))
	_temp_files = []


func _finish(result: Dictionary) -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	running = false
	stage = ""
	finished.emit(result)
