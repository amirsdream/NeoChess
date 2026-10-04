class_name Pgn
extends RefCounted

# Portable Game Notation (PGN) export and import, following the PGN standard
# (Seven Tag Roster, SAN movetext, result token). Import is forgiving the way
# real-world files from lichess, chess.com and ChessBase need it to be:
# comments, variations, NAGs, annotation marks and zero castling are accepted.

const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const ROSTER := ["Event", "Site", "Date", "Round", "White", "Black", "Result"]
const ROSTER_DEFAULT := {
	"Event": "Casual game", "Site": "NeoChess", "Date": "????.??.??",
	"Round": "-", "White": "?", "Black": "?",
}
const RESULTS := ["1-0", "0-1", "1/2-1/2", "*"]
const KNOWN_TAGS := [
	"Event", "Site", "Date", "Round", "White", "Black", "Result", "WhiteElo", "BlackElo",
	"WhiteTitle", "BlackTitle", "TimeControl", "Termination", "Opening", "ECO", "Variant",
	"UTCDate", "UTCTime", "Annotator", "PlyCount", "SetUp", "FEN", "EventDate", "Source",
]
const LINE_WIDTH := 80
const MAX_BYTES := 8 * 1024 * 1024
const KIND_OF := {"N": 2, "B": 3, "R": 4, "Q": 5, "K": 6}
const SUPPORTED_VARIANTS := ["", "standard", "chess", "from position"]


static func result_for(state: String, white_to_move: bool) -> String:
	match state:
		"":
			return "*"
		"checkmate":
			return "0-1" if white_to_move else "1-0"
		_:
			return "1/2-1/2"


static func export_game(info: Dictionary, sans: Array, result: String, start_fen: String = "") -> String:
	var lines := PackedStringArray()
	for key in ROSTER:
		var value := result if key == "Result" else str(info.get(key, ROSTER_DEFAULT.get(key, "*")))
		lines.append(_tag(key, value))
	for key in info:
		var name := str(key)
		if name in ROSTER or name == "FEN" or name == "SetUp":
			continue
		lines.append(_tag(name, str(info[key])))
	var fen := start_fen.strip_edges()
	var custom := fen != "" and fen != START_FEN
	if custom:
		lines.append(_tag("SetUp", "1"))
		lines.append(_tag("FEN", fen))
	var text := "\n".join(lines) + "\n\n"
	text += _movetext(sans, result, fen if custom else START_FEN)
	return text + "\n"


# Parses the first game in the text. Returns a dictionary:
# ok, error, headers, start_fen, moves (move dicts), sans, result, game_count.
static func parse(text: String) -> Dictionary:
	var source := text
	if source.length() > MAX_BYTES:
		return _fail("That file is too large to be a single game.")
	if source.begins_with(char(0xFEFF)):
		source = source.substr(1)
	source = _normalize(source)

	var count := _count_games(source)
	var headers := {}
	var rest := source
	var tag_pattern := RegEx.new()
	tag_pattern.compile("^\\[\\s*([A-Za-z0-9_]+)\\s+\"((?:[^\"\\\\]|\\\\.)*)\"\\s*\\]")
	# Some sites and chat windows show tags without brackets, as Event: Name or
	# Event "Name". Only the well-known tag names are read that way.
	var bare_pattern := RegEx.new()
	bare_pattern.compile("^\\[?\\s*(" + "|".join(KNOWN_TAGS) + ")\\s*[:=]?\\s*\"?([^\"\\]]*)\"?\\s*\\]?\\s*$")
	while true:
		rest = _skip_blank(rest)
		if rest.begins_with("%"):
			rest = _after_line(rest)
			continue
		if not rest.begins_with("["):
			var plain := bare_pattern.search(rest.get_slice("\n", 0))
			if plain == null:
				break
			headers[plain.get_string(1)] = plain.get_string(2).strip_edges()
			rest = _after_line(rest)
			continue
		var found := tag_pattern.search(rest)
		if found == null:
			var loose := bare_pattern.search(rest.get_slice("\n", 0))
			if loose != null:
				headers[loose.get_string(1)] = loose.get_string(2).strip_edges()
			rest = _after_line(rest)
			continue
		headers[found.get_string(1)] = _unescape(found.get_string(2))
		rest = rest.substr(found.get_end())
	var tokens := _tokens("\n" + rest)
	var result := str(headers.get("Result", "*"))
	var words: Array = []
	for token in tokens:
		if str(token) in RESULTS:
			result = str(token)
			break
		words.append(token)
	if words.is_empty() and headers.is_empty():
		return _fail("No chess game was found in that text.")

	var variant := str(headers.get("Variant", "")).to_lower()
	if not (variant in SUPPORTED_VARIANTS):
		return _fail("The variant \"%s\" is not supported, only standard chess." % headers["Variant"])
	var start := START_FEN
	if headers.has("FEN") and (str(headers.get("SetUp", "1")) != "0"):
		start = str(headers["FEN"]).strip_edges()
		var problem := ChessGame.fen_error(start)
		if problem != "":
			return _fail("The starting position in this game is invalid. " + problem)

	var game = ChessGame.setup(start)
	var moves: Array = []
	var sans: Array[String] = []
	for token in words:
		var label := _move_label(game)
		var found := find_move(game, str(token))
		if not str(found["error"]).is_empty():
			var hint := ""
			if moves.is_empty() and str(found["error"]) == "is not a move.":
				hint = " The text does not look like a PGN game. A game has tags such as [Event \"…\"] followed by moves like 1. e4 e5."
			return _fail("Move %s %s: %s%s" % [label, token, found["error"], hint])
		var move: Dictionary = found["move"]
		sans.append(game.to_san(move))
		moves.append(move.duplicate())
		game.make_move(move)
	return {
		"ok": true, "error": "", "headers": headers, "start_fen": start, "moves": moves,
		"sans": sans, "result": result, "game_count": count,
	}


