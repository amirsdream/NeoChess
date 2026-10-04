class_name EngineSetup
extends RefCounted

# Helpers for finding, downloading and installing the Stockfish engine.
# Stockfish is GPLv3 and is not stored in this repository. NeoChess downloads
# the official build for the current platform from the Stockfish GitHub release
# on request. Windows, Linux and macOS are supported.

const VERSION := "19"
const RELEASE_BASE := "https://github.com/official-stockfish/Stockfish/releases/download/sf_19/"
const RELEASE_PAGE := "https://github.com/official-stockfish/Stockfish/releases/tag/sf_19"
const LICENSE_FILES := ["Copying.txt", "AUTHORS"]
const MIN_EXE_BYTES := 1000000
const POSIX_SYSTEM_PATHS := [
	"/usr/games/stockfish",
	"/usr/bin/stockfish",
	"/usr/local/bin/stockfish",
	"/opt/homebrew/bin/stockfish",
	"/snap/bin/stockfish",
]


# "windows", "linux" or "macos". Other Unix systems count as "linux".
static func platform() -> String:
	match OS.get_name():
		"Windows", "UWP":
			return "windows"
		"macOS":
			return "macos"
		_:
			return "linux"


# "x86_64", "arm64", "riscv64" and so on (Godot's names).
static func architecture() -> String:
	return Engine.get_architecture_name()


static func exe_name(plat: String = "") -> String:
	return "stockfish.exe" if (plat if plat != "" else platform()) == "windows" else "stockfish"


# The release file for a platform, or "" when Stockfish publishes none.
static func asset_name(plat: String = "", arch: String = "") -> String:
	var os_name := plat if plat != "" else platform()
	var cpu := arch if arch != "" else architecture()
	match os_name:
		"windows":
			if cpu == "arm64":
				return "stockfish-windows-arm64-universal.zip"
			if cpu == "x86_64":
				return "stockfish-windows-x86-64-universal.zip"
		"linux":
			if cpu == "arm64":
				return "stockfish-linux-arm64-universal.tar.gz"
			if cpu == "riscv64":
				return "stockfish-linux-riscv64-universal.tar.gz"
			if cpu == "x86_64":
				return "stockfish-linux-x86-64-universal.tar.gz"
		"macos":
			return "stockfish-macos-universal.tar.gz"
	return ""


static func download_url(plat: String = "", arch: String = "") -> String:
	var asset := asset_name(plat, arch)
	return "" if asset.is_empty() else RELEASE_BASE + asset


static func is_supported(plat: String = "", arch: String = "") -> bool:
	return not asset_name(plat, arch).is_empty()


static func install_dir() -> String:
	return OS.get_user_data_dir().path_join("engine")


static func install_path(plat: String = "") -> String:
	return install_dir().path_join(exe_name(plat))


# Where the download is saved before it is unpacked.
static func archive_path(plat: String = "", arch: String = "") -> String:
	var asset := asset_name(plat, arch)
	var extension := ".tar.gz" if asset.ends_with(".tar.gz") else ".zip"
	return install_dir().path_join("stockfish-download" + extension)


# Places NeoChess looks for an engine, best first.
static func candidates(exe_dir: String, project_bin: String, plat: String = "") -> PackedStringArray:
	var os_name := plat if plat != "" else platform()
	var name := exe_name(os_name)
	var list := PackedStringArray([
		project_bin.path_join(name),
		exe_dir.path_join(name),
		exe_dir.path_join("bin/" + name),
		install_path(os_name),
	])
	if os_name != "windows":
		list.append_array(PackedStringArray(POSIX_SYSTEM_PATHS))
	return list


static func first_existing(paths: PackedStringArray) -> String:
	for path in paths:
		if FileAccess.file_exists(path):
			return path
	return ""


# Chooses the engine executable inside a release archive: the shallowest file
# named stockfish*, with .exe on Windows and without any extension elsewhere.
static func pick_executable(entries: PackedStringArray, plat: String = "") -> String:
	var os_name := plat if plat != "" else platform()
	var best := ""
	var best_depth := 1 << 20
	for entry in entries:
		if entry.ends_with("/"):
			continue
		var name := entry.get_file().to_lower()
		if not name.begins_with("stockfish"):
			continue
		if os_name == "windows":
			if not name.ends_with(".exe"):
				continue
		elif name.contains("."):
			continue
		var depth := entry.count("/")
		if depth < best_depth:
			best = entry
			best_depth = depth
	return best


# Unpacks the engine (and its license files) from the archive into dest_dir.
# The archive is a .zip or a .tar.gz. Returns {"ok", "path", "error"}.
static func extract(archive: String, dest_dir: String, plat: String = "") -> Dictionary:
	if archive.ends_with(".tar.gz") or archive.ends_with(".tgz"):
		return _extract_tar_gz(archive, dest_dir, plat)
	return _extract_zip(archive, dest_dir, plat)


static func _extract_zip(zip_file: String, dest_dir: String, plat: String) -> Dictionary:
	var os_name := plat if plat != "" else platform()
	var reader := ZIPReader.new()
	if reader.open(zip_file) != OK:
		return _fail("The downloaded file is not a valid zip archive.")
	var entries := reader.get_files()
	var exe_entry := pick_executable(entries, os_name)
	if exe_entry.is_empty():
		reader.close()
		return _fail("The archive does not contain a Stockfish executable.")
	if DirAccess.make_dir_recursive_absolute(dest_dir) != OK:
		reader.close()
		return _fail("Could not create the install folder.")
	var target := dest_dir.path_join(exe_name(os_name))
	if not _write(target, reader.read_file(exe_entry)):
		reader.close()
		return _fail("Could not write the engine file.")
	for entry in entries:
		if entry.ends_with("/") or entry.count("/") > 1:
			continue
		if entry.get_file() in LICENSE_FILES:
			_write(dest_dir.path_join(entry.get_file()), reader.read_file(entry))
	reader.close()
	return _finish_install(target, os_name)


