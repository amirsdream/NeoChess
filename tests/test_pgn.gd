extends "res://tests/test_base.gd"

const Rules = preload("res://scripts/chess_game.gd")

# A real-world style game: tags, NAGs, comments, a variation, castling and a
# capture on the final move.
const FULL_GAME := """[Event "Casual Game"]
[Site "Berlin GER"]
[Date "1852.??.??"]
[Round "?"]
[White "Adolf Anderssen"]
[Black "Jean Dufresne"]
[Result "1-0"]
[Annotator "Someone \\"Quoted\\""]

1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.b4 Bxb4 5.c3 Ba5 6.d4 exd4 7.O-O d3 8.Qb3 Qf6 9.e5 Qg6 10.Re1 Nge7
11.Ba3 b5 12.Qxb5 Rb8 13.Qa4 Bb6 14.Nbd2 Bb7 15.Ne4 Qf5 16.Bxd3 Qh5 17.Nf6+ gxf6 18.exf6 Rg8
19.Rad1 Qxf3 20.Rxe7+ Nxe7 21.Qxd7+ Kxd7 22.Bf5+ Ke8 23.Bd7+ Kf8 24.Bxe7# 1-0
"""

const MESSY := """% an escape line that must be ignored
[Event "Messy"]
[Site "?"]
[White "A"]
[Black "B"]
[Result "1/2-1/2"]

{ opening comment [%clk 0:03:00] } 1. e4! $1 {best by test} e5?! ; a rest of line comment
2. Nf3 (2. f4 exf4 3. Nf3 {gambit}) 2... Nc6 3. Bb5 a6 4. Ba4 Nf6 5. 0-0 Be7 6. Re1 b5 7. Bb3 d6
8. c3 O-O 9. h3 Nb8 10. d4 Nbd7 1/2-1/2
"""


const LICHESS := """[Event "Rated Blitz game"]
[Site "https://lichess.org/AbCdEfGh"]
[Date "2024.03.09"]
[White "alice"]
[Black "bob"]
[Result "0-1"]
[UTCDate "2024.03.09"]
[UTCTime "18:02:11"]
[WhiteElo "1850"]
[BlackElo "1902"]
[WhiteRatingDiff "-5"]
[BlackRatingDiff "+5"]
[Variant "Standard"]
[TimeControl "180+0"]
[ECO "C20"]
[Opening "King's Pawn Game"]
[Termination "Normal"]

1. e4 { [%eval 0.2] [%clk 0:03:00] } 1... e5 { [%eval 0.3] [%clk 0:03:00] } 2. Qh5 { [%eval 0.1] } 2... Nc6 3. Bc4 Nf6?? { (Blunder) } 4. Qxf7# 1-0
"""

const CHESSCOM := """[Event "Live Chess"]
[Site "Chess.com"]
[Date "2024.05.01"]
[Round "-"]
[White "carol"]
[Black "dave"]
[Result "1-0"]
[CurrentPosition "r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4"]
[Timezone "UTC"]
[ECO "C20"]
[ECOUrl "https://www.chess.com/openings/Kings-Pawn-Opening"]
[UTCDate "2024.05.01"]
[Termination "carol won by checkmate"]
[StartTime "10:00:00"]
[Link "https://www.chess.com/game/live/1"]

1. e4 {[%clk 0:09:58.9]} 1... e5 {[%clk 0:09:59.1]} 2. Qh5 {[%clk 0:09:57]} 2... Nc6 {[%clk 0:09:58]} 3. Bc4 {[%clk 0:09:56]} 3... Nf6 {[%clk 0:09:55]} 4. Qxf7# {[%clk 0:09:54]} 1-0
"""


func run() -> void:
	_real_world()
	_export()
	_roundtrip()
	_import_variants()
	_errors()
	_find_move()
	_fen_validation()


