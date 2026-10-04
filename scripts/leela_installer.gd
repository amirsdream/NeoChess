class_name LeelaInstaller
extends Node

# Downloads Leela Chess Zero for the current user in up to two steps: the lc0
# program (a zip from the lc0 GitHub release) and one neural network. A step is
# skipped when its file is already installed, so a cancelled or failed download
# continues where it stopped. It has the same signals as EngineInstaller.

signal progress(received: int, total: int)
signal finished(path: String, error: String)

enum Step { ENGINE, NETWORK }

var busy := false
var installing := false
# What is happening now, for the status line.
var step_text := "Downloading"
var http: HTTPRequest
var worker: Thread

var _steps: Array = []
var _current := -1


func start() -> void:
	if busy:
		return
	if not LeelaSetup.is_supported():
		finished.emit("", "Leela Chess Zero has no official download for %s on %s. Install lc0 with your package manager and choose the file in Settings." % [OS.get_name(), Engine.get_architecture_name()])
		return
	busy = true
	DirAccess.make_dir_recursive_absolute(LeelaSetup.install_dir())
	_steps = []
	if LeelaSetup.needs_engine():
		_steps.append(Step.ENGINE)
	if LeelaSetup.needs_network():
		_steps.append(Step.NETWORK)
	set_process(true)
	_next()


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


func _label(kind: int) -> String:
	var position := _steps.find(kind) + 1
	var text := "Downloading Leela engine" if kind == Step.ENGINE else "Downloading neural network"
	if _steps.size() > 1:
		text += " (%d of %d)" % [position, _steps.size()]
	return text


func _next() -> void:
	_current += 1
	if _current >= _steps.size():
		_end(LeelaSetup.install_path(), "")
		return
	var kind := int(_steps[_current])
	step_text = _label(kind)
	var target := LeelaSetup.archive_path() if kind == Step.ENGINE else _partial_network()
	var url := LeelaSetup.download_url() if kind == Step.ENGINE else LeelaSetup.NETWORK_URL
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(target)
	http = HTTPRequest.new()
	http.download_file = target
	http.use_threads = true
	http.max_redirects = 8
	http.timeout = 0.0
	add_child(http)
	http.request_completed.connect(_on_downloaded.bind(kind))
	var err := http.request(url)
	if err != OK:
		_fail("Could not start the download (error %d)." % err)
		return
	progress.emit(0, 0)


func _partial_network() -> String:
	return LeelaSetup.network_path() + ".part"


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, kind: int) -> void:
	var host := "GitHub" if kind == Step.ENGINE else "the Leela Chess Zero server"
	var problem := LeelaSetup.describe_http_failure(result, code, host)
	if problem != "":
		_fail(problem)
		return
	if http != null:
		http.queue_free()
		http = null
	if kind == Step.NETWORK:
		_finish_network()
		return
	installing = true
	step_text = "Installing and checking Leela"
	progress.emit(1, 1)
	worker = Thread.new()
	worker.start(_install_engine)


func _install_engine() -> void:
	var outcome := LeelaSetup.extract(LeelaSetup.archive_path(), LeelaSetup.install_dir())
	var error := str(outcome["error"])
	if bool(outcome["ok"]) and not LeelaSetup.runs(str(outcome["path"])):
		error = "Leela was installed but did not start on this computer."
	call_deferred("_engine_installed", error)


func _engine_installed(error: String) -> void:
	if worker != null:
		worker.wait_to_finish()
		worker = null
	installing = false
	if FileAccess.file_exists(LeelaSetup.archive_path()):
		DirAccess.remove_absolute(LeelaSetup.archive_path())
	if error != "":
		_fail(error)
		return
	_next()


func _finish_network() -> void:
	var partial := _partial_network()
	if not LeelaSetup.looks_like_network(partial):
		DirAccess.remove_absolute(partial)
		_fail("The downloaded network is not a valid file. Try again.")
		return
	if FileAccess.file_exists(LeelaSetup.network_path()):
		DirAccess.remove_absolute(LeelaSetup.network_path())
	if DirAccess.rename_absolute(partial, LeelaSetup.network_path()) != OK:
		_fail("Could not save the network file.")
		return
	_next()


func _fail(message: String) -> void:
	_cleanup()
	_end("", message)


func _cleanup() -> void:
	for leftover in [LeelaSetup.archive_path(), _partial_network()]:
		if FileAccess.file_exists(str(leftover)):
			DirAccess.remove_absolute(str(leftover))
	if http != null:
		http.queue_free()
		http = null


func _end(path: String, error: String) -> void:
	busy = false
	installing = false
	_current = -1
	_steps = []
	set_process(false)
	finished.emit(path, error)
