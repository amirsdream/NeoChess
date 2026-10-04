extends "res://tests/test_base.gd"

# Covers the Leela Chess Zero (lc0) download helpers without touching the
# network. A real engine run happens only when NEOCHESS_LC0 points to an lc0
# program (and NEOCHESS_LC0_NET to a network); otherwise it is skipped.

const Rules = preload("res://scripts/chess_game.gd")

var work := ""
var seen := {}


func run() -> void:
	work = OS.get_user_data_dir().path_join("test_leela")
	DirAccess.make_dir_recursive_absolute(work)
	_constants()
	_candidates()
	_entries()
	_extraction()
	_network_files()
	_http_messages()
	_settings()
	await _in_the_app()
	await _real_engine()
	_remove_tree(work)


func _constants() -> void:
	expect("release base is https", LeelaSetup.RELEASE_BASE.begins_with("https://github.com/LeelaChessZero/lc0/releases/download/"), true)
	expect("base names the release", LeelaSetup.RELEASE_BASE.contains("v" + LeelaSetup.VERSION), true)
	expect("release page names the release", LeelaSetup.RELEASE_PAGE.ends_with("v" + LeelaSetup.VERSION), true)
	expect("network comes from the project server", LeelaSetup.NETWORK_URL.begins_with("https://storage.lczero.org/"), true)
	expect("network url ends with the file", LeelaSetup.NETWORK_URL.ends_with(LeelaSetup.NETWORK_FILE), true)
	expect("windows asset", LeelaSetup.asset_name("windows", "x86_64"), "lc0-v%s-windows-onnx-dml.zip" % LeelaSetup.VERSION)
	expect("no windows arm build", LeelaSetup.asset_name("windows", "arm64"), "")
	expect("no linux download", LeelaSetup.asset_name("linux", "x86_64"), "")
	expect("no macos download", LeelaSetup.asset_name("macos", "arm64"), "")
	expect("supported on windows", LeelaSetup.is_supported("windows", "x86_64"), true)
	expect("not supported on linux", LeelaSetup.is_supported("linux", "x86_64"), false)
	expect("url ends with the asset", LeelaSetup.download_url("windows", "x86_64").ends_with("windows-onnx-dml.zip"), true)
	expect("url starts at the release", LeelaSetup.download_url("windows", "x86_64").begins_with(LeelaSetup.RELEASE_BASE), true)
	expect("no url when unsupported", LeelaSetup.download_url("linux", "x86_64"), "")
	expect("windows exe name", LeelaSetup.exe_name("windows"), "lc0.exe")
	expect("linux exe name", LeelaSetup.exe_name("linux"), "lc0")
	expect("installs in its own folder", LeelaSetup.install_dir(), EngineSetup.install_dir().path_join("leela"))
	expect("install path", LeelaSetup.install_path("windows"), LeelaSetup.install_dir().path_join("lc0.exe"))
	expect("network beside the engine", LeelaSetup.network_path().get_base_dir(), LeelaSetup.install_dir())
	expect("archive beside the engine", LeelaSetup.archive_path().get_base_dir(), LeelaSetup.install_dir())
	expect("backend is the DirectX one", LeelaSetup.BACKEND, "onnx-dml")


func _candidates() -> void:
	var list := LeelaSetup.candidates("C:/apps/neochess", "C:/proj/bin", "windows")
	expect("candidate count", list.size(), 4)
	expect("dev copy first", list[0], "C:/proj/bin/lc0.exe")
	expect("beside the exe second", list[1], "C:/apps/neochess/lc0.exe")
	expect("downloaded copy last", list[3], LeelaSetup.install_path("windows"))
	var unix := LeelaSetup.candidates("/opt/neochess", "/home/me/proj/bin", "linux")
	expect("unix beside the program", unix[1], "/opt/neochess/lc0")
	expect("unix looks in system folders", "/usr/bin/lc0" in unix and "/usr/games/lc0" in unix, true)
	expect("unix has no exe names", "lc0.exe" in " ".join(unix), false)
	expect("windows skips system folders", "/usr/bin/lc0" in list, false)
	expect("the installed copy is recognised", LeelaSetup.is_installed_copy(LeelaSetup.install_path()), true)
	expect("another copy is not", LeelaSetup.is_installed_copy("C:/other/lc0.exe"), false)
	expect("empty is not", LeelaSetup.is_installed_copy(""), false)


func _entries() -> void:
	var release := PackedStringArray([
		"791556.pb.gz", "COPYING", "install.cmd", "lc0.exe", "mimalloc-override.dll", "onnxruntime.dll",
		"README.txt", "sub/", "sub/other.dll", "a/b/deep.dll", "../escape.dll",
	])
	var kept := LeelaSetup.installable_entries(release)
	expect("keeps the program", "lc0.exe" in kept, true)
	expect("keeps libraries", "onnxruntime.dll" in kept and "mimalloc-override.dll" in kept, true)
	expect("keeps licenses", "COPYING" in kept, true)
	expect("keeps one folder level", "sub/other.dll" in kept, true)
	expect("skips the sample network", "791556.pb.gz" in kept, false)
	expect("skips install scripts", "install.cmd" in kept, false)
	expect("skips folders", "sub/" in kept, false)
	expect("skips deep files", "a/b/deep.dll" in kept, false)
	expect("skips path escapes", "../escape.dll" in kept, false)