func _real_world() -> void:
	var lichess := Pgn.parse(LICHESS)
	expect_true("lichess parses", bool(lichess["ok"]), str(lichess["error"]))
	expect("lichess plies", (lichess["moves"] as Array).size(), 7)
	expect("lichess result", str(lichess["result"]), "1-0")
	expect("lichess tag", str(lichess["headers"]["Opening"]), "King's Pawn Game")
	var chesscom := Pgn.parse(CHESSCOM)
	expect_true("chess.com parses", bool(chesscom["ok"]), str(chesscom["error"]))
	expect("chess.com plies", (chesscom["moves"] as Array).size(), 7)
	expect("chess.com tag", str(chesscom["headers"]["Site"]), "Chess.com")

	# The same game as it arrives from a Windows clipboard, a web page or a chat.
	var variants := {
		"windows line endings": LICHESS.replace("\n", "\r\n"),
		"tags on one line": LICHESS.replace("]\n[", "] ["),
		"all on one line": LICHESS.replace("\n\n", " ").replace("\n", " "),
		"non-breaking spaces": LICHESS.replace("\" ", "\"\u00a0").replace("] ", "]\u00a0"),
		"curly quotes": LICHESS.replace("\"", "\u201c"),
		"leading blank lines and spaces": "\n\n   \t" + LICHESS,
		"indented tags": LICHESS.replace("\n[", "\n   ["),
		"trailing spaces": LICHESS.replace("]\n", "]   \n"),
		"byte order mark": "\ufeff" + LICHESS,
		"unicode line separators": LICHESS.replace("\n", "\u2028"),
		"no blank line before moves": LICHESS.replace("\n\n1.", "\n1."),
		"tags without moves on a new line": LICHESS.replace("]\n\n1.", "] 1."),
	}
	for name in variants:
		var parsed := Pgn.parse(str(variants[name]))
		expect_true("lichess game with " + name, bool(parsed["ok"]) and (parsed["moves"] as Array).size() == 7, str(parsed["error"]))
		if bool(parsed["ok"]):
			expect("tags read with " + name, str(parsed["headers"].get("Black", "")), "bob")

	var plain_forms := {
		"colon tags": "Event: Casual game\nSite: Home\nWhite: Ann\nBlack: Bob\nResult: 1-0\n\n1. e4 e5 2. Nf3 Nc6 1-0\n",
		"quoted tags without brackets": "Event \"Casual game\"\nWhite \"Ann\"\nBlack \"Bob\"\n\n1. e4 e5 2. Nf3 Nc6\n",
		"missing opening bracket": "Event \"Casual game\"]\nSite \"Home\"]\n\n1. e4 e5\n",
		"markdown code fence": "```pgn\n" + LICHESS + "```\n",
		"fence without language": "```\n[Event \"x\"]\n\n1. e4 e5 2. Nf3 Nc6 *\n```",
	}
	for name in plain_forms:
		var parsed := Pgn.parse(str(plain_forms[name]))
		expect_true("game with " + name, bool(parsed["ok"]) and (parsed["moves"] as Array).size() >= 2, str(parsed["error"]))
	expect("colon tag value", str(Pgn.parse(plain_forms["colon tags"])["headers"].get("White", "")), "Ann")

	var junk_tag := Pgn.parse("[Event \"Ok\"]\n[Broken tag line\n[Site \"Here\"]\n\n1. e4 e5 *\n")
	expect_true("a broken tag line is skipped", bool(junk_tag["ok"]), str(junk_tag["error"]))
	expect("tags after a broken line are kept", str(junk_tag["headers"].get("Site", "")), "Here")
	var empty_value := Pgn.parse("[Event \"\"]\n[Round \"\"]\n\n1. d4 *\n")
	expect("empty tag values", bool(empty_value["ok"]), true)
	var dashes := Pgn.parse("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Bxc6 dxc6 5. O\u2013O Nf6 *")
	expect_true("en dash castling", bool(dashes["ok"]) and (dashes["moves"] as Array).size() == 10, str(dashes["error"]))
	var exported := Pgn.export_game({"White": "Me", "Black": "You"}, ["e4", "e5"], "*")
	expect("export then CRLF paste", bool(Pgn.parse(exported.replace("\n", "\r\n"))["ok"]), true)
	expect("export then one-line paste", (Pgn.parse(exported.replace("\n", " "))["moves"] as Array).size(), 2)


