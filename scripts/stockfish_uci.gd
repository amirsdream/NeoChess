class_name StockfishUci
extends RefCounted

static var last_log := ""
static var last_depth := 0


static func best_move(engine_path: String, fen: String, options: Dictionary) -> String:
	last_log = ""
	last_depth = 0
	if engine_path.is_empty() or not FileAccess.file_exists(engine_path):
		last_log = "Engine file not found."
		return ""

	var folder := OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(folder)
	var input_path := folder.path_join("uci_input.txt")
	var log_path := output_log_path()
	var ps1_path := folder.path_join("run_stockfish.ps1")
	var dll_path := folder.path_join("uci_run_3.dll")
	var commands := _commands(fen, options)
	var input := FileAccess.open(input_path, FileAccess.WRITE)
	if input == null:
		last_log = "Could not write UCI commands."
		return ""
	input.store_string(commands)
	input.close()
	var runner := FileAccess.get_file_as_string("res://bin/run_stockfish.ps1")
	if runner.is_empty():
		last_log = "Engine launcher is missing."
		return ""
	var script := FileAccess.open(ps1_path, FileAccess.WRITE)
	if script == null:
		last_log = "Could not write the engine launcher."
		return ""
	script.store_string(runner)
	script.close()
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	var full_path := log_path + ".full"
	if FileAccess.file_exists(full_path):
		DirAccess.remove_absolute(full_path)
	var stream_path := stream_log_path()
	if FileAccess.file_exists(stream_path):
		DirAccess.remove_absolute(stream_path)

	var movetime := maxi(int(options.get("movetime", 400)), 50)
	var timeout := movetime + 20000
	if bool(options.get("clock", false)):
		timeout = maxi(maxi(int(options.get("wtime", 1000)), int(options.get("btime", 1000))), 1000) + 20000
	var output: Array = []
	var code := OS.execute("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-NonInteractive",
		"-ExecutionPolicy", "Bypass",
		"-File", ps1_path,
		"-Engine", engine_path,
		"-CommandsFile", input_path,
		"-LogFile", log_path,
		"-DllPath", dll_path,
		"-TimeoutMs", str(timeout),
	]), output, true, false)

	var text := FileAccess.get_file_as_string(log_path + ".full")
	if text.is_empty():
		text = FileAccess.get_file_as_string(log_path)
	if text.is_empty():
		for line in output:
			text += str(line)
			if not str(line).ends_with("\n"):
				text += "\n"
	last_log = text
	last_depth = _max_depth(text)
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("bestmove "):
			var bits := trimmed.split(" ")
			if bits.size() >= 2:
				return bits[1]
	if text.is_empty():
		last_log = "Stockfish exited with code %d and no output." % code
	return ""


static func output_log_path() -> String:
	return OS.get_user_data_dir().path_join("uci_output.txt")


static func stream_log_path() -> String:
	return output_log_path() + ".stream"


static func _commands(fen: String, options: Dictionary) -> String:
	var skill := clampi(int(options.get("skill", 8)), 0, 20)
	var movetime := maxi(int(options.get("movetime", 400)), 50)
	var threads := clampi(int(options.get("threads", 1)), 1, 16)
	var hash_mb := clampi(int(options.get("hash", 64)), 1, 1024)
	var overhead := clampi(int(options.get("overhead", 30)), 0, 5000)
	var multipv := clampi(int(options.get("multipv", 1)), 1, 5)
	var lines := PackedStringArray([
		"uci",
		"setoption name Threads value %d" % threads,
		"setoption name Hash value %d" % hash_mb,
		"setoption name Move Overhead value %d" % overhead,
		"setoption name MultiPV value %d" % multipv,
	])
	if bool(options.get("limit_elo", false)):
		var elo := clampi(int(options.get("elo", 1600)), 1320, 3190)
		lines.append("setoption name UCI_LimitStrength value true")
		lines.append("setoption name UCI_Elo value %d" % elo)
	else:
		lines.append("setoption name UCI_LimitStrength value false")
		lines.append("setoption name Skill Level value %d" % skill)
	lines.append("isready")
	lines.append("position fen %s" % fen)
	if bool(options.get("clock", false)):
		var wtime := maxi(int(options.get("wtime", 1000)), 50)
		var btime := maxi(int(options.get("btime", 1000)), 50)
		var inc := maxi(int(options.get("inc", 0)), 0)
		lines.append("go wtime %d btime %d winc %d binc %d" % [wtime, btime, inc, inc])
	else:
		lines.append("go movetime %d" % movetime)
	return "\n".join(lines) + "\n"


static func principal_lines(text: String, limit: int) -> Array:
	var found := {}
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with("info ") or not line.contains(" pv "):
			continue
		var parts := line.split(" ")
		var mpv := 1
		var depth := 0
		var cp := 0
		var mate := 0
		var has_mate := false
		var pv := PackedStringArray()
		var i := 0
		while i < parts.size():
			var token := str(parts[i])
			if token == "multipv" and i + 1 < parts.size():
				mpv = int(parts[i + 1])
				i += 2
			elif token == "depth" and i + 1 < parts.size():
				depth = int(parts[i + 1])
				i += 2
			elif token == "score" and i + 2 < parts.size():
				if str(parts[i + 1]) == "mate":
					mate = int(parts[i + 2])
					has_mate = true
				elif str(parts[i + 1]) == "cp":
					cp = int(parts[i + 2])
					has_mate = false
				i += 3
			elif token == "pv":
				i += 1
				while i < parts.size():
					var move := str(parts[i])
					if move.length() < 4 or move.length() > 5:
						break
					pv.append(move)
					i += 1
				break
			else:
				i += 1
		if pv.is_empty() or mpv < 1 or mpv > limit:
			continue
		found[mpv] = {"n": mpv, "depth": depth, "cp": cp, "mate": mate, "has_mate": has_mate, "pv": pv}
	var result: Array = []
	for n in range(1, limit + 1):
		if found.has(n):
			result.append(found[n])
	return result


static func _max_depth(text: String) -> int:
	var best := 0
	for line in text.split("\n"):
		var parts := line.split(" ")
		var idx := parts.find("depth")
		if idx >= 0 and idx + 1 < parts.size():
			best = maxi(best, int(parts[idx + 1]))
	return best
