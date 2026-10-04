class_name GameStore
extends RefCounted

# The game library: a SQLite database with your own games and any databases
# you import. Each collection of games is a "source". The opening explorer is
# answered from the first moves of every game, so there is no separate index
# to maintain: deleting a game or a whole source just works.
#
# Several GameStore objects can open the same file (the importer uses its own
# connection on a worker thread); the database runs in WAL mode.

const SCHEMA_VERSION := 2
# Games keep their first moves in a separate indexed column for the explorer.
const LINE_PLIES := 24
const KIND_MINE := "mine"
const KIND_IMPORT := "import"
const FNV_BASIS := -3750763034362895579
const FNV_PRIME := 1099511628211
const KEPT_TAGS := ["Round", "TimeControl", "Termination", "LichessURL", "EventType", "Annotator", "Time"]
const COLUMNS := "id, source_id, white, black, white_elo, black_elo, result, date, year, event, site, eco, opening, plies, start_fen"

var path := ""
var error := ""
# The godot-sqlite object. It is created by name, so the game still starts (without
# a library) when the native library file is missing.
var _db: Object


static func default_path() -> String:
	return OS.get_user_data_dir().path_join("games.db")


func is_open() -> bool:
	return _db != null


func open(file_path: String = "") -> bool:
	close()
	path = file_path if file_path != "" else default_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if not _looks_like_database(path):
		error = "%s is not a NeoChess game library." % path.get_file()
		return false
	if not ClassDB.class_exists("SQLite"):
		error = "The database library (libgdsqlite) was not found next to the game."
		return false
	var db: Object = ClassDB.instantiate("SQLite")
	db.path = path
	db.verbosity_level = 0
	if not db.open_db():
		error = "Could not open the game library: %s" % db.error_message
		return false
	_db = db
	_run("PRAGMA journal_mode = WAL")
	_run("PRAGMA synchronous = NORMAL")
	_run("PRAGMA busy_timeout = 15000")
	if not _create_schema():
		close()
		return false
	return true


func close() -> void:
	if _db != null:
		_db.close_db()
		_db = null


# --- sources ---------------------------------------------------------------

# Returns the id of the collection with this name, creating it when needed.
func add_source(source_name: String, kind: String = KIND_IMPORT, origin: String = "") -> int:
	var existing := _select("SELECT id FROM sources WHERE name = ? AND kind = ?", [source_name, kind])
	if not existing.is_empty():
		return int((existing[0] as Dictionary)["id"])
	_exec("INSERT INTO sources (name, kind, origin, added, games) VALUES (?, ?, ?, ?, 0)", [source_name, kind, origin, int(Time.get_unix_time_from_system())])
	return _db.last_insert_rowid


func mine_source() -> int:
	return add_source("My games", KIND_MINE)


# [{id, name, kind, origin, added, games}], my games first.
func sources() -> Array:
	return _select("SELECT id, name, kind, origin, added, games FROM sources ORDER BY (kind = 'mine') DESC, name COLLATE NOCASE")


func source(id: int) -> Dictionary:
	var rows := _select("SELECT id, name, kind, origin, added, games FROM sources WHERE id = ?", [id])
	return {} if rows.is_empty() else rows[0]


func rename_source(id: int, new_name: String) -> void:
	_exec("UPDATE sources SET name = ? WHERE id = ?", [new_name, id])


# Deletes a collection and all its games.
func remove_source(id: int) -> void:
	_run("BEGIN")
	_exec("DELETE FROM games WHERE source_id = ?", [id])
	_exec("DELETE FROM sources WHERE id = ?", [id])
	_run("COMMIT")


# --- adding games ----------------------------------------------------------

# Turns a game from PgnReader into a database row, or returns an empty
# dictionary when it should be skipped (other chess variants, no moves).
static func record_from(game: Dictionary) -> Dictionary:
	var tags: Dictionary = game["tags"]
	var variant := str(tags.get("Variant", "Standard"))
	if variant != "Standard" and variant != "" and variant.to_lower() != "chess":
		return {}
	var sans: PackedStringArray = game["sans"]
	if sans.is_empty() or not _plausible(sans):
		return {}
	return record(tags, sans, str(game["result"]))


