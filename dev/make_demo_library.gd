extends SceneTree

# Builds a small sample game library for the documentation screenshots:
#   godot --headless --path . --script dev/make_demo_library.gd -- <out.db>
# The games are made up: real opening lines followed by random legal moves, with
# invented players. They only exist to give the library window and the opening
# book something to show. Not part of the test suite.

const OPENINGS := [
	# [name, ECO, weight, moves]
	["Sicilian Defense: Najdorf Variation", "B90", 9, "e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 Be3 e5"],
	["Sicilian Defense: Open", "B33", 8, "e4 c5 Nf3 Nc6 d4 cxd4 Nxd4 Nf6 Nc3 e5"],
	["Ruy Lopez: Closed", "C84", 9, "e4 e5 Nf3 Nc6 Bb5 a6 Ba4 Nf6 O-O Be7 Re1 b5 Bb3 d6"],
	["Ruy Lopez: Exchange Variation", "C69", 7, "e4 e5 Nf3 Nc6 Bb5 a6 Bxc6 dxc6 O-O f6 d4 exd4"],
	["Ruy Lopez: Berlin Defense", "C67", 5, "e4 e5 Nf3 Nc6 Bb5 Nf6 O-O Nxe4 d4 Nd6"],
	["Italian Game: Giuoco Piano", "C54", 6, "e4 e5 Nf3 Nc6 Bc4 Bc5 c3 Nf6 d3 d6"],
	["French Defense: Classical", "C11", 6, "e4 e6 d4 d5 Nc3 Nf6 Bg5 Be7 e5 Nfd7"],
	["Caro-Kann Defense: Classical", "B18", 6, "e4 c6 d4 d5 Nc3 dxe4 Nxe4 Bf5 Ng3 Bg6"],
	["Scandinavian Defense", "B01", 3, "e4 d5 exd5 Qxd5 Nc3 Qa5 d4 Nf6"],
	["Pirc Defense", "B07", 3, "e4 d6 d4 Nf6 Nc3 g6 Nf3 Bg7"],
	["Queen's Gambit Declined", "D37", 8, "d4 d5 c4 e6 Nc3 Nf6 Nf3 Be7 Bf4 O-O"],
	["Slav Defense", "D17", 5, "d4 d5 c4 c6 Nf3 Nf6 Nc3 dxc4 a4 Bf5"],
	["King's Indian Defense: Classical", "E91", 7, "d4 Nf6 c4 g6 Nc3 Bg7 e4 d6 Nf3 O-O Be2 e5"],
	["Nimzo-Indian Defense", "E32", 6, "d4 Nf6 c4 e6 Nc3 Bb4 Qc2 O-O a3 Bxc3+ Qxc3 b6"],
	["English Opening: Symmetrical", "A30", 6, "c4 c5 Nf3 Nf6 Nc3 Nc6 g3 d5 cxd5 Nxd5"],
	["English Opening: King's English", "A28", 4, "c4 e5 Nc3 Nf6 Nf3 Nc6 e3 Bb4 Qc2 Bxc3"],
	["Reti Opening", "A07", 3, "Nf3 d5 g3 Nf6 Bg2 c6 O-O Bg4"],
]

const FIRST := ["Magnus", "Hikaru", "Fabi", "Alireza", "Ian", "Wesley", "Levon", "Anish", "Maxime", "Nodirbek", "Richard", "Jan", "Sam", "Ding", "Vidit", "Gukesh"]
const LAST := ["Nova", "Pilot", "Quartz", "Atlas", "Ember", "Falcon", "Harbor", "Lynx", "Orbit", "Raven", "Summit", "Tundra"]

var rng := RandomNumberGenerator.new()


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <out.db>")
		quit(2)
		return
	var path := String(args[0])
	for suffix in ["", "-wal", "-shm"]:
		DirAccess.remove_absolute(path + suffix)
	rng.seed = 20251104
	var store := GameStore.new()
	if not store.open(path):
		print("cannot open: ", store.error)
		quit(1)
		return

	var total_weight := 0
	for opening in OPENINGS:
		total_weight += int(opening[2])

	var sample := store.add_source("Sample games", GameStore.KIND_IMPORT, "made up for the documentation")
	var rows: Array = []
	for n in 300:
		var pick := rng.randi_range(1, total_weight)
		var chosen: Array = OPENINGS[0]
		for opening in OPENINGS:
			pick -= int(opening[2])
			if pick <= 0:
				chosen = opening
				break
		rows.append(_make_game(chosen, n))
	store.add_games(sample, rows)
	store.refresh_count(sample)

	var mine := store.mine_source()
	var mine_rows: Array = []
	mine_rows.append(_make_named(OPENINGS[2], "You", "Stockfish 19", 1500, 2200, "0-1", "2025.10.02", 64))
	mine_rows.append(_make_named(OPENINGS[9], "Stockfish 19", "You", 2000, 1500, "1/2-1/2", "2025.10.03", 72))
	mine_rows.append(_make_named(OPENINGS[4], "You", "Stockfish 19", 1500, 1800, "1-0", "2025.10.04", 48))
	store.add_games(mine, mine_rows)
	store.refresh_count(mine)

	print("demo library: %d games" % store.total_games())
	store.close()
	quit()


func _name() -> String:
	return "%s%s%d" % [FIRST[rng.randi() % FIRST.size()], LAST[rng.randi() % LAST.size()], rng.randi_range(1, 99)]


func _make_game(opening: Array, n: int) -> Dictionary:
	var white_elo := rng.randi_range(2250, 2750)
	var black_elo := rng.randi_range(2250, 2750)
	var strong := white_elo - black_elo
	var roll := rng.randf() - float(strong) / 4000.0
	var result := "1-0" if roll < 0.40 else ("1/2-1/2" if roll < 0.62 else "0-1")
	var date := "%d.%02d.%02d" % [rng.randi_range(2024, 2025), rng.randi_range(1, 11), rng.randi_range(1, 28)]
	var game := _make_named(opening, _name(), _name(), white_elo, black_elo, result, date, rng.randi_range(30, 70))
	game["hash"] = 1000 + n
	return game


func _make_named(opening: Array, white: String, black: String, white_elo: int, black_elo: int, result: String, date: String, length: int) -> Dictionary:
	var game := ChessGame.new()
	var sans := PackedStringArray()
	for token in String(opening[3]).split(" "):
		var found := Pgn.find_move(game, token)
		var move: Dictionary = found.get("move", {})
		if move.is_empty():
			push_error("illegal demo opening %s at %s" % [opening[0], token])
			break
		sans.append(game.to_san(move))
		game.make_move(move)
	while sans.size() < length:
		var legal := game.legal_moves()
		if game.state_of(legal) != "":
			break
		var move: Dictionary = legal[rng.randi() % legal.size()]
		sans.append(game.to_san(move))
		game.make_move(move)
	var final_state := game.state_of(game.legal_moves())
	if final_state == "checkmate":
		result = "0-1" if game.white_to_move else "1-0"
	var tags := {
		"Event": "Rated Blitz game" if length % 3 else "Rated Rapid game",
		"Site": "https://lichess.org/",
		"Date": date,
		"White": white,
		"Black": black,
		"WhiteElo": str(white_elo),
		"BlackElo": str(black_elo),
		"ECO": opening[1],
		"Opening": opening[0],
	}
	return GameStore.record(tags, sans, result)
