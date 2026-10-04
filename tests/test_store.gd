extends "res://tests/test_base.gd"

# The game library: reading PGN files quickly, storing games in SQLite,
# searching them and answering the opening explorer. Uses a temporary database.

var work := ""
var store: GameStore

const SAMPLE := """[Event "Rated Blitz game"]
[Site "lichess.org"]
[Date "2023.12.01"]
[White "Alice"]
[Black "Bob"]
[Result "1-0"]
[ECO "C65"]
[WhiteElo "2757"]
[BlackElo "2650"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 Nf6 4. O-O Nxe4 5. d4 Nd6 6. Bxc6 dxc6 7. dxe5 Nf5 8. Qxd8+ Kxd8 1-0

[Event "Rated Classical game"]
[Site "lichess.org"]
[Date "2023.12.02"]
[White "Carol"]
[Black "Alice"]
[Result "1/2-1/2"]
[ECO "C50"]
[WhiteElo "2500"]
[BlackElo "2757"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d3 d6 1/2-1/2

[Event "Casual"]
[Site "?"]
[Date "2022.05.06"]
[White "Dave"]
[Black "Erin"]
[Result "0-1"]

1. d4 {the queen's pawn} d5 (1... Nf6 2. c4) 2. c4 $1 e6 3. Nc3 Nf6 4. Bg5 Be7 0-1

[Event "Variant"]
[Variant "Atomic"]
[Result "1-0"]

1. e4 e5 1-0

[Event "Setup"]
[Result "*"]
[SetUp "1"]
[FEN "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1"]

1. e4 Kd7 *
"""


func run() -> void:
	work = OS.get_user_data_dir().path_join("test_store")
	DirAccess.make_dir_recursive_absolute(work)
	_movetext()
	_reader()
	_store_basics()
	_search()
	_explorer()
	_deleting()
	_two_connections()
	_not_chess()
	_damaged_library_is_cleaned()
	_corrupt_and_future()
	_cleanup()


func _write(name: String, text: String) -> String:
	var file_path := work.path_join(name)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return file_path


func _movetext() -> void:
	var plain := PgnReader.parse_movetext("1. e4 e5 2. Nf3 Nc6 1-0")
	expect("plain moves", ",".join(plain["sans"]), "e4,e5,Nf3,Nc6")
	expect("plain result", plain["result"], "1-0")
	var annotated := PgnReader.parse_movetext("1. e4! e5?! 2. Nf3 {a comment} Nc6 $1 3. Bb5 (3. Bc4 Bc5 (3... Nf6)) 3... a6 *")
	expect("annotations are removed", ",".join(annotated["sans"]), "e4,e5,Nf3,Nc6,Bb5,a6")
	expect("unfinished game", annotated["result"], "*")
	expect("glued numbers", ",".join(PgnReader.parse_movetext("1.e4 e5 2.Nf3")["sans"]), "e4,e5,Nf3")
	expect("black numbers", ",".join(PgnReader.parse_movetext("1... e5 2. Nf3")["sans"]), "e5,Nf3")
	expect("checks are kept", ",".join(PgnReader.parse_movetext("1. e4 e5 2. Qh5 Nc6 3. Qxf7# 1-0")["sans"]), "e4,e5,Qh5,Nc6,Qxf7#")
	expect("castling and promotion", ",".join(PgnReader.parse_movetext("1. O-O O-O-O 2. e8=Q+")["sans"]), "O-O,O-O-O,e8=Q+")
	expect("line comment", ",".join(PgnReader.parse_movetext("1. e4 ; a note\n e5")["sans"]), "e4,e5")
	expect("empty", PgnReader.parse_movetext("")["sans"].size(), 0)


func _reader() -> void:
	var path := _write("sample.pgn", SAMPLE)
	var reader := PgnReader.new(FileAccess.open(path, FileAccess.READ))
	var games: Array = []
	while true:
		var next := reader.next_game()
		if next.is_empty():
			break
		games.append(next)
	expect("five games are read", games.size(), 5)
	expect("games counted", reader.games_read, 5)
	var first: Dictionary = games[0]
	expect("white", (first["tags"] as Dictionary)["White"], "Alice")
	expect("moves", (first["sans"] as PackedStringArray).size(), 16)
	expect("result", first["result"], "1-0")
	var third: Dictionary = games[2]
	expect("comments and variations are skipped", ",".join(third["sans"]), "d4,d5,c4,e6,Nc3,Nf6,Bg5,Be7")
	expect("result 0-1", third["result"], "0-1")
	expect("a game without tags ends the file", reader.next_game().is_empty(), true)

	# Windows line endings, a BOM, and games with no blank line between them.
	var messy := "\ufeff[White \"A\"]\r\n[Black \"B\"]\r\n[Result \"1-0\"]\r\n\r\n1. e4 e5 1-0\r\n[White \"C\"]\r\n[Black \"D\"]\r\n\r\n1. d4 d5 1/2-1/2\r\n"
	var messy_reader := PgnReader.new(FileAccess.open(_write("messy.pgn", messy), FileAccess.READ))
	var a := messy_reader.next_game()
	var b := messy_reader.next_game()
	expect("crlf first game", (a["tags"] as Dictionary)["White"], "A")
	expect("crlf moves", ",".join(a["sans"]), "e4,e5")
	expect("games without a blank line", (b["tags"] as Dictionary)["White"], "C")
	expect("result from the moves", b["result"], "1/2-1/2")
	expect("empty file", PgnReader.new(FileAccess.open(_write("empty.pgn", ""), FileAccess.READ)).next_game().is_empty(), true)
	var braces := "[White \"A\"]\n[Black \"B\"]\n\n1. e4 {a long\n\ncomment with a blank line} e5 *\n"
	var braces_game := PgnReader.new(FileAccess.open(_write("braces.pgn", braces), FileAccess.READ)).next_game()
	expect("comment spanning a blank line", ",".join(braces_game["sans"]), "e4,e5")


