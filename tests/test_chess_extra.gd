extends "res://tests/test_base.gd"

const Rules = preload("res://scripts/chess_game.gd")


func run() -> void:
	_fen_and_squares()
	_promotion()
	_end_states()
	_castling_rules()
	_san()
	_clone_and_undo_support()
	_move_matching()


func _fen_and_squares() -> void:
	var fens := [
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
		"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 3 7",
		"8/8/8/3k4/8/8/4K3/8 b - - 12 40",
		"rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3",
	]
	for fen in fens:
		expect("fen roundtrip " + str(fen), Rules.setup(fen).to_fen(), fen)
	var game := Rules.new()
	expect("a1 is 0", game.name_sq("a1"), 0)
	expect("h1 is 7", game.name_sq("h1"), 7)
	expect("a8 is 56", game.name_sq("a8"), 56)
	expect("h8 is 63", game.name_sq("h8"), 63)
	expect("bad square", game.name_sq("z9"), -1)
	expect("short square", game.name_sq("e"), -1)
	for sq in 64:
		expect("square name roundtrip %d" % sq, game.name_sq(game.sq_name(sq)), sq)
	expect("white king start", game.king_square(true), 4)
	expect("black king start", game.king_square(false), 60)
	var half = Rules.setup("8/8/8/3k4/8/8/4K3/8 b - - 12 40")
	expect("halfmove parsed", half.halfmove, 12)
	expect("fullmove parsed", half.fullmove, 40)
	expect("side parsed", half.white_to_move, false)


func _promotion() -> void:
	var game = Rules.setup("8/4P3/8/8/8/8/k7/4K3 w - - 0 1")
	var promos := 0
	var seen := {}
	for move in game.legal_moves():
		if int(move.from) == game.name_sq("e7"):
			promos += 1
			seen[int(move.promo)] = true
	expect("four promotion choices", promos, 4)
	expect("promotes to queen", seen.has(Rules.QUEEN), true)
	expect("promotes to knight", seen.has(Rules.KNIGHT), true)
	var queen: Dictionary = game.match_uci("e7e8q")
	expect("queen promotion found", queen.is_empty(), false)
	expect("promotion needs piece letter", game.match_uci("e7e8").is_empty(), true)
	expect("promotion san", game.to_san(queen), "e8=Q")
	game.make_move(queen)
	expect("queen on e8", int(game.board[60]), Rules.QUEEN)
	var under: Dictionary = Rules.setup("8/4P3/8/8/8/8/k7/4K3 w - - 0 1").match_uci("e7e8n")
	expect("underpromotion uci", Rules.new().to_uci(under), "e7e8n")
	var capture = Rules.setup("k2r4/4P3/8/8/8/8/8/4K3 w - - 0 1")
	expect("promotion capture san", capture.to_san(capture.match_uci("e7d8q")), "exd8=Q+")