func _export() -> void:
	expect("result in progress", Pgn.result_for("", true), "*")
	expect("white mates", Pgn.result_for("checkmate", false), "1-0")
	expect("black mates", Pgn.result_for("checkmate", true), "0-1")
	expect("stalemate is a draw", Pgn.result_for("stalemate", true), "1/2-1/2")
	expect("repetition is a draw", Pgn.result_for("repetition", false), "1/2-1/2")

	var text := Pgn.export_game({"White": "Me", "Black": "Stockfish 19", "Date": "2026.10.04"}, ["e4", "e5", "Nf3"], "*")
	var lines := text.split("\n")
	expect("event first", lines[0], "[Event \"Casual game\"]")
	expect("site", lines[1], "[Site \"NeoChess\"]")
	expect("date", lines[2], "[Date \"2026.10.04\"]")
	expect("round", lines[3], "[Round \"-\"]")
	expect("white", lines[4], "[White \"Me\"]")
	expect("black", lines[5], "[Black \"Stockfish 19\"]")
	expect("result tag", lines[6], "[Result \"*\"]")
	expect("blank line after tags", lines[7], "")
	expect("movetext", lines[8], "1. e4 e5 2. Nf3 *")
	expect("ends with newline", text.ends_with("*\n"), true)
	expect("no FEN for the start position", text.contains("[FEN"), false)

	var extra := Pgn.export_game({"WhiteType": "human", "TimeControl": "300+0"}, [], "*")
	expect("extra tags kept", extra.contains("[TimeControl \"300+0\"]"), true)
	expect("defaults for missing names", extra.contains("[White \"?\"]"), true)
	var quoted := Pgn.export_game({"White": "Say \"hi\" \\ there\nnow"}, [], "*")
	expect("quotes and backslashes escaped", quoted.contains("[White \"Say \\\"hi\\\" \\\\ there now\"]"), true)

	var fen := "4k3/8/8/8/8/8/4P3/4K3 b - - 0 7"
	var custom := Pgn.export_game({}, ["Kd7", "Ke3"], "*", fen)
	expect("setup tag", custom.contains("[SetUp \"1\"]"), true)
	expect("fen tag", custom.contains("[FEN \"" + fen + "\"]"), true)
	expect("black first uses ellipsis", custom.contains("7... Kd7 8. Ke3 *"), true)

	var sans: Array = []
	for i in 60:
		sans.append("Nf3" if i % 2 == 0 else "Nf6")
	var wrapped := Pgn.export_game({}, sans, "1/2-1/2")
	var longest := 0
	for line in wrapped.split("\n"):
		longest = maxi(longest, line.length())
	expect_true("lines wrap at 80 columns", longest <= 80, "(longest %d)" % longest)
	expect("result ends the movetext", wrapped.strip_edges().ends_with("1/2-1/2"), true)


