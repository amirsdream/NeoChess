extends "res://tests/test_base.gd"

const Rules = preload("res://scripts/chess_game.gd")


func run() -> void:
	_rules()

func _rules() -> void:
	var start := Rules.new()
	expect("start fen", start.to_fen(), "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
	expect("start moves", start.legal_moves().size(), 20)
	_expect_perft("start d1", "", 1, 20)
	_expect_perft("start d2", "", 2, 400)
	_expect_perft("start d3", "", 3, 8902)
	_expect_perft("kiwipete d1", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -", 1, 48)
	_expect_perft("kiwipete d2", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -", 2, 2039)
	_expect_perft("pos3 d1", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -", 1, 14)
	_expect_perft("pos3 d2", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -", 2, 191)
	_expect_perft("pos4 d1", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", 1, 6)
	_expect_perft("pos4 d2", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", 2, 264)
	_expect_perft("pos5 d1", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", 1, 44)

	var opening := Rules.new()
	expect("e4 san", opening.to_san(opening.match_uci("e2e4")), "e4")
	_play(opening, "e2e4")
	expect("fen after e4", opening.to_fen(), "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
	_play(opening, "e7e5")
	expect("fen after e5", opening.to_fen(), "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2")

	var mate := Rules.new()
	expect("f3", _play(mate, "f2f3"), true)
	expect("e5", _play(mate, "e7e5"), true)
	expect("g4", _play(mate, "g2g4"), true)
	var queen := mate.match_uci("d8h4")
	expect("qh4 san", mate.to_san(queen), "Qh4#")
	mate.make_move(queen)
	expect("fools mate", mate.outcome(), "checkmate")

	var ep := Rules.new()
	for uci in ["e2e4", "e7e6", "e4e5", "d7d5"]:
		expect(uci, _play(ep, uci), true)
	var hit := ep.match_uci("e5d6")
	expect("ep available", hit.is_empty(), false)
	expect("ep flag", bool(hit.ep), true)
	ep.make_move(hit)
	expect("ep pawn landed", int(ep.board[43]), Rules.PAWN)
	expect("ep pawn removed", int(ep.board[35]), 0)

	var castle = Rules.setup("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	expect("castle san", castle.to_san(castle.match_uci("e1g1")), "O-O")
	_play(castle, "e1g1")
	expect("king castled", int(castle.board[6]), Rules.KING)
	expect("rook castled", int(castle.board[5]), Rules.ROOK)
	expect("rook left h1", int(castle.board[7]), 0)
	expect("castle rights gone", castle.castle_wk or castle.castle_wq, false)

	var pin = Rules.setup("4k3/8/8/b7/8/2N5/8/4K3 w - - 0 1")
	var knight_moves := 0
	for move in pin.legal_moves():
		if int(move.from) == pin.name_sq("c3"):
			knight_moves += 1
	expect("pinned knight", knight_moves, 0)


func _expect_perft(name: String, fen: String, depth: int, expected: int) -> void:
	var game = Rules.new() if fen.is_empty() else Rules.setup(fen)
	var started := Time.get_ticks_msec()
	var count: int = game.perft(depth)
	var elapsed := Time.get_ticks_msec() - started
	checks += 1
	if count != expected:
		failures += 1
		print("FAIL %s: got %d expected %d (%d ms)" % [name, count, expected, elapsed])
		if depth <= 2:
			game.debug_divide(depth)
	elif verbose:
		print("ok   %s = %d (%d ms)" % [name, count, elapsed])


func _play(game, uci: String) -> bool:
	var move = game.match_uci(uci)
	if move.is_empty():
		return false
	game.make_move(move)
	return true
