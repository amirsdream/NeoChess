class_name PgnReader
extends RefCounted

# Reads games from a PGN file one at a time, fast enough for databases with
# hundreds of thousands of games. It does not check the moves for legality
# (the games are opened and checked when you view one); it only separates the
# tags from the moves and cleans the move text.
#
#   var reader := PgnReader.new(FileAccess.open(path, FileAccess.READ))
#   while true:
#       var game := reader.next_game()
#       if game.is_empty():
#           break

const RESULTS := ["1-0", "0-1", "1/2-1/2", "*"]
# Built with char(): a "\ufeff" literal turns into an empty string in release
# builds, and then every line would lose its first character.
var BOM := char(0xFEFF)

var file: FileAccess
var games_read := 0
var _pending := ""


func _init(source: FileAccess) -> void:
	file = source


# Bytes read so far, for progress bars.
func position() -> int:
	return file.get_position() if file != null else 0


# The next game as {"tags": Dictionary, "sans": PackedStringArray,
# "result": String}, or an empty dictionary at the end of the file.
func next_game() -> Dictionary:
	if file == null:
		return {}
	var tags := {}
	var movetext := PackedStringArray()
	var open_braces := false
	var seen_moves := false
	while true:
		var line := _pending
		if line != "":
			_pending = ""
		elif file.eof_reached():
			break
		else:
			line = file.get_line()
		if line.ends_with("\r"):
			line = line.substr(0, line.length() - 1)
		if line.begins_with(BOM):
			line = line.substr(1)
		if open_braces:
			movetext.append(line)
			if line.contains("}"):
				open_braces = _unclosed_brace(line, true)
			continue
		var stripped := line.strip_edges()
		if stripped.is_empty():
			if seen_moves:
				break
			continue
		if line.begins_with("%"):
			continue
		if stripped.begins_with("[") and not seen_moves:
			_read_tag(stripped, tags)
			continue
		if stripped.begins_with("[") and seen_moves:
			# The next game starts without a blank line in between.
			_pending = line
			break
		seen_moves = true
		if stripped.contains(";"):
			var semicolon := stripped.find(";")
			var brace := stripped.find("{")
			if brace < 0 or semicolon < brace:
				stripped = stripped.substr(0, semicolon)
		movetext.append(stripped)
		if stripped.contains("{"):
			open_braces = _unclosed_brace(stripped, false)
	if tags.is_empty() and movetext.is_empty():
		return {}
	games_read += 1
	var parsed := parse_movetext(" ".join(movetext))
	return {"tags": tags, "sans": parsed["sans"], "result": _result_of(tags, str(parsed["result"]))}


# Splits movetext into the moves (without numbers, comments, variations or
# annotations) and the result marker if there is one.
static func parse_movetext(text: String) -> Dictionary:
	var cleaned := text
	if cleaned.contains("{") or cleaned.contains("(") or cleaned.contains(";") or cleaned.contains("$"):
		cleaned = _strip_extras(cleaned)
	var sans := PackedStringArray()
	var result := ""
	for token in cleaned.replace("\t", " ").split(" ", false):
		var word := token as String
		if word in RESULTS:
			result = word
			continue
		var first := word.unicode_at(0)
		if first >= 48 and first <= 57:
			# Move numbers: "12." and "12..." and glued forms like "12.e4".
			var dot := word.rfind(".")
			if dot < 0:
				continue
			word = word.substr(dot + 1)
			if word.is_empty():
				continue
		word = word.rstrip("!?")
		if word.is_empty():
			continue
		sans.append(word)
	return {"sans": sans, "result": result}


# Removes {comments}, ; line comments, (variations, even nested) and $NAGs.
static func _strip_extras(text: String) -> String:
	var out := PackedStringArray()
	var depth := 0
	var in_brace := false
	var i := 0
	var length := text.length()
	var start := 0
	while i < length:
		var c := text.unicode_at(i)
		if in_brace:
			if c == 125:
				in_brace = false
				start = i + 1
		elif c == 123:
			if depth == 0:
				out.append(text.substr(start, i - start))
			in_brace = true
		elif c == 59 and depth == 0:
			out.append(text.substr(start, i - start))
			var eol := text.find("\n", i)
			if eol < 0:
				start = length
				break
			start = eol
			i = eol - 1
		elif c == 40:
			if depth == 0:
				out.append(text.substr(start, i - start))
			depth += 1
		elif c == 41 and depth > 0:
			depth -= 1
			if depth == 0:
				start = i + 1
		elif c == 36 and depth == 0:
			out.append(text.substr(start, i - start))
			var j := i + 1
			while j < length and text.unicode_at(j) >= 48 and text.unicode_at(j) <= 57:
				j += 1
			start = j
			i = j - 1
		i += 1
	if not in_brace and depth == 0 and start <= length:
		out.append(text.substr(start))
	return " ".join(out).replace("\n", " ")


static func _unclosed_brace(line: String, already_open: bool) -> bool:
	var open := already_open
	for i in line.length():
		var c := line.unicode_at(i)
		if c == 123 and not open:
			open = true
		elif c == 125 and open:
			open = false
	return open


static func _read_tag(line: String, tags: Dictionary) -> bool:
	var space := line.find(" ")
	var quote := line.find("\"")
	var last := line.rfind("\"")
	if space < 2 or quote < 0 or last <= quote:
		return false
	tags[line.substr(1, space - 1)] = line.substr(quote + 1, last - quote - 1).replace("\\\"", "\"").replace("\\\\", "\\")
	return true


static func _result_of(tags: Dictionary, from_moves: String) -> String:
	var tagged := str(tags.get("Result", ""))
	if tagged in RESULTS:
		return tagged
	if from_moves != "":
		return from_moves
	return "*"