func _roundtrip() -> void:
	var game := Rules.new()
	var sans: Array = []
	var ucis := ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", "f8e7"]
	for uci in ucis:
		var move: Dictionary = game.match_uci(uci)
		sans.append(game.to_san(move))
		game.make_move(move)
	var text := Pgn.export_game({"White": "A", "Black": "B"}, sans, "*")
	var parsed := Pgn.parse(text)
	expect("roundtrip parses", bool(parsed["ok"]), true)
	expect("roundtrip move count", (parsed["moves"] as Array).size(), ucis.size())
	expect("roundtrip sans", ",".join(parsed["sans"]), ",".join(sans))
	expect("roundtrip white tag", str(parsed["headers"]["White"]), "A")
	expect("roundtrip result", str(parsed["result"]), "*")
	expect("roundtrip start", str(parsed["start_fen"]), Pgn.START_FEN)
	var replay := Rules.new()
	for move in parsed["moves"]:
		replay.make_move(move)
	expect("roundtrip position", replay.to_fen(), game.to_fen())

	var fen := "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 20"
	var from_fen = Rules.setup(fen)
	var castle: Dictionary = from_fen.match_uci("e1c1")
	var castle_san: String = from_fen.to_san(castle)
	var again := Pgn.parse(Pgn.export_game({}, [castle_san], "*", fen))
	expect("fen game parses", bool(again["ok"]), true)
	expect("fen game start", str(again["start_fen"]), fen)
	expect("fen game castles", castle_san, "O-O-O")
	expect("fen game move count", (again["moves"] as Array).size(), 1)

	var promo = Rules.setup("8/4P3/8/8/8/8/k7/4K3 w - - 0 1")
	var promo_text := Pgn.export_game({}, [promo.to_san(promo.match_uci("e7e8q"))], "*", "8/4P3/8/8/8/8/k7/4K3 w - - 0 1")
	var promo_back := Pgn.parse(promo_text)
	expect("promotion roundtrip", bool(promo_back["ok"]), true)
	expect("promotion san", str(promo_back["sans"][0]), "e8=Q")


func _import_variants() -> void:
	var full := Pgn.parse(FULL_GAME)
	expect("full game parses", bool(full["ok"]), true)
	expect("full game plies", (full["moves"] as Array).size(), 47)
	expect("full game result", str(full["result"]), "1-0")
	expect("full game white", str(full["headers"]["White"]), "Adolf Anderssen")
	expect("escaped quote tag", str(full["headers"]["Annotator"]), "Someone \"Quoted\"")
	expect("last move is mate", str(full["sans"][46]), "Bxe7#")
	expect("game count", int(full["game_count"]), 1)
	var ended := Rules.new()
	for move in full["moves"]:
		ended.make_move(move)
	expect("final position is mate", ended.outcome(), "checkmate")

	var messy := Pgn.parse(MESSY)
	expect_true("messy game parses", bool(messy["ok"]), str(messy["error"]))
	expect("messy plies", (messy["moves"] as Array).size(), 20)
	expect("variation skipped", str(messy["sans"][2]), "Nf3")
	expect("move after variation", str(messy["sans"][3]), "Nc6")
	expect("zero castling", str(messy["sans"][8]), "O-O")
	expect("draw result", str(messy["result"]), "1/2-1/2")

	var bare := Pgn.parse("1. e4 e5 2. Nf3 *")
	expect("no tags needed", bool(bare["ok"]), true)
	expect("bare moves", (bare["moves"] as Array).size(), 3)
	expect("bare result", str(bare["result"]), "*")
	var crlf := Pgn.parse("[Event \"x\"]\r\n\r\n1. d4 d5 2. c4 *\r\n")
	expect("windows line endings", (crlf["moves"] as Array).size(), 3)
	var bom := Pgn.parse("\ufeff[Event \"x\"]\n\n1. d4 *\n")
	expect("byte order mark", bool(bom["ok"]), true)
	var glued := Pgn.parse("1.e4 1...e5 2.Nf3 2...Nc6 3.Bb5 *")
	expect("glued move numbers", (glued["moves"] as Array).size(), 5)
	var tags_only := Pgn.parse("[Event \"Empty\"]\n[Result \"*\"]\n")
	expect("tags only is an empty game", bool(tags_only["ok"]), true)
	expect("tags only has no moves", (tags_only["moves"] as Array).size(), 0)
	var long_algebraic := Pgn.parse("1. e2-e4 e7-e5 *")
	expect("long algebraic", (long_algebraic["moves"] as Array).size(), 2)
	var trailing := Pgn.parse("1. e4 e5 {unfinished comment")
	expect("unterminated comment", (trailing["moves"] as Array).size(), 2)

	var two := Pgn.parse("[Event \"One\"]\n\n1. e4 *\n\n[Event \"Two\"]\n\n1. d4 d5 2. c4 *\n")
	expect("multi game count", int(two["game_count"]), 2)
	expect("first game is used", (two["moves"] as Array).size(), 1)
	expect("first game tags", str(two["headers"]["Event"]), "One")

	var from_pos := Pgn.parse("[SetUp \"1\"]\n[FEN \"4k3/8/8/8/8/8/4P3/4K3 w - - 0 1\"]\n\n1. e4 Kd7 *\n")
	expect("fen start parses", bool(from_pos["ok"]), true)
	expect("fen start kept", str(from_pos["start_fen"]), "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1")
	var variant_ok := Pgn.parse("[Variant \"Standard\"]\n\n1. e4 *\n")
	expect("standard variant accepted", bool(variant_ok["ok"]), true)
	var disabled_setup := Pgn.parse("[SetUp \"0\"]\n[FEN \"4k3/8/8/8/8/8/4P3/4K3 w - - 0 1\"]\n\n1. e4 *\n")
	expect("SetUp 0 means standard start", str(disabled_setup["start_fen"]), Pgn.START_FEN)