func _load_sample() -> int:
	var reader := PgnReader.new(FileAccess.open(work.path_join("sample.pgn"), FileAccess.READ))
	var rows: Array = []
	while true:
		var next := reader.next_game()
		if next.is_empty():
			break
		var row := GameStore.record_from(next)
		if not row.is_empty():
			rows.append(row)
	var source := store.add_source("Sample", GameStore.KIND_IMPORT, "sample.pgn")
	store.add_games(source, rows)
	return source


func _store_basics() -> void:
	var db_path := work.path_join("library.db")
	store = GameStore.new()
	expect("database opens", store.open(db_path), true)
	expect("database is open", store.is_open(), true)
	var mine := store.mine_source()
	expect("my games source", store.mine_source(), mine)
	expect("sources start with mine", int((store.sources()[0] as Dictionary)["id"]), mine)
	var sample := _load_sample()
	expect("variants and empty games are skipped", store.count({"sources": [sample]}), 4)
	expect("source count is kept", int(store.source(sample)["games"]), 4)
	_load_sample()
	expect("importing twice adds nothing", store.count({"sources": [sample]}), 4)
	expect("source count unchanged", int(store.source(sample)["games"]), 4)

	var found := store.search({"white": "Alice"}, 10)
	expect("a stored game", found.size(), 1)
	var id := int((found[0] as Dictionary)["id"])
	var full := store.game(id)
	expect("moves are stored", (full["sans"] as PackedStringArray).size(), 16)
	expect("elo", full["white_elo"], 2757)
	expect("year", full["year"], 2023)
	expect("eco", full["eco"], "C65")
	expect("unknown game", store.game(999999).is_empty(), true)

	var pgn := store.pgn_of(id)
	var parsed := Pgn.parse(pgn)
	expect("a stored game exports as valid PGN", bool(parsed["ok"]), true)
	expect("exported white", (parsed["headers"] as Dictionary)["White"], "Alice")
	expect("exported moves", (parsed["sans"] as Array).size(), 16)
	expect("exported result", parsed["result"], "1-0")

	# A game with a set-up position keeps its start position and has no line.
	var setup := store.search({"text": "Setup"}, 10)
	expect("setup game is skipped as a variant-free game", setup.size(), 1)
	expect("start position kept", str((setup[0] as Dictionary)["start_fen"]), "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1")


func _search() -> void:
	expect("search all", store.search({}, 100).size(), 4)
	expect("limit", store.search({}, 2).size(), 2)
	expect("offset", store.search({}, 100, 3).size(), 1)
	expect("player either colour", store.count({"text": "alice"}), 2)
	expect("white only", store.count({"white": "alice"}), 1)
	expect("black only", store.count({"black": "alice"}), 1)
	expect("event text", store.count({"text": "Blitz"}), 1)
	expect("result filter", store.count({"result": "1/2-1/2"}), 1)
	expect("white wins", store.count({"result": "1-0"}), 1)
	expect("year from", store.count({"year_from": 2023}), 2)
	expect("year to", store.count({"year_to": 2022}), 1)
	expect("year range", store.count({"year_from": 2023, "year_to": 2023}), 2)
	expect("minimum rating", store.count({"min_elo": 2700}), 2)
	expect("eco prefix", store.count({"eco": "C"}), 2)
	expect("eco exact", store.count({"eco": "C65"}), 1)
	expect("line", store.count({"line": PackedStringArray(["e4", "e5"])}), 2)
	expect("deeper line", store.count({"line": PackedStringArray(["e4", "e5", "Nf3", "Nc6", "Bb5"])}), 1)
	expect("line is a move prefix, not text", store.count({"line": PackedStringArray(["e"])}), 0)
	expect("filters combine", store.count({"text": "alice", "result": "1-0"}), 1)
	expect("no match", store.count({"text": "nobody"}), 0)
	expect("like characters are literal", store.count({"text": "100%"}), 0)
	expect("quote characters are safe", store.count({"text": "'; DROP TABLE games; --"}), 0)
	expect("table survived", store.count({}), 4)
	var newest := store.search({"sort": "date"}, 10)
	expect("newest first", str((newest[0] as Dictionary)["date"]), "2023.12.02")
	var oldest := store.search({"sort": "oldest", "year_from": 1}, 10)  # games without a date come first otherwise
	expect("oldest first", str((oldest[0] as Dictionary)["date"]), "2022.05.06")
	expect("rating order", int((store.search({"sort": "rating"}, 10)[0] as Dictionary)["white_elo"]) >= 2500, true)
	expect("length order", int((store.search({"sort": "length"}, 10)[0] as Dictionary)["plies"]), 16)


