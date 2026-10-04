class_name OpeningNames
extends RefCounted

# Names the opening a position belongs to ("C84 Ruy Lopez: Closed").
#
# The names come from the Lichess chess-openings data set (CC0, about 3,800
# named lines with ECO codes), prepared by dev/build_openings.gd into
# data/openings.tsv. Positions are matched, not move orders, so the same
# opening is recognised after a transposition. A position is matched by its
# pieces, the side to move and the castling rights.

const DATA := "res://data/openings.tsv"

static var _names := {}
static var _loaded := false
static var _longest := 0
static var _cache_line := ""
static var _cache_found := {}


# How many half-moves the longest named line has.
static func longest_line() -> int:
	_load()
	return _longest


static func count() -> int:
	_load()
	return _names.size()


# The key of a position: FEN without the en passant square and the move counters.
static func key_of(game) -> String:
	var parts: PackedStringArray = String(game.to_fen()).split(" ")
	return "%s %s %s" % [parts[0], parts[1], parts[2]]


# The entry for a position: {eco, name, plies, line}, or an empty dictionary.
static func find_position(game) -> Dictionary:
	_load()
	var entry: Variant = _names.get(key_of(game), null)
	return {} if entry == null else (entry as Dictionary)


# The deepest named position on the way through `moves` (move dictionaries from
# the standard start). Returns {eco, name, plies, line, at} where `at` is the half
# move it was reached at, or an empty dictionary when no position is named.
static func find_line(moves: Array) -> Dictionary:
	_load()
	if _names.is_empty() or moves.is_empty():
		return {}
	var upto := mini(moves.size(), _longest)
	var signature := PackedStringArray()
	for i in upto:
		var move: Dictionary = moves[i]
		signature.append("%d-%d-%d" % [int(move.from), int(move.to), int(move.get("promo", 0))])
	var text := ",".join(signature)
	if text == _cache_line:
		return _cache_found
	var game := ChessGame.new()
	var found := {}
	for i in upto:
		game.make_move(moves[i])
		var entry: Variant = _names.get(key_of(game), null)
		if entry != null:
			found = (entry as Dictionary).duplicate()
			found["at"] = i + 1
	_cache_line = text
	_cache_found = found
	return found


# The name of the position reached by playing `san` in `game`, or an empty
# dictionary. The game is not changed.
static func find_after(game, san: String) -> Dictionary:
	var found := Pgn.find_move(game, san)
	var move: Dictionary = found.get("move", {})
	if move.is_empty():
		return {}
	var next = game.clone()
	next.make_move(move)
	return find_position(next)


# "C84 · Ruy Lopez: Closed"
static func label(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	return "%s  ·  %s" % [entry["eco"], entry["name"]]


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(DATA, FileAccess.READ)
	if file == null:
		return
	while not file.eof_reached():
		var columns := file.get_line().split("\t")
		if columns.size() < 5 or columns[0] == "eco":
			continue
		var key := columns[3]
		if _names.has(key):
			continue
		var plies := int(columns[2])
		_names[key] = {"eco": columns[0], "name": columns[1], "plies": plies, "line": columns[4]}
		_longest = maxi(_longest, plies)
	file.close()