func _errors() -> void:
	var illegal := Pgn.parse("1. e4 e5 2. Nf6 *")
	expect("illegal move fails", bool(illegal["ok"]), false)
	expect_true("illegal move is located", str(illegal["error"]).contains("2. Nf6"), str(illegal["error"]))
	var black := Pgn.parse("1. e4 e4 *")
	expect("black move label", str(black["error"]).contains("1... e4"), true)
	expect("nothing returned on error", (illegal["moves"] as Array).size(), 0)
	expect("empty text", bool(Pgn.parse("")["ok"]), false)
	expect("whitespace text", bool(Pgn.parse("  \n\t ")["ok"]), false)
	expect_true("prose is rejected", not bool(Pgn.parse("hello there, this is not chess")["ok"]))
	var variant := Pgn.parse("[Variant \"Chess960\"]\n\n1. e4 *\n")
	expect("chess960 refused", bool(variant["ok"]), false)
	expect_true("variant named", str(variant["error"]).contains("Chess960"))
	var bad_fen := Pgn.parse("[SetUp \"1\"]\n[FEN \"not a position\"]\n\n1. e4 *\n")
	expect("bad fen refused", bool(bad_fen["ok"]), false)
	expect_true("bad fen explained", str(bad_fen["error"]).contains("starting position"))
	var null_move := Pgn.parse("1. e4 -- 2. d4 *")
	expect("null move refused", bool(null_move["ok"]), false)
	var huge := Pgn.parse("x".repeat(Pgn.MAX_BYTES + 1))
	expect("oversized input refused", bool(huge["ok"]), false)


