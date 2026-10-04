class_name StockfishUci
extends RefCounted

# Pure helpers for the UCI protocol: parsing what an engine prints and building
# what it is sent. They touch no files and start no processes, so they behave
# the same on every platform and are easy to test. UciEngine does the talking.

const MAX_PV_MOVES := 40


# Parses one "info ... pv ..." line. Returns {} for lines that carry no
# principal variation. Keys: n (MultiPV index), depth, seldepth, cp, mate,
# has_mate, bound ("", "lower" or "upper"), pv (UCI moves), nodes, nps,
# hashfull (permille), time (ms).
static func parse_info(raw: String) -> Dictionary:
	var line := raw.strip_edges()
	if not line.begins_with("info ") or not line.contains(" pv "):
		return {}
	var parts := line.split(" ", false)
	var entry := {
		"n": 1, "depth": 0, "seldepth": 0, "cp": 0, "mate": 0, "has_mate": false,
		"bound": "", "pv": PackedStringArray(), "nodes": 0, "nps": 0, "hashfull": 0, "time": 0,
	}
	var i := 0
	while i < parts.size():
		var token := str(parts[i])
		match token:
			"multipv", "depth", "seldepth", "nodes", "nps", "hashfull", "time":
				if i + 1 < parts.size():
					entry["n" if token == "multipv" else token] = int(parts[i + 1])
				i += 2
			"score":
				if i + 2 < parts.size():
					if str(parts[i + 1]) == "mate":
						entry["mate"] = int(parts[i + 2])
						entry["has_mate"] = true
					elif str(parts[i + 1]) == "cp":
						entry["cp"] = int(parts[i + 2])
						entry["has_mate"] = false
				i += 3
			"lowerbound":
				entry["bound"] = "lower"
				i += 1
			"upperbound":
				entry["bound"] = "upper"
				i += 1
			"pv":
				i += 1
				var pv := PackedStringArray()
				while i < parts.size() and pv.size() < MAX_PV_MOVES:
					var move := str(parts[i])
					if move.length() < 4 or move.length() > 5:
						break
					pv.append(move)
					i += 1
				entry["pv"] = pv
				i = parts.size()
			_:
				i += 1
	if (entry["pv"] as PackedStringArray).is_empty() or int(entry["n"]) < 1:
		return {}
	return entry


# The newest line for each MultiPV index (1..limit) found in the text.
static func principal_lines(text: String, limit: int) -> Array:
	var found := {}
	for raw in text.split("\n"):
		var entry := parse_info(raw)
		if entry.is_empty() or int(entry["n"]) > limit:
			continue
		found[int(entry["n"])] = entry
	var result: Array = []
	for n in range(1, limit + 1):
		if found.has(n):
			result.append(found[n])
	return result


# Parses an "option name X type T default D min A max B var V ..." line.
# Returns {} if it is not an option line.
static func parse_option(raw: String) -> Dictionary:
	var line := raw.strip_edges()
	if not line.begins_with("option name "):
		return {}
	var rest := line.substr(12)
	var type_at := rest.find(" type ")
	if type_at < 0:
		return {}
	var spec := {"name": rest.substr(0, type_at), "type": "", "default": null, "min": null, "max": null, "vars": PackedStringArray()}
	var words := rest.substr(type_at + 6).split(" ", false)
	if words.is_empty():
		return {}
	spec["type"] = str(words[0])
	var keys := ["default", "min", "max", "var"]
	var k := 1
	while k < words.size():
		var key := str(words[k])
		if not (key in keys):
			k += 1
			continue
		var buffer := PackedStringArray()
		k += 1
		while k < words.size() and not (str(words[k]) in keys):
			buffer.append(str(words[k]))
			k += 1
		var value := " ".join(buffer)
		match key:
			"default":
				spec["default"] = value
			"min":
				spec["min"] = int(value)
			"max":
				spec["max"] = int(value)
			"var":
				var choices: PackedStringArray = spec["vars"]
				choices.append(value)
				spec["vars"] = choices
	match str(spec["type"]):
		"spin":
			spec["default"] = int(str(spec["default"])) if spec["default"] != null else 0
		"check":
			spec["default"] = str(spec["default"]) == "true"
		"string", "combo":
			spec["default"] = "" if spec["default"] == null else str(spec["default"])
	return spec