func _extraction() -> void:
	var good := work.path_join("good.zip")
	_make_zip(good, {
		"lc0.exe": _fake_exe(1500000),
		"onnxruntime.dll": _fake_exe(2000),
		"COPYING": "GPL".to_utf8_buffer(),
		"install.cmd": "echo hi".to_utf8_buffer(),
		"791556.pb.gz": "sample".to_utf8_buffer(),
	})
	var out := work.path_join("good_out")
	var result := LeelaSetup.extract(good, out)
	expect("extract ok", bool(result["ok"]), true)
	expect("extract path", str(result["path"]), out.path_join("lc0.exe"))
	expect("program written", FileAccess.file_exists(out.path_join("lc0.exe")), true)
	expect("library written", FileAccess.file_exists(out.path_join("onnxruntime.dll")), true)
	expect("license written", FileAccess.get_file_as_string(out.path_join("COPYING")), "GPL")
	expect("script not written", FileAccess.file_exists(out.path_join("install.cmd")), false)
	expect("sample network not written", FileAccess.file_exists(out.path_join("791556.pb.gz")), false)

	var bad := work.path_join("bad.zip")
	_write_file(bad, "this is not a zip".to_utf8_buffer())
	var invalid := LeelaSetup.extract(bad, work.path_join("bad_out"))
	expect("invalid archive fails", bool(invalid["ok"]), false)
	expect_true("invalid archive explains", str(invalid["error"]).contains("zip"))

	var partial := work.path_join("partial.zip")
	_make_zip(partial, {"lc0.exe": _fake_exe(1500000)})
	var incomplete := LeelaSetup.extract(partial, work.path_join("partial_out"))
	expect("missing library fails", bool(incomplete["ok"]), false)
	expect_true("missing library is named", str(incomplete["error"]).contains("onnxruntime.dll"))

	var wrong := work.path_join("wrong.zip")
	_make_zip(wrong, {"lc0.exe": "plain text, not a program".repeat(80000).to_utf8_buffer(), "onnxruntime.dll": _fake_exe(2000)})
	var fake := LeelaSetup.extract(wrong, work.path_join("wrong_out"))
	expect("non program rejected", bool(fake["ok"]), false)
	expect("rejected file removed", FileAccess.file_exists(work.path_join("wrong_out").path_join("lc0.exe")), false)
	expect("missing program does not run", LeelaSetup.runs(work.path_join("none.exe")), false)


func _network_files() -> void:
	var good := work.path_join("net.pb.gz")
	var data := PackedByteArray()
	data.resize(2000000)
	data[0] = 0x1F
	data[1] = 0x8B
	_write_file(good, data)
	expect("a gzip file of some size is a network", LeelaSetup.looks_like_network(good), true)
	var tiny := work.path_join("tiny.pb.gz")
	_write_file(tiny, PackedByteArray([0x1F, 0x8B, 1, 2, 3]))
	expect("a tiny file is not", LeelaSetup.looks_like_network(tiny), false)
	var html := work.path_join("error.pb.gz")
	_write_file(html, "<html>error</html>".repeat(200000).to_utf8_buffer())
	expect("an error page is not", LeelaSetup.looks_like_network(html), false)
	expect("a missing file is not", LeelaSetup.looks_like_network(work.path_join("none.pb.gz")), false)


func _http_messages() -> void:
	expect("success", LeelaSetup.describe_http_failure(HTTPRequest.RESULT_SUCCESS, 200), "")
	expect("not found names the host", LeelaSetup.describe_http_failure(HTTPRequest.RESULT_SUCCESS, 404), "GitHub answered with HTTP 404.")
	expect("other host", LeelaSetup.describe_http_failure(HTTPRequest.RESULT_SUCCESS, 503, "the Leela Chess Zero server"), "the Leela Chess Zero server answered with HTTP 503.")
	expect_true("offline message", LeelaSetup.describe_http_failure(HTTPRequest.RESULT_CANT_RESOLVE, 0).contains("internet"))
	expect_true("tls message", LeelaSetup.describe_http_failure(HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, 0).contains("secure"))
	expect_true("disk message", LeelaSetup.describe_http_failure(HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR, 0).contains("disk"))


func _settings() -> void:
	expect("another copy gets no settings", LeelaSetup.uci_settings("C:/other/lc0.exe").size(), 0)
	var mine := LeelaSetup.uci_settings(LeelaSetup.install_path())
	expect("the installed copy gets the backend", mine.get("Backend"), "onnx-dml")
	expect("the weights follow the network file", mine.has("WeightsFile"), LeelaSetup.has_network())

	var settings := StockfishUci.engine_settings({"overhead": 45, "multipv": 3, "threads": 2})
	expect("overhead for lc0", settings["MoveOverheadMs"], 45)
	expect("overhead for stockfish", settings["Move Overhead"], 45)