static func _extract_tar_gz(archive: String, dest_dir: String, plat: String) -> Dictionary:
	var os_name := plat if plat != "" else platform()
	var packed := FileAccess.get_file_as_bytes(archive)
	if packed.is_empty():
		return _fail("The downloaded file could not be read.")
	if packed.size() < 18 or packed[0] != 0x1F or packed[1] != 0x8B:
		return _fail("The downloaded file is not a valid gzip archive.")
	var data := packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	packed = PackedByteArray()
	if data.is_empty():
		return _fail("The downloaded file is not a valid gzip archive.")
	var entries := tar_entries(data)
	var names := PackedStringArray()
	for entry in entries:
		names.append(str(entry["name"]) + ("/" if int(entry["type"]) == 53 else ""))
	var exe_entry := pick_executable(names, os_name)
	if exe_entry.is_empty():
		return _fail("The archive does not contain a Stockfish executable.")
	if DirAccess.make_dir_recursive_absolute(dest_dir) != OK:
		return _fail("Could not create the install folder.")
	var target := dest_dir.path_join(exe_name(os_name))
	var written := false
	for entry in entries:
		var entry_name := str(entry["name"])
		if entry_name == exe_entry:
			var start := int(entry["offset"])
			written = _write(target, data.slice(start, start + int(entry["size"])))
		elif entry_name.get_file() in LICENSE_FILES and entry_name.count("/") <= 1:
			var begin := int(entry["offset"])
			_write(dest_dir.path_join(entry_name.get_file()), data.slice(begin, begin + int(entry["size"])))
	if not written:
		return _fail("Could not write the engine file.")
	return _finish_install(target, os_name)


static func _finish_install(target: String, os_name: String) -> Dictionary:
	if not looks_like_executable(target, os_name):
		DirAccess.remove_absolute(target)
		return _fail("The extracted file is not a %s program." % {"windows": "Windows", "linux": "Linux", "macos": "macOS"}.get(os_name, "valid"))
	make_executable(target)
	return {"ok": true, "path": target, "error": ""}


# Lists the files in an uncompressed tar archive (ustar, GNU long names and
# pax path records). Each entry: name, size, type (the type flag as a number,
# 48 is a file and 53 a folder) and offset of its data inside the archive.
static func tar_entries(data: PackedByteArray) -> Array:
	var entries: Array = []
	var pos := 0
	var long_name := ""
	while pos + 512 <= data.size():
		if data[pos] == 0 and _tar_text(data, pos, 100) == "":
			break
		var name := _tar_text(data, pos, 100)
		var size := _tar_number(data, pos + 124, 12)
		var type := int(data[pos + 156])
		if _tar_text(data, pos + 257, 5) == "ustar":
			var prefix := _tar_text(data, pos + 345, 155)
			if prefix != "":
				name = prefix + "/" + name
		var body := pos + 512
		if type == 76:
			long_name = _tar_text(data, body, size)
		elif type == 120:
			var records := _tar_text(data, body, size)
			for record in records.split("\n", false):
				var space := record.find(" ")
				if space >= 0 and record.substr(space + 1).begins_with("path="):
					long_name = record.substr(space + 6)
		elif type == 103:
			pass
		else:
			if long_name != "":
				name = long_name
				long_name = ""
			if name.ends_with("/"):
				name = name.trim_suffix("/")
				type = 53
			if type == 0:
				type = 48
			entries.append({"name": name, "size": size, "type": type, "offset": body})
		pos = body + ((size + 511) / 512) * 512
	return entries


static func _tar_text(data: PackedByteArray, offset: int, length: int) -> String:
	var end := mini(offset + length, data.size())
	var stop := offset
	while stop < end and data[stop] != 0:
		stop += 1
	return data.slice(offset, stop).get_string_from_utf8()


static func _tar_number(data: PackedByteArray, offset: int, length: int) -> int:
	var total := 0
	for i in length:
		var byte := int(data[offset + i])
		if byte >= 48 and byte <= 55:
			total = total * 8 + (byte - 48)
		elif total > 0 or byte == 0:
			break
	return total


# Executables start with a recognisable header: MZ on Windows, ELF on Linux,
# a Mach-O magic number on macOS.
static func looks_like_executable(path: String, plat: String = "", min_bytes: int = MIN_EXE_BYTES) -> bool:
	var os_name := plat if plat != "" else platform()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var big_enough := file.get_length() >= min_bytes
	var header := file.get_buffer(4)
	file.close()
	return big_enough and header_matches(header, os_name)


static func header_matches(header: PackedByteArray, plat: String) -> bool:
	if header.size() < 4:
		return false
	match plat:
		"windows":
			return header[0] == 0x4D and header[1] == 0x5A
		"linux":
			return header[0] == 0x7F and header[1] == 0x45 and header[2] == 0x4C and header[3] == 0x46
		"macos":
			var magic := (int(header[0]) << 24) | (int(header[1]) << 16) | (int(header[2]) << 8) | int(header[3])
			return magic in [0xFEEDFACE, 0xFEEDFACF, 0xCEFAEDFE, 0xCFFAEDFE, 0xCAFEBABE, 0xBEBAFECA]
	return false


# Marks a file as runnable on Unix-like systems. Does nothing on Windows.
static func make_executable(path: String) -> void:
	var flags := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER
	flags |= FileAccess.UNIX_READ_GROUP | FileAccess.UNIX_EXECUTE_GROUP | FileAccess.UNIX_READ_OTHER | FileAccess.UNIX_EXECUTE_OTHER
	FileAccess.set_unix_permissions(path, flags)


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