# Fits a value to what an option accepts (spin range, check as bool).
static func coerce_option(spec: Dictionary, value):
	match str(spec.get("type", "")):
		"spin":
			var number := int(value)
			if spec.get("min") != null:
				number = maxi(number, int(spec["min"]))
			if spec.get("max") != null:
				number = mini(number, int(spec["max"]))
			return number
		"check":
			return bool(value)
		_:
			return str(value)


static func option_command(name: String, value) -> String:
	var text := str(value)
	if typeof(value) == TYPE_BOOL:
		text = "true" if value else "false"
	return "setoption name %s value %s" % [name, text]


# The "go" command for a search description:
#   {"infinite": true}                      until stopped
#   {"clock": true, "wtime", "btime", ...}  play on the clock
#   {"depth": n}                            to a fixed depth
#   {"movetime": ms}                        a fixed time (default)
static func go_command(go: Dictionary) -> String:
	if bool(go.get("infinite", false)):
		return "go infinite"
	if bool(go.get("clock", false)):
		var wtime := maxi(int(go.get("wtime", 1000)), 50)
		var btime := maxi(int(go.get("btime", 1000)), 50)
		var inc := maxi(int(go.get("inc", 0)), 0)
		return "go wtime %d btime %d winc %d binc %d" % [wtime, btime, inc, inc]
	if int(go.get("depth", 0)) > 0:
		return "go depth %d" % int(go["depth"])
	return "go movetime %d" % maxi(int(go.get("movetime", 400)), 50)


# How long a search may take before the engine counts as stuck. 0 means no limit.
static func time_budget_ms(go: Dictionary) -> int:
	if bool(go.get("infinite", false)):
		return 0
	if bool(go.get("clock", false)):
		return maxi(int(go.get("wtime", 1000)), int(go.get("btime", 1000))) + 20000
	if int(go.get("depth", 0)) > 0:
		return 10 * 60 * 1000
	return maxi(int(go.get("movetime", 400)), 50) + 20000


# Translates NeoChess's search options into the UCI options the engine needs.
static func engine_settings(options: Dictionary) -> Dictionary:
	var settings := {
		"Threads": clampi(int(options.get("threads", 1)), 1, 16),
		"Hash": clampi(int(options.get("hash", 64)), 1, 1024),
		"Move Overhead": clampi(int(options.get("overhead", 30)), 0, 5000),
		"MultiPV": clampi(int(options.get("multipv", 1)), 1, 5),
	}
	if bool(options.get("limit_elo", false)):
		settings["UCI_LimitStrength"] = true
		settings["UCI_Elo"] = clampi(int(options.get("elo", 1600)), 1320, 3190)
	else:
		settings["UCI_LimitStrength"] = false
		settings["Skill Level"] = clampi(int(options.get("skill", 8)), 0, 20)
	return settings


# The "go" part of NeoChess's search options.
static func go_from_options(options: Dictionary) -> Dictionary:
	if bool(options.get("clock", false)):
		return {
			"clock": true,
			"wtime": int(options.get("wtime", 1000)),
			"btime": int(options.get("btime", 1000)),
			"inc": int(options.get("inc", 0)),
		}
	return {"movetime": int(options.get("movetime", 400))}


static func format_nodes_per_second(nps: int) -> String:
	if nps >= 1000000:
		return "%.1f Mn/s" % (float(nps) / 1000000.0)
	if nps >= 1000:
		return "%d kn/s" % int(round(float(nps) / 1000.0))
	return "%d n/s" % nps