func _explorer() -> void:
	var root_moves := store.explorer(PackedStringArray(), [])
	var first: Dictionary = root_moves[0]
	expect("most played first move", first["move"], "e4")
	expect("e4 was played in two games", first["games"], 2)
	expect("e4 white wins", first["white"], 1)
	expect("e4 draws", first["draw"], 1)
	expect("e4 black wins", first["black"], 0)
	expect("other first move", str((root_moves[1] as Dictionary)["move"]), "d4")
	expect("setup games stay out of the book", root_moves.size(), 2)

	var after_e4 := store.explorer(PackedStringArray(["e4"]), [])
	expect("reply", str((after_e4[0] as Dictionary)["move"]), "e5")
	expect("reply count", (after_e4[0] as Dictionary)["games"], 2)
	var after_three := store.explorer(PackedStringArray(["e4", "e5", "Nf3", "Nc6"]), [])
	expect("two third moves", after_three.size(), 2)
	var moves := PackedStringArray()
	for entry in after_three:
		moves.append(str((entry as Dictionary)["move"]))
	moves.sort()
	expect("both bishop moves", ",".join(moves), "Bb5,Bc4")
	expect("unknown line", store.explorer(PackedStringArray(["h4", "h5"]), []).size(), 0)
	expect("end of a game has no next move", store.explorer(PackedStringArray(["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "c3", "Nf6", "d3", "d6"]), []).size(), 0)
	var too_deep := PackedStringArray()
	for _i in 30:
		too_deep.append("e4")
	expect("past the book depth", store.explorer(too_deep, []).size(), 0)
	expect("a prefix of a move is not a match", store.explorer(PackedStringArray(["e"]), []).size(), 0)

	var sample := int((store.sources()[1] as Dictionary)["id"])
	expect("restricted to a source", store.explorer(PackedStringArray(), [sample]).size(), 2)
	expect("other source is empty", store.explorer(PackedStringArray(), [store.mine_source()]).size(), 0)
	expect("games on the line", store.line_count(PackedStringArray(["e4", "e5", "Nf3"]), []), 2)


func _deleting() -> void:
	var mine := store.mine_source()
	var tags := {"White": "Me", "Black": "Stockfish 19", "Date": "2026.10.04", "Event": "NeoChess"}
	var row := GameStore.record(tags, PackedStringArray(["e4", "e5", "Nf3"]), "*")
	expect("my game is added", store.add_games(mine, [row]), 1)
	expect("same game again is ignored", store.add_games(mine, [row]), 0)
	expect("my games count", int(store.source(mine)["games"]), 1)
	expect("explorer counts my game", int((store.explorer(PackedStringArray(["e4", "e5"]), [mine])[0] as Dictionary)["games"]), 1)
	expect("unfinished games are not counted as results", (store.explorer(PackedStringArray(["e4", "e5"]), [mine])[0] as Dictionary)["white"], 0)

	var id := int((store.search({"sources": [mine]}, 10)[0] as Dictionary)["id"])
	store.set_note(id, "revisit move 3")
	expect("note is saved", str(store.game(id)["note"]), "revisit move 3")
	expect("delete reports the count", store.delete_games([id, 424242]), 1)
	expect("game is gone", store.game(id).is_empty(), true)
	expect("count follows", int(store.source(mine)["games"]), 0)
	expect("explorer forgets it", store.explorer(PackedStringArray(["e4", "e5"]), [mine]).size(), 0)
	expect("deleting nothing", store.delete_games([]), 0)

	var other := store.add_source("Temporary")
	store.add_games(other, [GameStore.record({"White": "X", "Black": "Y"}, PackedStringArray(["c4"]), "1-0")])
	expect("temporary source has a game", store.count({"sources": [other]}), 1)
	store.remove_source(other)
	expect("removed source has no games", store.count({"sources": [other]}), 0)
	expect("removed source is gone", store.source(other).is_empty(), true)
	expect("other games are untouched", store.count({}), 4)
	expect("rename", (func() -> String:
		var s := store.add_source("Old name")
		store.rename_source(s, "New name")
		return str(store.source(s)["name"])).call(), "New name")


func _two_connections() -> void:
	# The importer writes from another thread through its own connection.
	var second := GameStore.new()
	expect("second connection", second.open(store.path), true)
	var source := second.add_source("From another connection")
	second.add_games(source, [GameStore.record({"White": "T", "Black": "U"}, PackedStringArray(["Nf3"]), "1-0")])
	expect("first connection sees the write", store.count({"sources": [source]}), 1)
	var worker := Thread.new()
	worker.start(func() -> int:
		var third := GameStore.new()
		third.open(store.path)
		var rows: Array = []
		for i in 200:
			rows.append(GameStore.record({"White": "W%d" % i, "Black": "B"}, PackedStringArray(["e4", "c5"]), "1-0"))
		var added := third.add_games(source, rows)
		third.close()
		return added)
	expect("thread inserted every game", int(worker.wait_to_finish()), 200)
	expect("main thread reads them", store.count({"sources": [source]}), 201)
	second.close()


func _not_chess() -> void:
	var junk := {"tags": {"White": "A", "Black": "B"}, "sans": PackedStringArray(["Event:", "x", "y"]), "result": "*"}
	expect("text that is not chess is not stored", GameStore.record_from(junk).is_empty(), true)
	var fine := {"tags": {"White": "A", "Black": "B"}, "sans": PackedStringArray(["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "O-O", "exd4", "Qxd4+", "Nbd7", "e8=Q#", "R1a3", "O-O-O"]), "result": "*"}
	expect("real moves are stored", GameStore.record_from(fine).is_empty(), false)
	var wrong := {"tags": {"White": "A", "Black": "B"}, "sans": PackedStringArray(["e4", "[Event", "e5"]), "result": "*"}
	expect("a stray tag in the movetext is refused", GameStore.record_from(wrong).is_empty(), true)

func _damaged_library_is_cleaned() -> void:
	var path := work.path_join("old.db")
	var old := GameStore.new()
	old.open(path)
	var mine := old.mine_source()
	var imported := old.add_source("Broken import")
	var mixed := old.add_source("Mixed import")
	old.add_games(mine, [GameStore.record({"White": "Me", "Black": "Stockfish"}, PackedStringArray(["e4", "e5", "Nf3"]), "*")])
	old.add_games(imported, [
		GameStore.record({}, PackedStringArray(["Event \"Rated Blitz game\"]", "LichessURL"]), "*"),
		GameStore.record({}, PackedStringArray([".", "e4", "Nf6", "-1"]), "*"),
	])
	old.add_games(mixed, [
		GameStore.record({"White": "Ann", "Black": "Bob"}, PackedStringArray(["d4", "d5"]), "1-0"),
		GameStore.record({}, PackedStringArray(["Site \"x\"]"]), "*"),
	])
	old._run("PRAGMA user_version = 1")
	old.close()
	var fixed := GameStore.new()
	expect("the old library opens", fixed.open(path), true)
	expect("damaged games are gone, real ones stay", fixed.count({}), 2)
	expect("the broken import is removed", fixed.sources().size(), 2)
	expect("my games keep their game", int(fixed.source(mine)["games"]), 1)
	expect("a mixed import keeps its good game", int(fixed.source(mixed)["games"]), 1)
	fixed.close()
	var again := GameStore.new()
	again.open(path)
	expect("cleaning happens once", again.count({}), 2)
	again.close()

func _corrupt_and_future() -> void:
	var junk := GameStore.new()
	expect("a file that is not a database is refused", junk.open(_write("junk.db", "this is not a database, just text".repeat(50))), false)
	expect_true("the refusal says why", junk.error != "")
	expect("a closed store answers quietly", junk.search({}).size(), 0)
	expect("count on a closed store", junk.count({}), 0)

	var future := GameStore.new()
	future.open(work.path_join("future.db"))
	future._run("PRAGMA user_version = 99")
	future.close()
	var newer := GameStore.new()
	expect("a newer library is not opened", newer.open(work.path_join("future.db")), false)
	expect_true("and says so", newer.error.contains("newer"))

	var reopened := GameStore.new()
	expect("reopening works", reopened.open(store.path), true)
	expect("data survives closing", reopened.count({}) > 0, true)
	reopened.close()
	store.close()
	expect("closed", store.is_open(), false)


func _cleanup() -> void:
	_remove_tree(work)


func _remove_tree(dir_path: String) -> void:
	for file in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(dir_path.path_join(file))
	for folder in DirAccess.get_directories_at(dir_path):
		_remove_tree(dir_path.path_join(folder))
	DirAccess.remove_absolute(dir_path)
