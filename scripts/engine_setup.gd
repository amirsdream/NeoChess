class_name EngineSetup
extends RefCounted

# Helpers for finding, downloading and installing the Stockfish engine.
# Stockfish is GPLv3 and is not stored in this repository. NeoChess downloads
# the official Windows build from the Stockfish GitHub release on request.

const VERSION := "19"
const ASSET := "stockfish-windows-x86-64-universal.zip"
const URL := "https://github.com/official-stockfish/Stockfish/releases/download/sf_19/stockfish-windows-x86-64-universal.zip"
const RELEASE_PAGE := "https://github.com/official-stockfish/Stockfish/releases/tag/sf_19"
const LICENSE_FILES := ["Copying.txt", "AUTHORS"]
const MIN_EXE_BYTES := 1000000


static func install_dir() -> String:
	return OS.get_user_data_dir().path_join("engine")


static func install_path() -> String:
	return install_dir().path_join("stockfish.exe")


static func zip_path() -> String:
	return install_dir().path_join("stockfish-download.zip")


# Places NeoChess looks for an engine, best first.
static func candidates(exe_dir: String, project_bin: String) -> PackedStringArray:
	return PackedStringArray([
		project_bin.path_join("stockfish.exe"),
		exe_dir.path_join("stockfish.exe"),
		exe_dir.path_join("bin/stockfish.exe"),
		install_path(),
	])


static func first_existing(paths: PackedStringArray) -> String:
	for path in paths:
		if FileAccess.file_exists(path):
			return path
	return ""


# Chooses the engine executable inside a release archive. Prefers the
# shallowest file named stockfish*.exe and ignores folders and other files.
static func pick_executable(entries: PackedStringArray) -> String:
	var best := ""
	var best_depth := 1 << 20
	for entry in entries:
		if entry.ends_with("/"):
			continue
		var name := entry.get_file().to_lower()
		if not (name.begins_with("stockfish") and name.ends_with(".exe")):
			continue
		var depth := entry.count("/")
		if depth < best_depth:
			best = entry
			best_depth = depth
	return best


# Unpacks the engine (and its license files) from the archive into dest_dir.
# Returns {"ok": bool, "path": String, "error": String}.
static func extract(zip_file: String, dest_dir: String) -> Dictionary:
	var reader := ZIPReader.new()
	if reader.open(zip_file) != OK:
		return _fail("The downloaded file is not a valid zip archive.")
	var entries := reader.get_files()
	var exe_entry := pick_executable(entries)
	if exe_entry.is_empty():
		reader.close()
		return _fail("The archive does not contain a Stockfish executable.")
	if DirAccess.make_dir_recursive_absolute(dest_dir) != OK:
		reader.close()
		return _fail("Could not create the install folder.")
	var target := dest_dir.path_join("stockfish.exe")
	var written := _write(target, reader.read_file(exe_entry))
	if not written:
		reader.close()
		return _fail("Could not write the engine file.")
	for entry in entries:
		if entry.ends_with("/") or entry.count("/") > 1:
			continue
		if entry.get_file() in LICENSE_FILES:
			_write(dest_dir.path_join(entry.get_file()), reader.read_file(entry))
	reader.close()
	if not looks_like_windows_exe(target):
		DirAccess.remove_absolute(target)
		return _fail("The extracted file is not a Windows program.")
	return {"ok": true, "path": target, "error": ""}


static func looks_like_windows_exe(path: String, min_bytes: int = MIN_EXE_BYTES) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var big_enough := file.get_length() >= min_bytes
	var header := file.get_buffer(2)
	file.close()
	return big_enough and header.size() == 2 and header[0] == 0x4D and header[1] == 0x5A


# Runs the engine once to confirm it starts. Stockfish answers the
# "compiler" command and exits, so this is quick and needs no UCI session.
static func runs(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var output: Array = []
	var code := OS.execute(path, PackedStringArray(["compiler"]), output, true, false)
	if code != 0:
		return false
	return " ".join(PackedStringArray(output)).contains("Stockfish")


static func format_size(bytes: int) -> String:
	if bytes >= 1048576:
		return "%.1f MB" % (float(bytes) / 1048576.0)
	if bytes >= 1024:
		return "%d KB" % (bytes / 1024)
	return "%d B" % bytes


static func progress_text(received: int, total: int) -> String:
	if total > 0:
		return "%s of %s" % [format_size(received), format_size(total)]
	if received > 0:
		return format_size(received)
	return "Connecting…"


static func progress_ratio(received: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return clampf(float(received) / float(total), 0.0, 1.0)


static func describe_http_failure(result: int, code: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
				return "Could not reach GitHub. Check your internet connection."
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
				return "A secure connection to GitHub could not be made."
			HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
				return "Could not save the download. Check free disk space."
			_:
				return "The download failed (error %d)." % result
	if code != 200:
		return "GitHub answered with HTTP %d." % code
	return ""


static func _write(path: String, data: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(data)
	file.close()
	return true


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "path": "", "error": message}
