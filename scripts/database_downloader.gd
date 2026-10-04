class_name DatabaseDownloader
extends Node

# Downloads a game database (a .zip of PGN files) with progress and cancel.
# The Lichess Elite database is free to use: https://database.nikonoel.fr

signal progress(received: int, total: int)
signal finished(path: String, error: String)

const BASE_URL := "https://database.nikonoel.fr/lichess_elite_%s.zip"
const FIRST_MONTH := Vector2i(2021, 1)
const LATEST_MONTH := Vector2i(2025, 11)

var busy := false
var target := ""
var http: HTTPRequest


# Months that exist, newest first, as "YYYY-MM".
static func months() -> PackedStringArray:
	var list := PackedStringArray()
	var year := LATEST_MONTH.x
	var month := LATEST_MONTH.y
	while year > FIRST_MONTH.x or (year == FIRST_MONTH.x and month >= FIRST_MONTH.y):
		list.append("%04d-%02d" % [year, month])
		month -= 1
		if month == 0:
			month = 12
			year -= 1
	return list


static func url_for(month: String) -> String:
	return BASE_URL % month


static func download_dir() -> String:
	return OS.get_user_data_dir().path_join("downloads")


static func describe_failure(result: int, code: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "The download failed (%s). Check your internet connection." % _result_name(result)
	if code == 404:
		return "That month is not available on the server."
	if code < 200 or code >= 300:
		return "The server answered with HTTP %d." % code
	return ""


static func _result_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "could not connect"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "secure connection failed"
		HTTPRequest.RESULT_TIMEOUT:
			return "timed out"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "could not write the file"
	return "error %d" % result


# True when the file starts like a zip archive (the server answers missing
# months with a normal web page).
static func is_zip(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var head := file.get_buffer(2)
	file.close()
	return head.size() == 2 and head[0] == 0x50 and head[1] == 0x4B


func start(url: String, dest: String) -> void:
	if busy:
		return
	busy = true
	target = dest
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	http = HTTPRequest.new()
	http.download_file = dest
	http.use_threads = true
	http.max_redirects = 8
	http.timeout = 0.0
	http.download_chunk_size = 1048576
	add_child(http)
	http.request_completed.connect(_on_done)
	var err := http.request(url)
	if err != OK:
		_end("Could not start the download (error %d)." % err)
		return
	set_process(true)
	progress.emit(0, 0)


func cancel() -> void:
	if not busy:
		return
	if http != null:
		http.cancel_request()
	_end("Download cancelled.")


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if busy and http != null:
		progress.emit(http.get_downloaded_bytes(), http.get_body_size())


func _on_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var problem := describe_failure(result, code)
	if problem == "" and not is_zip(target):
		problem = "That month is not available on the server."
	_end(problem)


func _end(error: String) -> void:
	busy = false
	set_process(false)
	if http != null:
		http.queue_free()
		http = null
	var path := target
	if error != "":
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		path = ""
	finished.emit(path, error)
