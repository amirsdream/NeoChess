class_name EngineInstaller
extends Node

# Downloads the official Stockfish release and installs it for the current user.

signal progress(received: int, total: int)
signal finished(path: String, error: String)

var busy := false
var installing := false
# What is happening now, for the status line.
var step_text := "Downloading Stockfish"
var http: HTTPRequest
var worker: Thread


func start() -> void:
	if busy:
		return
	if not EngineSetup.is_supported():
		finished.emit("", "Stockfish has no official download for %s on %s. Install it with your package manager and choose the file in Settings." % [OS.get_name(), Engine.get_architecture_name()])
		return
	busy = true
	DirAccess.make_dir_recursive_absolute(EngineSetup.install_dir())
	if FileAccess.file_exists(EngineSetup.archive_path()):
		DirAccess.remove_absolute(EngineSetup.archive_path())
	http = HTTPRequest.new()
	http.download_file = EngineSetup.archive_path()
	http.use_threads = true
	http.max_redirects = 8
	http.timeout = 0.0
	add_child(http)
	http.request_completed.connect(_on_downloaded)
	var err := http.request(EngineSetup.download_url())
	if err != OK:
		_end("", "Could not start the download (error %d)." % err)
		return
	set_process(true)
	progress.emit(0, 0)


func cancel() -> void:
	if not busy or worker != null:
		return
	if http != null:
		http.cancel_request()
	_cleanup()
	_end("", "Download cancelled.")


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if busy and http != null and worker == null:
		progress.emit(http.get_downloaded_bytes(), http.get_body_size())


func _exit_tree() -> void:
	if worker != null:
		worker.wait_to_finish()
		worker = null


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var problem := EngineSetup.describe_http_failure(result, code)
	if problem != "":
		_cleanup()
		_end("", problem)
		return
	installing = true
	progress.emit(1, 1)
	worker = Thread.new()
	worker.start(_install)


func _install() -> void:
	var outcome := EngineSetup.extract(EngineSetup.archive_path(), EngineSetup.install_dir())
	var error := str(outcome["error"])
	var path := str(outcome["path"])
	if bool(outcome["ok"]) and not EngineSetup.runs(path):
		error = "The engine was installed but did not start on this computer."
		path = ""
	call_deferred("_installed", path, error)


func _installed(path: String, error: String) -> void:
	if worker != null:
		worker.wait_to_finish()
		worker = null
	_cleanup()
	_end(path, error)


func _cleanup() -> void:
	if FileAccess.file_exists(EngineSetup.archive_path()):
		DirAccess.remove_absolute(EngineSetup.archive_path())
	if http != null:
		http.queue_free()
		http = null


func _end(path: String, error: String) -> void:
	busy = false
	installing = false
	set_process(false)
	finished.emit(path, error)
