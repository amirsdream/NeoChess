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
	_tar()
	_headers()
	_cleanup()


func _constants() -> void:
	expect("release base is https", EngineSetup.RELEASE_BASE.begins_with("https://github.com/official-stockfish/Stockfish/releases/download/"), true)
	expect("base names the release", EngineSetup.RELEASE_BASE.contains("sf_" + EngineSetup.VERSION), true)
	expect("release page", EngineSetup.RELEASE_PAGE.contains("sf_" + EngineSetup.VERSION), true)

	expect("windows asset", EngineSetup.asset_name("windows", "x86_64"), "stockfish-windows-x86-64-universal.zip")
	expect("windows arm asset", EngineSetup.asset_name("windows", "arm64"), "stockfish-windows-arm64-universal.zip")
	expect("linux asset", EngineSetup.asset_name("linux", "x86_64"), "stockfish-linux-x86-64-universal.tar.gz")
	expect("linux arm asset", EngineSetup.asset_name("linux", "arm64"), "stockfish-linux-arm64-universal.tar.gz")
	expect("linux riscv asset", EngineSetup.asset_name("linux", "riscv64"), "stockfish-linux-riscv64-universal.tar.gz")
	expect("macos asset (either chip)", EngineSetup.asset_name("macos", "arm64"), "stockfish-macos-universal.tar.gz")
	expect("macos intel asset", EngineSetup.asset_name("macos", "x86_64"), "stockfish-macos-universal.tar.gz")
	expect("unknown cpu", EngineSetup.asset_name("linux", "mips"), "")
	expect("unsupported", EngineSetup.is_supported("linux", "mips"), false)
	expect("supported", EngineSetup.is_supported("windows", "x86_64"), true)
	expect("url ends with the asset", EngineSetup.download_url("linux", "x86_64").ends_with("stockfish-linux-x86-64-universal.tar.gz"), true)
	expect("url starts at the release", EngineSetup.download_url("macos", "arm64").begins_with(EngineSetup.RELEASE_BASE), true)
	expect("no url when unsupported", EngineSetup.download_url("linux", "mips"), "")

	expect("windows exe name", EngineSetup.exe_name("windows"), "stockfish.exe")
	expect("linux exe name", EngineSetup.exe_name("linux"), "stockfish")
	expect("macos exe name", EngineSetup.exe_name("macos"), "stockfish")
	expect("this platform is known", EngineSetup.platform() in ["windows", "linux", "macos"], true)
	expect("install path is in the engine folder", EngineSetup.install_path("linux").ends_with("engine/stockfish"), true)
	expect("windows install path", EngineSetup.install_path("windows").ends_with("engine/stockfish.exe"), true)
	expect("tar archive name", EngineSetup.archive_path("linux", "x86_64").ends_with(".tar.gz"), true)
	expect("zip archive name", EngineSetup.archive_path("windows", "x86_64").ends_with(".zip"), true)
	expect("archive lives beside the install", EngineSetup.archive_path("linux", "x86_64").get_base_dir(), EngineSetup.install_dir())