# The same from tags, moves and result (used for your own games too).
static func record(tags: Dictionary, sans: PackedStringArray, result: String) -> Dictionary:
	var date := str(tags.get("Date", tags.get("UTCDate", "")))
	var start_fen := str(tags.get("FEN", ""))
	var kept := {}
	for key in KEPT_TAGS:
		if tags.has(key) and str(tags[key]) != "":
			kept[key] = str(tags[key])
	var line := PackedStringArray()
	if start_fen == "" or start_fen == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1":
		start_fen = ""
		line = sans.slice(0, LINE_PLIES)
	var text := " ".join(sans)
	var white := str(tags.get("White", "?"))
	var black := str(tags.get("Black", "?"))
	return {
		"white": white,
		"black": black,
		"white_elo": _number(tags.get("WhiteElo", "")),
		"black_elo": _number(tags.get("BlackElo", "")),
		"result": result,
		"date": date,
		"year": _number(date.substr(0, 4)) if date.length() >= 4 else 0,
		"event": str(tags.get("Event", "")),
		"site": str(tags.get("Site", "")),
		"eco": str(tags.get("ECO", "")),
		"opening": str(tags.get("Opening", "")),
		"plies": sans.size(),
		"start_fen": start_fen,
		"sans": text,
		"opening_line": " ".join(line),
		"tags": "" if kept.is_empty() else JSON.stringify(kept),
		"hash": fingerprint("%s|%s|%s|%s|%s|%s|%d" % [white, black, date, tags.get("Round", ""), result, text.substr(0, 240), text.length()]),
	}


# Adds rows made by record(). Games already in that collection are skipped.
# Returns how many were new.
func add_games(source_id: int, rows: Array) -> int:
	if _db == null or rows.is_empty():
		return 0
	var before := _scalar("SELECT total_changes()")
	_run("BEGIN")
	for entry in rows:
		var row := entry as Dictionary
		_exec(
			"INSERT OR IGNORE INTO games (source_id, hash, white, black, white_elo, black_elo, result, date, year, event, site, eco, opening, plies, start_fen, sans, opening_line, tags, added) " +
			"VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
			[source_id, row["hash"], row["white"], row["black"], row["white_elo"], row["black_elo"], row["result"], row["date"], row["year"],
				row["event"], row["site"], row["eco"], row["opening"], row["plies"], row["start_fen"], row["sans"], row["opening_line"], row["tags"],
				int(Time.get_unix_time_from_system())])
	_run("COMMIT")
	var added := _scalar("SELECT total_changes()") - before
	refresh_count(source_id)
	return added


# Adds one game and returns its id (the existing game's id when it is already
# there, 0 on failure).
func add_game(source_id: int, row: Dictionary) -> int:
	add_games(source_id, [row])
	return _scalar("SELECT id FROM games WHERE source_id = ? AND hash = ?", [source_id, row["hash"]])


func refresh_count(source_id: int) -> void:
	_exec("UPDATE sources SET games = (SELECT COUNT(*) FROM games WHERE source_id = ?) WHERE id = ?", [source_id, source_id])


# --- finding games ---------------------------------------------------------

# Filters (all optional): sources (Array of ids), text (player, event or
# opening), white, black, result, year_from, year_to, min_elo, eco (prefix),
# line (Array of moves the game must start with).
# Sorting: "date" (default, newest first), "oldest", "rating", "length".
func search(filters: Dictionary, limit: int = 100, offset: int = 0) -> Array:
	var where := _where(filters, _mostly_everything(filters))
	# These two orders follow the date index, so a page of a huge library is
	# found without sorting every game.
	var order := "date DESC, id DESC"
	match str(filters.get("sort", "date")):
		"oldest":
			order = "date ASC, id ASC"
		"rating":
			order = "MAX(white_elo, black_elo) DESC, id DESC"  # follows games_rating
		"length":
			order = "plies DESC, id DESC"
	var bindings: Array = (where[1] as Array).duplicate()
	bindings.append(limit)
	bindings.append(offset)
	return _select("SELECT %s FROM games%s ORDER BY %s LIMIT ? OFFSET ?" % [COLUMNS, where[0], order], bindings)