func _real_engine() -> void:
	var exe := OS.get_environment("NEOCHESS_LC0")
	var net := OS.get_environment("NEOCHESS_LC0_NET")
	if exe == "" or not FileAccess.file_exists(exe):
		skip("real lc0 run (set NEOCHESS_LC0 and NEOCHESS_LC0_NET to enable)")
		return
	seen = {"started": "", "failed": "", "best": [], "infos": []}
	expect("the real program runs", LeelaSetup.runs(exe), true)
	var engine := UciEngine.new()
	root.add_child(engine)
	engine.started.connect(func(n: String) -> void: seen["started"] = n)
	engine.failed.connect(func(m: String) -> void: seen["failed"] = m)
	engine.best_move.connect(func(m: String) -> void: (seen["best"] as Array).append(m))
	engine.info.connect(func(e: Dictionary) -> void: (seen["infos"] as Array).append(e))
	expect("lc0 launches", engine.start(exe), true)
	var ready := await _until(func() -> bool: return engine.state == UciEngine.State.IDLE, 20000)
	expect("handshake finishes", ready, true)
	expect_true("reports its name", String(seen["started"]).to_lower().contains("lc0"), "(%s)" % seen["started"])
	expect("knows the backend option", engine.has_option("Backend"), true)
	expect("knows the weights option", engine.has_option("WeightsFile"), true)
	expect("knows multipv", engine.has_option("MultiPV"), true)
	expect("does not have a skill level", engine.has_option("Skill Level"), false)

	var settings := StockfishUci.engine_settings({"multipv": 3, "threads": 2, "overhead": 30})
	settings["Backend"] = LeelaSetup.BACKEND
	if net != "":
		settings["WeightsFile"] = net
	var game := Rules.new()
	engine.search(game.to_fen(), {"movetime": 1500}, settings)
	var done := await _until(func() -> bool: return not (seen["best"] as Array).is_empty(), 120000)
	expect("search answers", done, true)
	expect("no failure", String(seen["failed"]), "")
	var uci := String((seen["best"] as Array)[0]) if done else ""
	expect_true("opening move is legal", not game.match_uci(uci).is_empty(), "(got '%s')" % uci)
	var lines := {}
	for entry in seen["infos"] as Array:
		lines[int((entry as Dictionary)["n"])] = true
	expect_true("three lines came back", lines.size() >= 3, "(%d)" % lines.size())
	var last: Dictionary = (seen["infos"] as Array).back()
	print("lc0 reached %d nodes at %s, move %s" % [int(last["nodes"]), StockfishUci.format_nodes_per_second(int(last["nps"])), uci])
	engine.shutdown()
	engine.queue_free()
	await process_frame


# Switching the engine in the real app changes the wording and the controls.
func _in_the_app() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate() as Control
	root.add_child(main)
	await process_frame
	await process_frame
	expect("starts with stockfish", main.engine_kind, "stockfish")
	expect("the choice lists both", main.kind_opt.item_count, 2)
	expect("stockfish download text", main.engine_download_btn.text.begins_with("Download Stockfish"), true)
	expect("stockfish opponent", main.mode_opt.get_item_text(0), "Versus Stockfish")
	expect("levels are editable", main.skill_slider.editable, true)

	main.kind_opt.select(1)
	main._on_kind_selected(1)
	await process_frame
	expect("leela is chosen", main.engine_kind, "leela")
	expect("leela download text", main.engine_download_btn.text.begins_with("Download Leela"), true)
	expect("leela card title", main.setup_title.text.begins_with("Leela"), true)
	expect("leela link", main.setup_link.uri, LeelaSetup.RELEASE_PAGE)
	expect("leela opponent", main.mode_opt.get_item_text(0), "Versus Leela")
	expect("levels are locked", main.skill_slider.editable, false)
	expect("elo cap is locked", main.limit_check.disabled, true)
	expect("engine name for messages", main._engine_title(), "Leela")
	expect("leela uses at least two threads", int(main._engine_options()["threads"]), 2)
	expect("the right installer is used", main._active_installer() == main.installer, true)
	main.installing_kind = "leela"
	expect("leela installer for leela", main._active_installer() == main.leela_installer, true)

	main.kind_opt.select(0)
	main._on_kind_selected(0)
	await process_frame
	expect("back to stockfish", main.engine_kind, "stockfish")
	expect("levels are editable again", main.skill_slider.editable, true)
	main.queue_free()
	await process_frame


func _until(condition: Callable, timeout_ms: int = 15000) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout_ms:
		if condition.call():
			return true
		await process_frame
		OS.delay_msec(5)
	return condition.call()


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