func _picking() -> void:
	var release := PackedStringArray([
		"stockfish/",
		"stockfish/AUTHORS",
		"stockfish/Copying.txt",
		"stockfish/src/stockfish.cpp",
		"stockfish/stockfish-windows-x86-64-universal.exe",
	])
	expect("picks the exe", EngineSetup.pick_executable(release, "windows"), "stockfish/stockfish-windows-x86-64-universal.exe")
	expect("no exe", EngineSetup.pick_executable(PackedStringArray(["a.txt", "b/"]), "windows"), "")
	expect("empty archive", EngineSetup.pick_executable(PackedStringArray(), "windows"), "")
	expect("ignores other programs", EngineSetup.pick_executable(PackedStringArray(["tools/helper.exe"]), "windows"), "")
	var nested := PackedStringArray(["deep/er/stockfish-old.exe", "stockfish.exe"])
	expect("prefers the shallowest", EngineSetup.pick_executable(nested, "windows"), "stockfish.exe")
	expect("case is ignored", EngineSetup.pick_executable(PackedStringArray(["Stockfish/Stockfish.EXE"]), "windows"), "Stockfish/Stockfish.EXE")
	expect("folders are ignored", EngineSetup.pick_executable(PackedStringArray(["stockfish.exe/"]), "windows"), "")

	var unix := PackedStringArray([
		"stockfish/",
		"stockfish/AUTHORS",
		"stockfish/Copying.txt",
		"stockfish/src/stockfish.cpp",
		"stockfish/stockfish-ubuntu-x86-64-avx2",
	])
	expect("unix build has no extension", EngineSetup.pick_executable(unix, "linux"), "stockfish/stockfish-ubuntu-x86-64-avx2")
	expect("macos too", EngineSetup.pick_executable(unix, "macos"), "stockfish/stockfish-ubuntu-x86-64-avx2")
	expect("unix ignores sources", EngineSetup.pick_executable(PackedStringArray(["stockfish/src/stockfish.cpp"]), "linux"), "")
	expect("unix ignores exe files", EngineSetup.pick_executable(PackedStringArray(["stockfish.exe"]), "linux"), "")
	expect("windows ignores unix builds", EngineSetup.pick_executable(unix, "windows"), "")
	expect("unix prefers the shallowest", EngineSetup.pick_executable(PackedStringArray(["a/b/stockfish-old", "stockfish"]), "linux"), "stockfish")


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
	var list := EngineSetup.candidates("C:/apps/neochess", "C:/proj/bin", "windows")
	expect("candidate count", list.size(), 4)
	expect("dev copy first", list[0], "C:/proj/bin/stockfish.exe")
	expect("beside the exe second", list[1], "C:/apps/neochess/stockfish.exe")
	expect("downloaded copy last", list[3], EngineSetup.install_path("windows"))

	var unix := EngineSetup.candidates("/opt/neochess", "/home/me/proj/bin", "linux")
	expect("unix dev copy first", unix[0], "/home/me/proj/bin/stockfish")
	expect("unix beside the program", unix[1], "/opt/neochess/stockfish")
	expect("unix downloaded copy", unix[3], EngineSetup.install_path("linux"))
	expect("unix looks in system folders", "/usr/games/stockfish" in unix and "/usr/bin/stockfish" in unix, true)
	expect("unix has no exe names", "stockfish.exe" in " ".join(unix), false)
	expect("macos checks homebrew", "/opt/homebrew/bin/stockfish" in EngineSetup.candidates("/a", "/b", "macos"), true)
	expect("windows skips system folders", "/usr/bin/stockfish" in list, false)
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
	var result := EngineSetup.extract(good, out, "windows")
	expect("extract ok", bool(result["ok"]), true)
	expect("extract path", str(result["path"]), out.path_join("stockfish.exe"))
	expect("exe written", FileAccess.file_exists(out.path_join("stockfish.exe")), true)
	expect("exe size", FileAccess.open(out.path_join("stockfish.exe"), FileAccess.READ).get_length(), 1100000)
	expect("license copied", FileAccess.get_file_as_string(out.path_join("Copying.txt")), "GPL text")
	expect("authors copied", FileAccess.get_file_as_string(out.path_join("AUTHORS")), "people")
	expect("readme skipped", FileAccess.file_exists(out.path_join("README.md")), false)
	expect("looks like an exe", EngineSetup.looks_like_executable(out.path_join("stockfish.exe"), "windows"), true)

	var bad_zip := work.path_join("bad.zip")
	_write_file(bad_zip, "this is not a zip".to_utf8_buffer())
	var invalid := EngineSetup.extract(bad_zip, work.path_join("bad_out"), "windows")
	expect("invalid archive fails", bool(invalid["ok"]), false)
	expect_true("invalid archive explains", str(invalid["error"]).contains("zip"))

	var empty := work.path_join("empty.zip")
	_make_zip(empty, {"readme.txt": "hi".to_utf8_buffer()})
	var no_exe := EngineSetup.extract(empty, work.path_join("empty_out"), "windows")
	expect("no engine in archive", bool(no_exe["ok"]), false)
	expect_true("no engine explains", str(no_exe["error"]).contains("Stockfish"))

	var wrong := work.path_join("wrong.zip")
	_make_zip(wrong, {"stockfish.exe": "plain text, not a program".repeat(60000).to_utf8_buffer()})
	var fake := EngineSetup.extract(wrong, work.path_join("wrong_out"), "windows")
	expect("non program rejected", bool(fake["ok"]), false)
	expect("rejected file removed", FileAccess.file_exists(work.path_join("wrong_out").path_join("stockfish.exe")), false)

	var tiny := work.path_join("tiny.exe")
	_write_file(tiny, _fake_exe(100))
	expect("tiny file rejected", EngineSetup.looks_like_executable(tiny, "windows"), false)
	expect("tiny file allowed with a lower limit", EngineSetup.looks_like_executable(tiny, "windows", 50), true)
	expect("missing file", EngineSetup.looks_like_executable(work.path_join("none.exe"), "windows"), false)
	expect("missing program does not run", EngineSetup.runs(work.path_join("none.exe")), false)

	var bundled := ProjectSettings.globalize_path("res://bin/stockfish.exe")
	if FileAccess.file_exists(bundled):
		expect("real stockfish runs", EngineSetup.runs(bundled), true)
	else:
		skip("real stockfish runs (bin/stockfish.exe not present)")