func _end_states() -> void:
	var stalemate = Rules.setup("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	expect("stalemate", stalemate.outcome(), "stalemate")
	expect("stalemate text", stalemate.result_text_for("stalemate"), "Stalemate.")
	var mate = Rules.setup("6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
	mate.make_move(mate.match_uci("a1a8"))
	expect("back rank mate", mate.outcome(), "checkmate")
	expect("mate text", mate.result_text_for("checkmate"), "Checkmate. White wins.")
	expect("kings only", Rules.setup("8/8/8/3k4/8/8/4K3/8 w - - 0 1").outcome(), "material")
	expect("king and knight", Rules.setup("8/8/8/3k4/8/8/4K1N1/8 w - - 0 1").outcome(), "material")
	expect("king and rook is playable", Rules.setup("8/8/8/3k4/8/8/4K1R1/8 w - - 0 1").outcome(), "")
	expect("pawn keeps material", Rules.setup("8/8/8/3k4/8/8/4K1P1/8 w - - 0 1").outcome(), "")
	expect("fifty move rule", Rules.setup("8/8/8/3k4/8/8/4K1R1/8 w - - 100 80").outcome(), "fifty")
	expect("forty nine is fine", Rules.setup("8/8/8/3k4/8/8/4K1R1/8 w - - 99 80").outcome(), "")
	var rep = Rules.setup("8/8/8/3k4/8/8/4K1R1/8 w - - 0 1")
	var shuffle := ["g2g3", "d5d4", "g3g2", "d4d5"]
	for _round in 2:
		for uci in shuffle:
			rep.make_move(rep.match_uci(uci))
	expect("threefold repetition", rep.outcome(), "repetition")
	var fresh = Rules.setup("8/8/8/3k4/8/8/4K1R1/8 w - - 0 1")
	for uci in shuffle:
		fresh.make_move(fresh.match_uci(uci))
	expect("two fold is not a draw", fresh.outcome(), "")
	var check = Rules.setup("4k3/8/8/8/8/8/4r3/4K3 w - - 0 1")
	expect("in check", check.in_check_stm(), true)
	expect("check text", check.result_text_for(""), "White to move. Check.")
	expect("quiet text", Rules.new().result_text_for(""), "White to move.")


func _castling_rules() -> void:
	var both = Rules.setup("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	expect("castle both sides", both.match_uci("e1g1").is_empty() or both.match_uci("e1c1").is_empty(), false)
	expect("queen side san", both.to_san(both.match_uci("e1c1")), "O-O-O")
	var rook_moved = Rules.setup("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	rook_moved.make_move(rook_moved.match_uci("h1h2"))
	expect("king side right lost", rook_moved.castle_wk, false)
	expect("queen side right kept", rook_moved.castle_wq, true)
	var king_moved = Rules.setup("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	king_moved.make_move(king_moved.match_uci("e1e2"))
	expect("king move drops both rights", king_moved.castle_wk or king_moved.castle_wq, false)
	var captured_rook = Rules.setup("r3k2r/8/8/8/8/8/6b1/R3K2R b KQkq - 0 1")
	captured_rook.make_move(captured_rook.match_uci("g2h1"))
	expect("captured rook removes right", captured_rook.castle_wk, false)
	var through_check = Rules.setup("r3k2r/8/8/8/8/5r2/8/R3K2R w KQkq - 0 1")
	expect("cannot castle through attacked square", through_check.match_uci("e1g1").is_empty(), true)
	var in_check = Rules.setup("r3k2r/8/8/8/8/8/4r3/R3K2R w KQkq - 0 1")
	expect("cannot castle out of check", in_check.match_uci("e1g1").is_empty(), true)
	var blocked = Rules.setup("r3k2r/8/8/8/8/8/8/R3KN1R w KQkq - 0 1")
	expect("cannot castle through a piece", blocked.match_uci("e1g1").is_empty(), true)


func _san() -> void:
	var game = Rules.setup("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
	expect("rook disambiguates by file", game.to_san(game.match_uci("a1d1")), "Rad1")
	var ranks = Rules.setup("R7/4k3/8/8/8/8/8/R3K3 w - - 0 1")
	expect("rook disambiguates by rank", ranks.to_san(ranks.match_uci("a1a4")), "R1a4")
	var knights = Rules.setup("4k3/8/8/8/8/2N3N1/8/4K3 w - - 0 1")
	expect("knight disambiguation", knights.to_san(knights.match_uci("c3e4")), "Nce4")
	var capture = Rules.setup("4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1")
	expect("pawn capture san", capture.to_san(capture.match_uci("e4d5")), "exd5")
	var check = Rules.setup("6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
	expect("mate suffix", check.to_san(check.match_uci("a1a8")), "Ra8#")
	var plus = Rules.setup("4k3/8/8/8/8/8/8/R3K3 w - - 0 1")
	expect("check without mate", plus.to_san(plus.match_uci("a1a7")), "Ra7")
	var gives_check = Rules.setup("3k4/8/8/8/8/8/8/R3K3 w - - 0 1")
	expect("rook gives check", gives_check.to_san(gives_check.match_uci("a1a8")), "Ra8+")


func _clone_and_undo_support() -> void:
	var game := Rules.new()
	var copy = game.clone()
	copy.make_move(copy.match_uci("e2e4"))
	expect("clone is independent", game.to_fen(), "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	expect("clone moved", copy.white_to_move, false)
	game.make_move(game.match_uci("e2e4"))
	game.make_move(game.match_uci("e7e5"))
	game.reset()
	expect("reset restores start", game.to_fen(), "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	expect("reset clears repetition", game.rep.size(), 1)


func _move_matching() -> void:
	var game := Rules.new()
	expect("garbage uci", game.match_uci("hello").is_empty(), true)
	expect("empty uci", game.match_uci("").is_empty(), true)
	expect("illegal move", game.match_uci("e2e5").is_empty(), true)
	expect("uppercase accepted", game.match_uci("E2E4").is_empty(), false)
	expect("padding trimmed", game.match_uci("  e2e4 \n").is_empty(), false)
	expect("to_uci", game.to_uci(game.match_uci("g1f3")), "g1f3")
	var ep = Rules.setup("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3")
	var capture: Dictionary = ep.match_uci("e5d6")
	expect("en passant from fen", bool(capture.get("ep", false)), true)
	expect("ep san", ep.to_san(capture), "exd6")
	var expired = Rules.setup("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq - 0 3")
	expect("no ep without the square", expired.match_uci("e5d6").is_empty(), true)