# Finds the legal move a SAN token means. Returns {"move": Dictionary, "error": String}.
static func find_move(game, token: String) -> Dictionary:
	var clean := token.strip_edges()
	while clean.length() > 0 and clean[clean.length() - 1] in ["+", "#", "!", "?"]:
		clean = clean.substr(0, clean.length() - 1)
	clean = clean.replace("0-0-0", "O-O-O").replace("0-0", "O-O")
	if clean.is_empty() or clean == "--" or clean == "Z0":
		return {"move": {}, "error": "null moves are not supported."}
	var legal: Array = game.legal_moves()

	if clean == "O-O" or clean == "O-O-O":
		var wanted_file := 6 if clean == "O-O" else 2
		for move in legal:
			if bool(move.get("castle", false)) and int(move.to) % 8 == wanted_file:
				return {"move": move, "error": ""}
		return {"move": {}, "error": "castling is not legal here."}

	var promo := 0
	var body := clean
	var equals := body.find("=")
	if equals >= 0:
		promo = int(ChessGame.PROMO_FROM.get(body.substr(equals + 1, 1).to_lower(), 0))
		body = body.substr(0, equals)
	elif body.length() >= 3 and body[body.length() - 1] in ["Q", "R", "B", "N", "q", "r", "b", "n"] and body[body.length() - 2].is_valid_int():
		promo = int(ChessGame.PROMO_FROM.get(body[body.length() - 1].to_lower(), 0))
		body = body.substr(0, body.length() - 1)
	body = body.replace("x", "").replace(":", "").replace("-", "")
	if body.length() < 2:
		return {"move": {}, "error": "is not a move."}
	var target: int = game.name_sq(body.substr(body.length() - 2, 2))
	if target < 0:
		return {"move": {}, "error": "is not a move."}
	var prefix := body.substr(0, body.length() - 2)
	var kind := ChessGame.PAWN
	if prefix.length() > 0 and KIND_OF.has(prefix[0]):
		kind = int(KIND_OF[prefix[0]])
		prefix = prefix.substr(1)
	var hint_file := -1
	var hint_rank := -1
	for ch in prefix:
		if ch >= "a" and ch <= "h":
			hint_file = "abcdefgh".find(ch)
		elif ch >= "1" and ch <= "8":
			hint_rank = int(ch) - 1
		else:
			return {"move": {}, "error": "is not a move."}

	var matches: Array = []
	for move in legal:
		var origin := int(move.from)
		if absi(int(game.board[origin])) != kind or int(move.to) != target:
			continue
		if int(move.get("promo", 0)) != promo:
			continue
		if hint_file >= 0 and origin % 8 != hint_file:
			continue
		if hint_rank >= 0 and origin / 8 != hint_rank:
			continue
		matches.append(move)
	if matches.size() == 1:
		return {"move": matches[0], "error": ""}
	if matches.is_empty():
		return {"move": {}, "error": "is not legal in this position."}
	return {"move": {}, "error": "could mean more than one piece."}


