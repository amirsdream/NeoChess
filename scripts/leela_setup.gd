class_name LeelaSetup
extends RefCounted

# Helpers for finding, downloading and installing Leela Chess Zero (lc0), a
# neural-network engine that runs on the graphics card. lc0 is GPLv3 and is not
# stored in this repository. On request NeoChess downloads two things:
#   1. the official lc0 build that uses DirectML (any DirectX 12 graphics card,
#      NVIDIA, AMD or Intel; Windows only), from the lc0 GitHub release;
#   2. one neural network (the "weights"), from the Leela Chess Zero project.
# On Linux and macOS lc0 has no official download for these backends, so there
# the engine file is chosen by hand (for example the lc0 package of a distro).

const VERSION := "0.32.1"
const RELEASE_BASE := "https://github.com/LeelaChessZero/lc0/releases/download/v0.32.1/"
const RELEASE_PAGE := "https://github.com/LeelaChessZero/lc0/releases/tag/v0.32.1"
const NETWORK_FILE := "t1-512x15x8h-distilled-swa-3395000.pb.gz"
const NETWORK_URL := "https://storage.lczero.org/files/networks-contrib/t1-512x15x8h-distilled-swa-3395000.pb.gz"
const NETWORK_PAGE := "https://lczero.org/play/networks/bestnets/"
const NETWORK_MIN_BYTES := 1000000
const BACKEND := "onnx-dml"
const MIN_EXE_BYTES := 1000000
const REQUIRED_FILES := ["lc0.exe", "onnxruntime.dll"]
const SKIPPED_SUFFIXES := [".pb.gz", ".cmd", ".bat"]
const POSIX_SYSTEM_PATHS := [
	"/usr/games/lc0",
	"/usr/bin/lc0",
	"/usr/local/bin/lc0",
	"/opt/homebrew/bin/lc0",
	"/snap/bin/lc0",
]


static func exe_name(plat: String = "") -> String:
	return "lc0.exe" if (plat if plat != "" else EngineSetup.platform()) == "windows" else "lc0"


# The release file for a platform, or "" when lc0 publishes none we can use.
static func asset_name(plat: String = "", arch: String = "") -> String:
	var os_name := plat if plat != "" else EngineSetup.platform()
	var cpu := arch if arch != "" else EngineSetup.architecture()
	if os_name == "windows" and cpu == "x86_64":
		return "lc0-v%s-windows-onnx-dml.zip" % VERSION
	return ""


static func download_url(plat: String = "", arch: String = "") -> String:
	var asset := asset_name(plat, arch)
	return "" if asset.is_empty() else RELEASE_BASE + asset


static func is_supported(plat: String = "", arch: String = "") -> bool:
	return not asset_name(plat, arch).is_empty()


static func install_dir() -> String:
	return EngineSetup.install_dir().path_join("leela")


static func install_path(plat: String = "") -> String:
	return install_dir().path_join(exe_name(plat))


static func network_path() -> String:
	return install_dir().path_join(NETWORK_FILE)


static func archive_path() -> String:
	return install_dir().path_join("lc0-download.zip")


# Places NeoChess looks for lc0, best first.
static func candidates(exe_dir: String, project_bin: String, plat: String = "") -> PackedStringArray:
	var os_name := plat if plat != "" else EngineSetup.platform()
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


# True when the lc0 NeoChess installed itself is the file in use. Only then does
# NeoChess choose the backend and the network; an engine you picked yourself is
# left to its own configuration.
static func is_installed_copy(path: String) -> bool:
	return path != "" and path == install_path()


static func has_network() -> bool:
	return looks_like_network(network_path())


static func needs_engine() -> bool:
	return not (FileAccess.file_exists(install_path()) and EngineSetup.looks_like_executable(install_path(), "", MIN_EXE_BYTES))


static func needs_network() -> bool:
	return not has_network()


# A real network is a gzip file of some size; a failed download is not.
static func looks_like_network(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var big_enough := file.get_length() >= NETWORK_MIN_BYTES
	var header := file.get_buffer(2)
	file.close()
	return big_enough and header.size() == 2 and header[0] == 0x1F and header[1] == 0x8B


# The files of the release archive that are installed: everything at the top
# level except bundled sample networks and install scripts.
static func installable_entries(entries: PackedStringArray) -> PackedStringArray:
	var kept := PackedStringArray()
	for entry in entries:
		if entry.ends_with("/") or entry.contains("..") or entry.count("/") > 1:
			continue
		var name := entry.get_file().to_lower()
		var skip := false
		for suffix in SKIPPED_SUFFIXES:
			if name.ends_with(str(suffix)):
				skip = true
		if not skip:
			kept.append(entry)
	return kept


# Unpacks lc0 and the libraries it needs from the release zip into dest_dir.
# Returns {"ok", "path", "error"}.
static func extract(archive: String, dest_dir: String) -> Dictionary:
	var reader := ZIPReader.new()
	if reader.open(archive) != OK:
		return _fail("The downloaded file is not a valid zip archive.")
	var entries := installable_entries(reader.get_files())
	var names := PackedStringArray()
	for entry in entries:
		names.append(entry.get_file().to_lower())
	for needed in REQUIRED_FILES:
		if not (needed in names):
			reader.close()
			return _fail("The archive does not contain %s." % needed)
	if DirAccess.make_dir_recursive_absolute(dest_dir) != OK:
		reader.close()
		return _fail("Could not create the install folder.")
	for entry in entries:
		var target := dest_dir.path_join(entry.get_file())
		if not _write(target, reader.read_file(entry)):
			reader.close()
			return _fail("Could not write %s." % entry.get_file())
	reader.close()
	var exe := dest_dir.path_join("lc0.exe")
	if not EngineSetup.looks_like_executable(exe, "windows", MIN_EXE_BYTES):
		DirAccess.remove_absolute(exe)
		return _fail("The extracted file is not a Windows program.")
	return {"ok": true, "path": exe, "error": ""}


# Starts lc0 once to confirm it runs. It prints a banner with its version and
# exits for --help, so no UCI session is needed.
static func runs(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var output: Array = []
	var code := OS.execute(path, PackedStringArray(["--help"]), output, true, false)
	if code != 0:
		return false
	var text := " ".join(PackedStringArray(output))
	return text.contains("built") or text.to_lower().contains("lc0")


# The UCI options that make lc0 use the installed backend and network.
static func uci_settings(path: String) -> Dictionary:
	if not is_installed_copy(path):
		return {}
	var settings := {"Backend": BACKEND}
	if has_network():
		settings["WeightsFile"] = network_path()
	return settings


static func describe_http_failure(result: int, code: int, host: String = "GitHub") -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
				return "Could not reach %s. Check your internet connection." % host
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
				return "A secure connection to %s could not be made." % host
			HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
				return "Could not save the download. Check free disk space."
			_:
				return "The download failed (error %d)." % result
	if code != 200:
		return "%s answered with HTTP %d." % [host, code]
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
