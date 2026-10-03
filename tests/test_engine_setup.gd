extends "res://tests/test_base.gd"

# Covers the Stockfish download helpers without touching the network.

var work := ""


func run() -> void:
	work = OS.get_user_data_dir().path_join("test_engine_setup")
	DirAccess.make_dir_recursive_absolute(work)
	_constants()
	_picking()
	_formatting()
	_http_messages()
	_candidates()
	_extraction()
	_cleanup()


func _constants() -> void:
	expect("url is https", EngineSetup.URL.begins_with("https://github.com/official-stockfish/Stockfish/releases/download/"), true)
	expect("url ends with the asset", EngineSetup.URL.ends_with(EngineSetup.ASSET), true)
	expect("asset is a zip", EngineSetup.ASSET.ends_with(".zip"), true)
	expect("url names the release", EngineSetup.URL.contains("sf_" + EngineSetup.VERSION), true)
	expect("release page", EngineSetup.RELEASE_PAGE.contains("sf_" + EngineSetup.VERSION), true)
	expect("install path is the exe", EngineSetup.install_path().ends_with("engine/stockfish.exe"), true)
	expect("zip lives next to it", EngineSetup.zip_path().get_base_dir(), EngineSetup.install_dir())


func _picking() -> void:
	var release := PackedStringArray([
		"stockfish/",
		"stockfish/AUTHORS",
		"stockfish/Copying.txt",
		"stockfish/src/stockfish.cpp",
		"stockfish/stockfish-windows-x86-64-universal.exe",
	])
	expect("picks the exe", EngineSetup.pick_executable(release), "stockfish/stockfish-windows-x86-64-universal.exe")
	expect("no exe", EngineSetup.pick_executable(PackedStringArray(["a.txt", "b/"])), "")
	expect("empty archive", EngineSetup.pick_executable(PackedStringArray()), "")
	expect("ignores other programs", EngineSetup.pick_executable(PackedStringArray(["tools/helper.exe"])), "")
	var nested := PackedStringArray(["deep/er/stockfish-old.exe", "stockfish.exe"])
	expect("prefers the shallowest", EngineSetup.pick_executable(nested), "stockfish.exe")
	expect("case is ignored", EngineSetup.pick_executable(PackedStringArray(["Stockfish/Stockfish.EXE"])), "Stockfish/Stockfish.EXE")
	expect("folders are ignored", EngineSetup.pick_executable(PackedStringArray(["stockfish.exe/"])), "")


func _formatting() -> void:
	expect("bytes", EngineSetup.format_size(512), "512 B")
	expect("kilobytes", EngineSetup.format_size(2048), "2 KB")
	expect("megabytes", EngineSetup.format_size(5 * 1048576), "5.0 MB")
	expect("connecting", EngineSetup.progress_text(0, 0), "Connecting…")
	expect("unknown total", EngineSetup.progress_text(1048576, 0), "1.0 MB")
	expect("known total", EngineSetup.progress_text(1048576, 4194304), "1.0 MB of 4.0 MB")
	expect_near("ratio half", EngineSetup.progress_ratio(50, 100), 0.5)
	expect_near("ratio unknown", EngineSetup.progress_ratio(50, 0), 0.0)
	expect_near("ratio clamps", EngineSetup.progress_ratio(500, 100), 1.0)


func _http_messages() -> void:
	expect("success", EngineSetup.describe_http_failure(HTTPRequest.RESULT_SUCCESS, 200), "")
	expect("not found", EngineSetup.describe_http_failure(HTTPRequest.RESULT_SUCCESS, 404), "GitHub answered with HTTP 404.")
	expect_true("offline message", EngineSetup.describe_http_failure(HTTPRequest.RESULT_CANT_RESOLVE, 0).contains("internet"))
	expect_true("connect message", EngineSetup.describe_http_failure(HTTPRequest.RESULT_CANT_CONNECT, 0).contains("internet"))
	expect_true("tls message", EngineSetup.describe_http_failure(HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, 0).contains("secure"))
	expect_true("disk message", EngineSetup.describe_http_failure(HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, 0).contains("disk"))
	expect_true("other failures are reported", EngineSetup.describe_http_failure(HTTPRequest.RESULT_TIMEOUT, 0) != "")