func _find_move() -> void:
	var game := Rules.new()
	expect("pawn push", Pgn.find_move(game, "e4")["error"], "")
	expect("knight", Pgn.find_move(game, "Nf3")["error"], "")
	expect("annotation marks ignored", Pgn.find_move(game, "Nf3!?")["error"], "")
	expect("check marks ignored", Pgn.find_move(game, "e4+")["error"], "")
	expect_true("impossible pawn move", str(Pgn.find_move(game, "e5")["error"]) != "")
	expect_true("not a move", str(Pgn.find_move(game, "banana")["error"]) != "")
	expect_true("castling blocked at start", str(Pgn.find_move(game, "O-O")["error"]) != "")

	var rooks = Rules.setup("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
	expect_true("ambiguous rook", str(Pgn.find_move(rooks, "Rd1")["error"]).contains("more than one"))
	expect("file disambiguation", Pgn.find_move(rooks, "Rad1")["error"], "")
	expect("file disambiguation picks the right rook", int(Pgn.find_move(rooks, "Rad1")["move"]["from"]), 0)
	expect("other rook", int(Pgn.find_move(rooks, "Rhd1")["move"]["from"]), 7)
	var stacked = Rules.setup("R3k3/8/8/8/8/8/8/R3K3 w - - 0 1")
	expect("rank disambiguation", int(Pgn.find_move(stacked, "R1a4")["move"]["from"]), 0)
	var queens = Rules.setup("4k3/8/8/8/Q6Q/8/8/Q3K3 w - - 0 1")
	expect("square disambiguation", int(Pgn.find_move(queens, "Qa4b3")["move"]["from"]), 24)

	var capture = Rules.setup("4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1")
	expect("pawn capture", Pgn.find_move(capture, "exd5")["error"], "")
	expect("capture mark optional", Pgn.find_move(capture, "ed5")["error"], "")
	var ep = Rules.setup("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3")
	expect("en passant", bool(Pgn.find_move(ep, "exd6")["move"]["ep"]), true)
	var promo = Rules.setup("8/4P3/8/8/8/8/k7/4K3 w - - 0 1")
	expect("promotion with equals", int(Pgn.find_move(promo, "e8=N")["move"]["promo"]), Rules.KNIGHT)
	expect("promotion without equals", int(Pgn.find_move(promo, "e8Q")["move"]["promo"]), Rules.QUEEN)
	expect_true("promotion needs a piece", str(Pgn.find_move(promo, "e8")["error"]) != "")
	var castle = Rules.setup("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	expect("short castle", int(Pgn.find_move(castle, "O-O")["move"]["to"]), 6)
	expect("long castle", int(Pgn.find_move(castle, "O-O-O")["move"]["to"]), 2)
	expect("zero castle", int(Pgn.find_move(castle, "0-0")["move"]["to"]), 6)
	expect("zero long castle", int(Pgn.find_move(castle, "0-0-0")["move"]["to"]), 2)
	expect("lowercase promotion letter", int(Pgn.find_move(promo, "e8=q")["move"]["promo"]), Rules.QUEEN)


func _fen_validation() -> void:
	expect("start is valid", Rules.fen_error(Pgn.START_FEN), "")
	expect("placement only is valid", Rules.fen_error("4k3/8/8/8/8/8/8/4K3"), "")
	expect("kiwipete is valid", Rules.fen_error("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"), "")
	expect_true("empty", Rules.fen_error("") != "")
	expect_true("too few ranks", Rules.fen_error("8/8/8 w - - 0 1") != "")
	expect_true("short rank", Rules.fen_error("4k3/8/8/8/8/8/8/3K4 w - - 0 1") == "")
	expect_true("rank too long", Rules.fen_error("4k4/8/8/8/8/8/8/4K3 w - - 0 1") != "")
	expect_true("unknown piece", Rules.fen_error("4k3/8/8/8/8/8/8/4X3 w - - 0 1") != "")
	expect_true("no white king", Rules.fen_error("4k3/8/8/8/8/8/8/8 w - - 0 1") != "")
	expect_true("two black kings", Rules.fen_error("4kk2/8/8/8/8/8/8/4K3 w - - 0 1") != "")
	expect_true("pawn on back rank", Rules.fen_error("4k2P/8/8/8/8/8/8/4K3 w - - 0 1") != "")
	expect_true("bad side", Rules.fen_error("4k3/8/8/8/8/8/8/4K3 x - - 0 1") != "")
	expect_true("bad en passant", Rules.fen_error("4k3/8/8/8/8/8/8/4K3 w - e5 0 1") != "")
	expect_true("side that just moved in check", Rules.fen_error("4k3/4R3/8/8/8/8/8/4K3 w - - 0 1") != "")
	expect("side to move may be in check", Rules.fen_error("4k3/8/8/8/8/8/8/4RK2 b - - 0 1"), "")