func _tar() -> void:
	var elf := _fake_elf(1100000)
	var files := [
		{"name": "stockfish/", "type": 53},
		{"name": "stockfish/stockfish-ubuntu-x86-64-avx2", "data": elf},
		{"name": "stockfish/Copying.txt", "data": "GPL text".to_utf8_buffer()},
		{"name": "stockfish/AUTHORS", "data": "people".to_utf8_buffer()},
		{"name": "stockfish/src/AUTHORS", "data": "nested".to_utf8_buffer()},
		{"name": "stockfish/README.md", "data": "ignore me".to_utf8_buffer()},
	]
	var tar := _make_tar(files)
	var listing := EngineSetup.tar_entries(tar)
	expect("tar entry count", listing.size(), 6)
	expect("tar folder", int(listing[0]["type"]), 53)
	expect("tar folder name", str(listing[0]["name"]), "stockfish")
	expect("tar file name", str(listing[1]["name"]), "stockfish/stockfish-ubuntu-x86-64-avx2")
	expect("tar file type", int(listing[1]["type"]), 48)
	expect("tar file size", int(listing[1]["size"]), 1100000)
	var first := int(listing[1]["offset"])
	expect("tar file data starts with ELF", tar.slice(first, first + 4), PackedByteArray([0x7F, 0x45, 0x4C, 0x46]))
	expect("tar data of a small file", tar.slice(int(listing[2]["offset"]), int(listing[2]["offset"]) + 8).get_string_from_utf8(), "GPL text")
	expect("empty archive", EngineSetup.tar_entries(PackedByteArray()).size(), 0)
	expect("zero blocks only", EngineSetup.tar_entries(_zeros(2048)).size(), 0)

	# Names longer than 100 characters, the three ways tar stores them.
	var deep := "stockfish/" + "very_long_folder_name/".repeat(6) + "stockfish-ubuntu-x86-64-avx2"
	var gnu := EngineSetup.tar_entries(_make_tar([{"name": deep, "data": "x".to_utf8_buffer(), "long": "gnu"}]))
	expect("gnu long name", gnu.size() > 0 and str(gnu[0]["name"]) == deep, true)
	var pax := EngineSetup.tar_entries(_make_tar([{"name": deep, "data": "x".to_utf8_buffer(), "long": "pax"}]))
	expect("pax long name", pax.size() > 0 and str(pax[0]["name"]) == deep, true)
	var split := EngineSetup.tar_entries(_make_tar([{"name": deep, "data": "x".to_utf8_buffer(), "long": "prefix"}]))
	expect("ustar prefix name", split.size() > 0 and str(split[0]["name"]) == deep, true)

	# Whole archives, as downloaded: gzip around a tar.
	var good := work.path_join("good.tar.gz")
	_write_file(good, tar.compress(FileAccess.COMPRESSION_GZIP))
	var out := work.path_join("tar_out")
	var result := EngineSetup.extract(good, out, "linux")
	expect("tar.gz extracts", bool(result["ok"]), true)
	expect("tar.gz path", str(result["path"]), out.path_join("stockfish"))
	expect("engine written", FileAccess.get_file_as_bytes(out.path_join("stockfish")).size(), 1100000)
	expect("engine is an ELF file", EngineSetup.looks_like_executable(out.path_join("stockfish"), "linux"), true)
	expect("license copied", FileAccess.get_file_as_string(out.path_join("Copying.txt")), "GPL text")
	expect("authors copied", FileAccess.get_file_as_string(out.path_join("AUTHORS")), "people")
	expect("nested files skipped", FileAccess.get_file_as_string(out.path_join("AUTHORS")) != "nested", true)
	expect("readme skipped", FileAccess.file_exists(out.path_join("README.md")), false)
	if OS.get_name() != "Windows":
		expect("engine is executable", FileAccess.get_unix_permissions(out.path_join("stockfish")) & FileAccess.UNIX_EXECUTE_OWNER != 0, true)

	var tgz := work.path_join("good.tgz")
	_write_file(tgz, tar.compress(FileAccess.COMPRESSION_GZIP))
	expect("tgz extension works", bool(EngineSetup.extract(tgz, work.path_join("tgz_out"), "linux")["ok"]), true)

	var junk := work.path_join("junk.tar.gz")
	_write_file(junk, "this is not gzip data at all".to_utf8_buffer())
	var bad := EngineSetup.extract(junk, work.path_join("junk_out"), "linux")
	expect("garbage fails", bool(bad["ok"]), false)
	expect_true("garbage explains", str(bad["error"]).to_lower().contains("gzip"))
	expect("missing archive fails", bool(EngineSetup.extract(work.path_join("none.tar.gz"), work.path_join("none_out"), "linux")["ok"]), false)

	var no_exe := work.path_join("noexe.tar.gz")
	_write_file(no_exe, _make_tar([{"name": "readme.txt", "data": "hi".to_utf8_buffer()}]).compress(FileAccess.COMPRESSION_GZIP))
	var missing := EngineSetup.extract(no_exe, work.path_join("noexe_out"), "linux")
	expect("no engine in the archive", bool(missing["ok"]), false)
	expect_true("no engine explains", str(missing["error"]).contains("Stockfish"))

	var wrong_os := EngineSetup.extract(good, work.path_join("wrong_os_out"), "macos")
	expect("linux program rejected on macos", bool(wrong_os["ok"]), false)
	expect("rejected file is removed", FileAccess.file_exists(work.path_join("wrong_os_out").path_join("stockfish")), false)

	var mac := work.path_join("mac.tar.gz")
	_write_file(mac, _make_tar([{"name": "stockfish/stockfish-macos-m1-apple-silicon", "data": _fake_macho(1100000)}]).compress(FileAccess.COMPRESSION_GZIP))
	expect("macos program accepted", bool(EngineSetup.extract(mac, work.path_join("mac_out"), "macos")["ok"]), true)