# How many games the library holds (from the collection counters, so it is
# instant even for millions of games).
func total_games() -> int:
	return _scalar("SELECT COALESCE(SUM(games), 0) FROM sources")


func count(filters: Dictionary) -> int:
	var where := _where(filters)
	return _scalar("SELECT COUNT(*) FROM games" + str(where[0]), where[1] as Array)


# One game with its moves, or an empty dictionary.
func game(id: int) -> Dictionary:
	var rows := _select("SELECT %s, sans, tags, note FROM games WHERE id = ?" % COLUMNS, [id])
	if rows.is_empty():
		return {}
	var row: Dictionary = rows[0]
	row["sans"] = PackedStringArray(str(row["sans"]).split(" ", false))
	var extra := {}
	if str(row.get("tags", "")) != "":
		var parsed: Variant = JSON.parse_string(str(row["tags"]))
		if parsed is Dictionary:
			extra = parsed
	row["extra"] = extra
	return row


# The PGN text of a stored game.
func pgn_of(id: int) -> String:
	var row := game(id)
	if row.is_empty():
		return ""
	var info := {
		"Event": str(row["event"]) if str(row["event"]) != "" else "?",
		"Site": str(row["site"]) if str(row["site"]) != "" else "?",
		"Date": str(row["date"]) if str(row["date"]) != "" else "????.??.??",
		"White": row["white"],
		"Black": row["black"],
	}
	if int(row["white_elo"]) > 0:
		info["WhiteElo"] = str(row["white_elo"])
	if int(row["black_elo"]) > 0:
		info["BlackElo"] = str(row["black_elo"])
	if str(row["eco"]) != "":
		info["ECO"] = row["eco"]
	if str(row["opening"]) != "":
		info["Opening"] = row["opening"]
	info.merge(row["extra"] as Dictionary, false)
	return Pgn.export_game(info, row["sans"] as PackedStringArray, str(row["result"]), str(row["start_fen"]))


func set_note(id: int, note: String) -> void:
	_exec("UPDATE games SET note = ? WHERE id = ?", [note, id])


# Deletes games by id. Returns how many were removed.
func delete_games(ids: Array) -> int:
	if ids.is_empty():
		return 0
	var touched := {}
	_run("BEGIN")
	var removed := 0
	for id in ids:
		var rows := _select("SELECT source_id FROM games WHERE id = ?", [int(id)])
		if rows.is_empty():
			continue
		touched[int((rows[0] as Dictionary)["source_id"])] = true
		_exec("DELETE FROM games WHERE id = ?", [int(id)])
		removed += 1
	_run("COMMIT")
	for source_id in touched:
		refresh_count(int(source_id))
	return removed


# --- opening explorer ------------------------------------------------------

# What was played after `line` (the moves so far from the starting position).
# Returns [{move, games, white, draw, black}] with the most played first.
func explorer(line: PackedStringArray, source_ids: Array, limit: int = 12) -> Array:
	if line.size() >= LINE_PLIES:
		return []
	var prefix := _prefix(line)
	var args: Array = [prefix.length() + 1]
	var sql := "SELECT nxt AS move, COUNT(*) AS games, SUM(result = '1-0') AS white, SUM(result = '1/2-1/2') AS draw, SUM(result = '0-1') AS black FROM (" + \
		"SELECT CASE WHEN instr(rest, ' ') > 0 THEN substr(rest, 1, instr(rest, ' ') - 1) ELSE rest END AS nxt, result FROM (" + \
		"SELECT substr(opening_line, ?) AS rest, result FROM games WHERE opening_line <> ''"
	if not source_ids.is_empty():
		sql += " AND source_id IN (%s)" % _int_list(source_ids)
	if prefix != "":
		sql += " AND opening_line >= ? AND opening_line < ?"
		args.append(prefix)
		args.append(_prefix_end(prefix))
	sql += ")) WHERE nxt <> '' GROUP BY nxt ORDER BY games DESC, nxt LIMIT ?"
	args.append(limit)
	return _select(sql, args)


# How many stored games start with this line.
func line_count(line: PackedStringArray, source_ids: Array) -> int:
	var filters := {"line": line}
	if not source_ids.is_empty():
		filters["sources"] = source_ids
	return count(filters)