static func _movetext(sans: Array, result: String, start_fen: String) -> String:
	var parts := start_fen.split(" ", false)
	var white := parts.size() < 2 or parts[1] == "w"
	var number := int(parts[5]) if parts.size() > 5 else 1
	var words := PackedStringArray()
	var first := true
	for san in sans:
		if white:
			words.append("%d. %s" % [number, san])
		elif first:
			words.append("%d... %s" % [number, san])
		else:
			words.append(str(san))
		if not white:
			number += 1
		white = not white
		first = false
	words.append(result)
	var lines := PackedStringArray()
	var current := ""
	for word in words:
		var piece := str(word)
		if current.is_empty():
			current = piece
		elif current.length() + 1 + piece.length() > LINE_WIDTH:
			lines.append(current)
			current = piece
		else:
			current += " " + piece
	lines.append(current)
	return "\n".join(lines)


static func _tag(key: String, value: String) -> String:
	var safe := value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ").replace("\r", " ")
	return "[%s \"%s\"]" % [key, safe]


# Text copied from web pages and chat programs often carries non-breaking
# spaces, curly quotes or unusual line separators. Make them ordinary.
static func _normalize(text: String) -> String:
	var out := text.replace("\r\n", "\n").replace("\r", "\n")
	# The characters are built with char(): "\uXXXX" escapes are lost when a
	# release build compiles the script (the string becomes empty), which made
	# begins_with() true for every text.
	for code in [0x2028, 0x2029, 0x0085]:
		out = out.replace(char(code), "\n")
	for code in [0x00A0, 0x2007, 0x202F, 0x3000, 0x2009, 0x200A]:
		out = out.replace(char(code), " ")
	for code in [0x201C, 0x201D, 0x201E, 0x00AB, 0x00BB]:
		out = out.replace(char(code), "\"")
	for code in [0x2013, 0x2014, 0x2212]:
		out = out.replace(char(code), "-")
	if out.contains("```"):
		var kept := PackedStringArray()
		for line in out.split("\n"):
			if not line.strip_edges().begins_with("```"):
				kept.append(line)
		out = "\n".join(kept)
	for code in [0x200B, 0x200E, 0x200F, 0xFEFF]:
		out = out.replace(char(code), "")
	return out


static func _skip_blank(text: String) -> String:
	var i := 0
	while i < text.length() and text[i] in [" ", "\t", "\n"]:
		i += 1
	return text.substr(i)


static func _after_line(text: String) -> String:
	var eol := text.find("\n")
	return "" if eol < 0 else text.substr(eol + 1)


static func _unescape(raw: String) -> String:
	var value := ""
	var escaped := false
	for ch in raw:
		if escaped:
			value += ch
			escaped = false
		elif ch == "\\":
			escaped = true
		else:
			value += ch
	return value


# Splits movetext into move words and result tokens, dropping comments,
# variations, NAGs and move numbers.
static func _tokens(source: String) -> Array:
	var out: Array = []
	var i := 0
	var n := source.length()
	var depth := 0
	while i < n:
		var c := source[i]
		if c == " " or c == "\n" or c == "\t":
			i += 1
		elif c == "{":
			var close := source.find("}", i)
			i = n if close < 0 else close + 1
		elif c == ";":
			var eol := source.find("\n", i)
			i = n if eol < 0 else eol + 1
		elif c == "%" and (i == 0 or source[i - 1] == "\n"):
			var eol2 := source.find("\n", i)
			i = n if eol2 < 0 else eol2 + 1
		elif c == "(":
			depth += 1
			i += 1
		elif c == ")":
			depth = maxi(0, depth - 1)
			i += 1
		elif c == "$":
			i += 1
			while i < n and source[i].is_valid_int():
				i += 1
		else:
			var j := i
			while j < n and not (source[j] in [" ", "\n", "\t", "{", ";", "(", ")"]):
				j += 1
			var word := source.substr(i, j - i)
			i = j
			if depth > 0:
				continue
			if word in RESULTS:
				out.append(word)
				break
			word = _strip_number(word)
			if word.is_empty() or word == "e.p." or word.is_valid_int():
				continue
			if word in RESULTS:
				out.append(word)
				break
			out.append(word)
	return out


static func _strip_number(word: String) -> String:
	var k := 0
	while k < word.length() and word[k].is_valid_int():
		k += 1
	if k > 0 and k < word.length() and word[k] == ".":
		while k < word.length() and word[k] == ".":
			k += 1
		return word.substr(k)
	if k > 0 and k == word.length():
		return ""
	return word


static func _count_games(source: String) -> int:
	var regex := RegEx.new()
	regex.compile("(?m)^\\[Event\\s")
	return maxi(regex.search_all(source).size(), 1)


static func _move_label(game) -> String:
	return "%d%s" % [int(game.fullmove), "." if game.white_to_move else "..."]


static func _fail(message: String) -> Dictionary:
	return {
		"ok": false, "error": message, "headers": {}, "start_fen": START_FEN,
		"moves": [], "sans": [], "result": "*", "game_count": 0,
	}