func _headers() -> void:
	expect("windows header", EngineSetup.header_matches(PackedByteArray([0x4D, 0x5A, 0, 0]), "windows"), true)
	expect("elf is not windows", EngineSetup.header_matches(PackedByteArray([0x7F, 0x45, 0x4C, 0x46]), "windows"), false)
	expect("elf header", EngineSetup.header_matches(PackedByteArray([0x7F, 0x45, 0x4C, 0x46]), "linux"), true)
	expect("exe is not elf", EngineSetup.header_matches(PackedByteArray([0x4D, 0x5A, 0, 0]), "linux"), false)
	expect("mach-o 64", EngineSetup.header_matches(PackedByteArray([0xCF, 0xFA, 0xED, 0xFE]), "macos"), true)
	expect("mach-o universal", EngineSetup.header_matches(PackedByteArray([0xCA, 0xFE, 0xBA, 0xBE]), "macos"), true)
	expect("elf is not mach-o", EngineSetup.header_matches(PackedByteArray([0x7F, 0x45, 0x4C, 0x46]), "macos"), false)
	expect("short header", EngineSetup.header_matches(PackedByteArray([0x4D]), "windows"), false)
	expect("unknown platform", EngineSetup.header_matches(PackedByteArray([0x4D, 0x5A, 0, 0]), "plan9"), false)


func _fake_elf(size: int) -> PackedByteArray:
	var data := _zeros(size)
	data[0] = 0x7F
	data[1] = 0x45
	data[2] = 0x4C
	data[3] = 0x46
	return data


func _fake_macho(size: int) -> PackedByteArray:
	var data := _zeros(size)
	data[0] = 0xCF
	data[1] = 0xFA
	data[2] = 0xED
	data[3] = 0xFE
	return data


func _zeros(size: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(size)
	return data


# Builds an uncompressed tar archive. Each item: name, optional data, optional
# type (53 for folders) and optional "long" (gnu, pax or prefix) to store a
# name that does not fit the 100 characters of a plain header.
func _make_tar(items: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for item in items:
		var name := str(item["name"])
		var data: PackedByteArray = item.get("data", PackedByteArray())
		var type := int(item.get("type", 48))
		var style := str(item.get("long", ""))
		var prefix := ""
		var short_name := name
		if style == "gnu":
			var long_bytes := name.to_utf8_buffer()
			long_bytes.append(0)
			out.append_array(_tar_block("././@LongLink", long_bytes, 76, ""))
			short_name = name.substr(0, 99)
		elif style == "pax":
			var record := " path=%s\n" % name
			var length := record.length() + str(record.length()).length() + 1
			out.append_array(_tar_block("PaxHeader", ("%d%s" % [length, record]).to_utf8_buffer(), 120, ""))
			short_name = name.substr(0, 99)
		elif style == "prefix":
			var cut := name.rfind("/", 150)
			prefix = name.substr(0, cut)
			short_name = name.substr(cut + 1)
		out.append_array(_tar_block(short_name, data, type, prefix))
	out.append_array(_zeros(1024))
	return out


func _tar_block(name: String, data: PackedByteArray, type: int, prefix: String) -> PackedByteArray:
	var header := _zeros(512)
	_put(header, 0, name.to_utf8_buffer())
	_put(header, 100, "0000644".to_utf8_buffer())
	_put(header, 124, ("%011o" % data.size()).to_utf8_buffer())
	header[156] = type
	_put(header, 257, "ustar".to_utf8_buffer())
	_put(header, 263, "00".to_utf8_buffer())
	_put(header, 345, prefix.to_utf8_buffer())
	var out := header
	out.append_array(data)
	var padding := (512 - data.size() % 512) % 512
	out.append_array(_zeros(padding))
	return out


func _put(target: PackedByteArray, at: int, bytes: PackedByteArray) -> void:
	for i in bytes.size():
		target[at + i] = bytes[i]


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