# --- helpers ---------------------------------------------------------------

# Moves in algebraic notation only. Text that is not chess (a damaged file,
# or something that is not a PGN) is refused instead of being stored.
static var _san_pattern: RegEx


static func _plausible(sans: PackedStringArray) -> bool:
	if _san_pattern == null:
		_san_pattern = RegEx.new()
		_san_pattern.compile("^(?:(?:O-O(?:-O)?|[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?)[+#]?)(?: (?:O-O(?:-O)?|[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?)[+#]?)*$")
	return _san_pattern.search(" ".join(sans)) != null


static func fingerprint(text: String) -> int:
	var h := FNV_BASIS
	for b in text.to_utf8_buffer():
		h = (h ^ int(b)) * FNV_PRIME
	return h


# An existing file must start with the SQLite header, so a text file is refused
# without confusing the database library.
static func _looks_like_database(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return true
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	var empty := file.get_length() == 0
	var header := file.get_buffer(15).get_string_from_ascii()
	file.close()
	return empty or header == "SQLite format 3"


static func _number(value: Variant) -> int:
	var text := str(value).strip_edges()
	return int(text) if text.is_valid_int() else 0


static func _prefix(line: PackedStringArray) -> String:
	return "" if line.is_empty() else " ".join(line) + " "


static func _prefix_end(prefix: String) -> String:
	# The prefix ends with a space (0x20); the next character bounds the range.
	return prefix.substr(0, prefix.length() - 1) + "!"


static func _int_list(values: Array) -> String:
	var parts := PackedStringArray()
	for value in values:
		parts.append(str(int(value)))
	return ",".join(parts)


static func _like(text: String) -> String:
	return "%" + text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"


# True when the chosen collections hold most of the library. Then the date and
# rating indexes find a page fastest, and the collection is checked row by row
# (the unary plus keeps the planner from sorting a huge collection instead).
func _mostly_everything(f: Dictionary) -> bool:
	if not f.has("sources") or (f["sources"] as Array).is_empty():
		return false
	var inside := _scalar("SELECT COALESCE(SUM(games), 0) FROM sources WHERE id IN (%s)" % _int_list(f["sources"] as Array))
	return inside * 4 > total_games()


func _where(f: Dictionary, scan_by_order: bool = false) -> Array:
	var parts := PackedStringArray()
	var args: Array = []
	if f.has("sources") and not (f["sources"] as Array).is_empty():
		parts.append("%ssource_id IN (%s)" % ["+" if scan_by_order else "", _int_list(f["sources"] as Array)])
	var text := str(f.get("text", "")).strip_edges()
	if text != "":
		parts.append("(white LIKE ? ESCAPE '\\' OR black LIKE ? ESCAPE '\\' OR event LIKE ? ESCAPE '\\' OR opening LIKE ? ESCAPE '\\' OR eco LIKE ? ESCAPE '\\')")
		for _i in 5:
			args.append(_like(text))
	for key in ["white", "black"]:
		var name := str(f.get(key, "")).strip_edges()
		if name != "":
			parts.append("%s LIKE ? ESCAPE '\\'" % key)
			args.append(_like(name))
	var result := str(f.get("result", ""))
	if result in ["1-0", "0-1", "1/2-1/2", "*"]:
		parts.append("result = ?")
		args.append(result)
	if int(f.get("year_from", 0)) > 0:
		parts.append("year >= ?")
		args.append(int(f["year_from"]))
	if int(f.get("year_to", 0)) > 0:
		parts.append("year <= ? AND year > 0")
		args.append(int(f["year_to"]))
	if int(f.get("min_elo", 0)) > 0:
		parts.append("MAX(white_elo, black_elo) >= ?")
		args.append(int(f["min_elo"]))
	var eco := str(f.get("eco", "")).strip_edges()
	if eco != "":
		parts.append("eco LIKE ? ESCAPE '\\'")
		args.append(eco.replace("%", "").replace("_", "") + "%")
	if f.has("line") and not (f["line"] as PackedStringArray).is_empty():
		var line: PackedStringArray = f["line"]
		var whole := " ".join(line)
		if line.size() <= LINE_PLIES:
			parts.append("(opening_line = ? OR (opening_line >= ? AND opening_line < ?))")
			args.append(whole)
			args.append(whole + " ")
			args.append(whole + "!")
		else:
			parts.append("(sans = ? OR (sans >= ? AND sans < ?))")
			args.append(whole)
			args.append(whole + " ")
			args.append(whole + "!")
	if f.has("min_plies") and int(f["min_plies"]) > 0:
		parts.append("plies >= ?")
		args.append(int(f["min_plies"]))
	return [" WHERE " + " AND ".join(parts) if not parts.is_empty() else "", args]


func _create_schema() -> bool:
	var version := _scalar("PRAGMA user_version")
	if version > SCHEMA_VERSION:
		error = "This game library was made by a newer version of NeoChess."
		return false
	if version == 1:
		_remove_damaged_games()
	var statements := [
		"CREATE TABLE IF NOT EXISTS sources (id INTEGER PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL, origin TEXT DEFAULT '', added INTEGER DEFAULT 0, games INTEGER DEFAULT 0)",
		"CREATE TABLE IF NOT EXISTS games (id INTEGER PRIMARY KEY, source_id INTEGER NOT NULL, hash INTEGER NOT NULL, white TEXT, black TEXT, white_elo INTEGER DEFAULT 0, black_elo INTEGER DEFAULT 0, " +
			"result TEXT, date TEXT, year INTEGER DEFAULT 0, event TEXT, site TEXT, eco TEXT, opening TEXT, plies INTEGER DEFAULT 0, start_fen TEXT DEFAULT '', sans TEXT, opening_line TEXT DEFAULT '', tags TEXT DEFAULT '', note TEXT DEFAULT '', added INTEGER DEFAULT 0)",
		"CREATE UNIQUE INDEX IF NOT EXISTS games_unique ON games (source_id, hash)",
		"CREATE INDEX IF NOT EXISTS games_line ON games (opening_line)",
		"CREATE INDEX IF NOT EXISTS games_date ON games (date)",
		"CREATE INDEX IF NOT EXISTS games_rating ON games (MAX(white_elo, black_elo))",
		"CREATE INDEX IF NOT EXISTS games_plies ON games (plies)",
		"CREATE INDEX IF NOT EXISTS games_white ON games (white COLLATE NOCASE)",
		"CREATE INDEX IF NOT EXISTS games_black ON games (black COLLATE NOCASE)",
	]
	for statement in statements:
		if not _run(statement):
			error = "Could not prepare the game library: %s" % _db.error_message
			return false
	_run("PRAGMA user_version = %d" % SCHEMA_VERSION)
	return true


# Version 1 libraries could hold "games" made of tag lines and half-cut move
# lines (a release build read PGN files wrongly). Remove them once; importing the
# file again brings the real games in.
func _remove_damaged_games() -> void:
	var damaged := "sans LIKE '%\"%' OR sans LIKE '%]%' OR substr(sans, 1, 1) NOT IN ('a','b','c','d','e','f','g','h','N','B','R','Q','K','O')"
	if _scalar("SELECT COUNT(*) FROM games WHERE " + damaged) == 0:
		return
	for index_name in ["games_line", "games_date", "games_white", "games_black"]:
		_run("DROP INDEX IF EXISTS " + index_name)
	_run("BEGIN")
	_run("DELETE FROM games WHERE " + damaged)
	_run("COMMIT")
	for entry in _select("SELECT id FROM sources"):
		refresh_count(int((entry as Dictionary)["id"]))
	_run("DELETE FROM sources WHERE kind = 'import' AND games = 0")


func _run(sql: String) -> bool:
	return _db != null and _db.query(sql)


func _exec(sql: String, args: Array = []) -> bool:
	return _db != null and _db.query_with_bindings(sql, args)


func _select(sql: String, args: Array = []) -> Array:
	if _db == null:
		return []
	if not _db.query_with_bindings(sql, args):
		error = _db.error_message
		return []
	return _db.query_result.duplicate(true)


func _scalar(sql: String, args: Array = []) -> int:
	var rows := _select(sql, args)
	if rows.is_empty():
		return 0
	var row: Dictionary = rows[0]
	for key in row:
		return int(row[key])
	return 0