func _candidates() -> void:
	var list := EngineSetup.candidates("C:/apps/neochess", "C:/proj/bin")
	expect("candidate count", list.size(), 4)
	expect("dev copy first", list[0], "C:/proj/bin/stockfish.exe")
	expect("beside the exe second", list[1], "C:/apps/neochess/stockfish.exe")
	expect("downloaded copy last", list[3], EngineSetup.install_path())
	expect("nothing exists", EngineSetup.first_existing(PackedStringArray(["C:/nope/a.exe", "C:/nope/b.exe"])), "")
	var real := work.path_join("present.exe")
	_write_file(real, PackedByteArray([1, 2, 3]))
	expect("first existing wins", EngineSetup.first_existing(PackedStringArray(["C:/nope/a.exe", real, "C:/nope/b.exe"])), real)


func _extraction() -> void:
	var good := work.path_join("good.zip")
	_make_zip(good, {
		"stockfish/": PackedByteArray(),
		"stockfish/stockfish-windows-x86-64-universal.exe": _fake_exe(1100000),
		"stockfish/Copying.txt": "GPL text".to_utf8_buffer(),
		"stockfish/AUTHORS": "people".to_utf8_buffer(),
		"stockfish/README.md": "ignore me".to_utf8_buffer(),
		"stockfish/src/AUTHORS": "nested".to_utf8_buffer(),
	})
	var out := work.path_join("good_out")
	var result := EngineSetup.extract(good, out)
	expect("extract ok", bool(result["ok"]), true)
	expect("extract path", str(result["path"]), out.path_join("stockfish.exe"))
	expect("exe written", FileAccess.file_exists(out.path_join("stockfish.exe")), true)
	expect("exe size", FileAccess.open(out.path_join("stockfish.exe"), FileAccess.READ).get_length(), 1100000)
	expect("license copied", FileAccess.get_file_as_string(out.path_join("Copying.txt")), "GPL text")
	expect("authors copied", FileAccess.get_file_as_string(out.path_join("AUTHORS")), "people")
	expect("readme skipped", FileAccess.file_exists(out.path_join("README.md")), false)
	expect("looks like an exe", EngineSetup.looks_like_windows_exe(out.path_join("stockfish.exe")), true)

	var bad_zip := work.path_join("bad.zip")
	_write_file(bad_zip, "this is not a zip".to_utf8_buffer())
	var invalid := EngineSetup.extract(bad_zip, work.path_join("bad_out"))
	expect("invalid archive fails", bool(invalid["ok"]), false)
	expect_true("invalid archive explains", str(invalid["error"]).contains("zip"))

	var empty := work.path_join("empty.zip")
	_make_zip(empty, {"readme.txt": "hi".to_utf8_buffer()})
	var no_exe := EngineSetup.extract(empty, work.path_join("empty_out"))
	expect("no engine in archive", bool(no_exe["ok"]), false)
	expect_true("no engine explains", str(no_exe["error"]).contains("Stockfish"))

	var wrong := work.path_join("wrong.zip")
	_make_zip(wrong, {"stockfish.exe": "plain text, not a program".repeat(60000).to_utf8_buffer()})
	var fake := EngineSetup.extract(wrong, work.path_join("wrong_out"))
	expect("non program rejected", bool(fake["ok"]), false)
	expect("rejected file removed", FileAccess.file_exists(work.path_join("wrong_out").path_join("stockfish.exe")), false)

	var tiny := work.path_join("tiny.exe")
	_write_file(tiny, _fake_exe(100))
	expect("tiny file rejected", EngineSetup.looks_like_windows_exe(tiny), false)
	expect("tiny file allowed with a lower limit", EngineSetup.looks_like_windows_exe(tiny, 50), true)
	expect("missing file", EngineSetup.looks_like_windows_exe(work.path_join("none.exe")), false)
	expect("missing program does not run", EngineSetup.runs(work.path_join("none.exe")), false)

	var bundled := ProjectSettings.globalize_path("res://bin/stockfish.exe")
	if FileAccess.file_exists(bundled):
		expect("real stockfish runs", EngineSetup.runs(bundled), true)
	else:
		skip("real stockfish runs (bin/stockfish.exe not present)")


func _cleanup() -> void:
	_remove_tree(work)


func _fake_exe(size: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(size)
	data[0] = 0x4D
	data[1] = 0x5A
	return data


func _make_zip(path: String, files: Dictionary) -> void:
	var packer := ZIPPacker.new()
	packer.open(path)
	for name in files:
		packer.start_file(str(name))
		packer.write_file(files[name] as PackedByteArray)
		packer.close_file()
	packer.close()


func _write_file(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()


func _remove_tree(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for folder in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(folder))
	DirAccess.remove_absolute(path)
