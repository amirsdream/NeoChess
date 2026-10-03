class_name ChessGame
extends RefCounted

const NONE := 0
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6

const FEN_OF := {
	"P": 1, "N": 2, "B": 3, "R": 4, "Q": 5, "K": 6,
	"p": -1, "n": -2, "b": -3, "r": -4, "q": -5, "k": -6,
}
const FEN_CHAR := {
	1: "P", 2: "N", 3: "B", 4: "R", 5: "Q", 6: "K",
	-1: "p", -2: "n", -3: "b", -4: "r", -5: "q", -6: "k",
}
const LETTER := {2: "N", 3: "B", 4: "R", 5: "Q", 6: "K"}
const PROMO_CHAR := {5: "q", 4: "r", 3: "b", 2: "n"}
const PROMO_FROM := {"q": 5, "r": 4, "b": 3, "n": 2}

const KNIGHT_DIRS := [
	Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
	Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2),
]
const BISHOP_DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const ROOK_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const KING_DIRS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var board := PackedInt32Array()
var white_to_move := true
var castle_wk := true
var castle_wq := true
var castle_bk := true
var castle_bq := true
var ep_square := -1
var halfmove := 0
var fullmove := 1
var rep := {}


func _init() -> void:
	reset()


static func setup(fen: String):
	var game = load("res://scripts/chess_game.gd").new()
	game.load_fen(fen)
	return game


func reset() -> void:
	board = PackedInt32Array()
	board.resize(64)
	var back: Array[int] = [ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK]
	for file in 8:
		board[file] = back[file]
		board[8 + file] = PAWN
		board[48 + file] = -PAWN
		board[56 + file] = -back[file]
	white_to_move = true
	castle_wk = true
	castle_wq = true
	castle_bk = true
	castle_bq = true
	ep_square = -1
	halfmove = 0
	fullmove = 1
	rep = {}
	_note_rep()


func load_fen(fen: String) -> void:
	var parts := fen.split(" ")
	var ranks := parts[0].split("/")
	board = PackedInt32Array()
	board.resize(64)
	for row_index in mini(ranks.size(), 8):
		var rank := 7 - row_index
		var file := 0
		var row: String = ranks[row_index]
		for ch in row:
			if ch >= "1" and ch <= "8":
				file += int(ch)
			elif FEN_OF.has(ch) and file < 8:
				board[rank * 8 + file] = int(FEN_OF[ch])
				file += 1
	white_to_move = parts.size() < 2 or parts[1] == "w"
	var castle := parts[2] if parts.size() > 2 else "-"
	castle_wk = "K" in castle
	castle_wq = "Q" in castle
	castle_bk = "k" in castle
	castle_bq = "q" in castle
	var ep := parts[3] if parts.size() > 3 else "-"
	ep_square = -1 if ep == "-" else name_sq(ep)
	halfmove = int(parts[4]) if parts.size() > 4 else 0
	fullmove = int(parts[5]) if parts.size() > 5 else 1
	rep = {}
	_note_rep()


func clone():
	var copy = get_script().new()
	copy.board = board.duplicate()
	copy.white_to_move = white_to_move
	copy.castle_wk = castle_wk
	copy.castle_wq = castle_wq
	copy.castle_bk = castle_bk
	copy.castle_bq = castle_bq
	copy.ep_square = ep_square
	copy.halfmove = halfmove
	copy.fullmove = fullmove
	copy.rep = rep.duplicate()
	return copy


func to_fen() -> String:
	var rows := PackedStringArray()
	for rank in range(7, -1, -1):
		var empty := 0
		var row := ""
		for file in 8:
			var piece := int(board[rank * 8 + file])
			if piece == 0:
				empty += 1
			else:
				if empty > 0:
					row += str(empty)
					empty = 0
				row += str(FEN_CHAR[piece])
		if empty > 0:
			row += str(empty)
		rows.append(row)
	var castle := ""
	if castle_wk:
		castle += "K"
	if castle_wq:
		castle += "Q"
	if castle_bk:
		castle += "k"
	if castle_bq:
		castle += "q"
	if castle.is_empty():
		castle = "-"
	var ep := "-" if ep_square < 0 else sq_name(ep_square)
	var side := "w" if white_to_move else "b"
	return "%s %s %s %s %d %d" % ["/".join(rows), side, castle, ep, halfmove, fullmove]


func sq_name(sq: int) -> String:
	return "abcdefgh"[sq % 8] + str((sq / 8) + 1)


func name_sq(text: String) -> int:
	if text.length() != 2:
		return -1
	var file := "abcdefgh".find(text.substr(0, 1))
	var rank := text.substr(1, 1).to_int() - 1
	if file < 0 or rank < 0 or rank > 7:
		return -1
	return rank * 8 + file


func king_square(white: bool) -> int:
	return board.find(KING if white else -KING)


func in_check_stm() -> bool:
	return _king_in_check(white_to_move)


func legal_moves() -> Array:
	var found: Array = []
	for move in pseudo_moves():
		var next = clone()
		next.make_move(move)
		if not next._king_in_check(not next.white_to_move):
			found.append(move)
	return found


func state_of(legal_list: Array) -> String:
	if legal_list.is_empty():
		return "checkmate" if in_check_stm() else "stalemate"
	if halfmove >= 100:
		return "fifty"
	if int(rep.get(_key(), 0)) >= 3:
		return "repetition"
	if _insufficient():
		return "material"
	return ""


func outcome() -> String:
	return state_of(legal_moves())


func result_text_for(state: String) -> String:
	var who := "White" if white_to_move else "Black"
	match state:
		"checkmate":
			return "Checkmate. %s wins." % ("Black" if white_to_move else "White")
		"stalemate":
			return "Stalemate."
		"fifty":
			return "Draw by the fifty-move rule."
		"repetition":
			return "Draw by repetition."
		"material":
			return "Draw by insufficient material."
		_:
			if in_check_stm():
				return "%s to move. Check." % who
			return "%s to move." % who


func match_uci(uci: String) -> Dictionary:
	var text := uci.strip_edges().to_lower()
	if text.length() < 4:
		return {}
	var origin := name_sq(text.substr(0, 2))
	var target := name_sq(text.substr(2, 2))
	if origin < 0 or target < 0:
		return {}
	var promo := 0
	if text.length() >= 5:
		promo = int(PROMO_FROM.get(text.substr(4, 1), 0))
	for move in legal_moves():
		if int(move.from) == origin and int(move.to) == target and int(move.promo) == promo:
			return move
	return {}


func to_uci(move: Dictionary) -> String:
	var text := sq_name(int(move.from)) + sq_name(int(move.to))
	var promo := int(move.get("promo", 0))
	if promo != 0:
		text += str(PROMO_CHAR[promo])
	return text


func to_san(move: Dictionary) -> String:
	var origin := int(move.from)
	var target := int(move.to)
	var kind := absi(int(board[origin]))
	var san := ""
	if bool(move.get("castle", false)):
		san = "O-O" if target % 8 == 6 else "O-O-O"
	elif kind == PAWN:
		if int(board[target]) != 0 or bool(move.get("ep", false)):
			san = _file_char(origin) + "x" + sq_name(target)
		else:
			san = sq_name(target)
		if int(move.get("promo", 0)) != 0:
			san += "=" + str(LETTER[int(move.promo)])
	else:
		san = str(LETTER[kind]) + _disambiguation(move)
		if int(board[target]) != 0:
			san += "x"
		san += sq_name(target)
	var next = clone()
	next.make_move(move)
	if next.legal_moves().is_empty() and next.in_check_stm():
		san += "#"
	elif next.in_check_stm():
		san += "+"
	return san


func make_move(move: Dictionary) -> void:
	var origin := int(move.from)
	var target := int(move.to)
	var promo := int(move.get("promo", 0))
	var castle := bool(move.get("castle", false))
	var ep := bool(move.get("ep", false))
	var piece := int(board[origin])
	var captured := int(board[target])
	var sign := 1 if piece > 0 else -1

	_clear_castle(origin)
	_clear_castle(target)
	board[origin] = 0
	board[target] = sign * promo if promo != 0 else piece
	if ep:
		var captured_sq := target - 8 if sign > 0 else target + 8
		board[captured_sq] = 0
	if castle:
		_move_castling_rook(target)
	if absi(piece) == PAWN and absi(target - origin) == 16:
		ep_square = (origin + target) / 2
	else:
		ep_square = -1
	if absi(piece) == PAWN or captured != 0 or ep:
		halfmove = 0
	else:
		halfmove += 1
	if not white_to_move:
		fullmove += 1
	white_to_move = not white_to_move
	_note_rep()


func perft(depth: int) -> int:
	if depth <= 0:
		return 1
	var total := 0
	for move in legal_moves():
		var next = clone()
		next.make_move(move)
		total += next.perft(depth - 1)
	return total


func debug_divide(depth: int) -> void:
	var total := 0
	var rows: Array = []
	for move in legal_moves():
		var next = clone()
		next.make_move(move)
		var count: int = 1 if depth <= 1 else next.perft(depth - 1)
		rows.append("%s %d" % [to_uci(move), count])
		total += count
	rows.sort()
	for row in rows:
		print(row)
	print("total %d" % total)


func pseudo_moves() -> Array:
	var moves: Array = []
	var side := 1 if white_to_move else -1
	for sq in 64:
		var piece := int(board[sq])
		if piece * side <= 0:
			continue
		match absi(piece):
			PAWN:
				_pawn_moves(sq, side, moves)
			KNIGHT:
				_leaps(sq, side, KNIGHT_DIRS, moves)
			BISHOP:
				_slides(sq, side, BISHOP_DIRS, moves)
			ROOK:
				_slides(sq, side, ROOK_DIRS, moves)
			QUEEN:
				_slides(sq, side, BISHOP_DIRS, moves)
				_slides(sq, side, ROOK_DIRS, moves)
			KING:
				_leaps(sq, side, KING_DIRS, moves)
	_castling(moves)
	return moves


func _pawn_moves(sq: int, side: int, moves: Array) -> void:
	var file := sq % 8
	var rank := sq / 8
	var next_rank := rank + side
	if next_rank < 0 or next_rank > 7:
		return
	var forward := next_rank * 8 + file
	if int(board[forward]) == 0:
		_push_pawn(sq, forward, side, moves)
		var start_rank := 1 if side == 1 else 6
		if rank == start_rank:
			var double := (rank + 2 * side) * 8 + file
			if int(board[double]) == 0:
				moves.append(_mv(sq, double))
	for delta in [-1, 1]:
		var capture_file: int = file + int(delta)
		if capture_file < 0 or capture_file > 7:
			continue
		var capture: int = next_rank * 8 + capture_file
		if int(board[capture]) * side < 0:
			_push_pawn(sq, capture, side, moves)
		elif ep_square >= 0 and capture == ep_square:
			moves.append(_mv(sq, capture, 0, false, true))


func _push_pawn(origin: int, target: int, side: int, moves: Array) -> void:
	var last_rank := 7 if side == 1 else 0
	if target / 8 == last_rank:
		for promo in [QUEEN, ROOK, BISHOP, KNIGHT]:
			moves.append(_mv(origin, target, promo))
	else:
		moves.append(_mv(origin, target))


func _leaps(sq: int, side: int, dirs: Array, moves: Array) -> void:
	var file := sq % 8
	var rank := sq / 8
	for step in dirs:
		var target := _at(file + step.x, rank + step.y)
		if target >= 0 and int(board[target]) * side <= 0:
			moves.append(_mv(sq, target))


func _slides(sq: int, side: int, dirs: Array, moves: Array) -> void:
	var file := sq % 8
	var rank := sq / 8
	for step in dirs:
		var next_file: int = file + int(step.x)
		var next_rank: int = rank + int(step.y)
		while next_file >= 0 and next_file <= 7 and next_rank >= 0 and next_rank <= 7:
			var target: int = next_rank * 8 + next_file
			var occupant := int(board[target])
			if occupant == 0:
				moves.append(_mv(sq, target))
			else:
				if occupant * side < 0:
					moves.append(_mv(sq, target))
				break
			next_file += step.x
			next_rank += step.y


func _castling(moves: Array) -> void:
	if white_to_move:
		if int(board[4]) != KING or _king_in_check(true):
			return
		if castle_wk and int(board[7]) == ROOK and int(board[5]) == 0 and int(board[6]) == 0:
			if not is_attacked(5, false) and not is_attacked(6, false):
				moves.append(_mv(4, 6, 0, true, false))
		if castle_wq and int(board[0]) == ROOK and int(board[1]) == 0 and int(board[2]) == 0 and int(board[3]) == 0:
			if not is_attacked(3, false) and not is_attacked(2, false):
				moves.append(_mv(4, 2, 0, true, false))
	else:
		if int(board[60]) != -KING or _king_in_check(false):
			return
		if castle_bk and int(board[63]) == -ROOK and int(board[61]) == 0 and int(board[62]) == 0:
			if not is_attacked(61, true) and not is_attacked(62, true):
				moves.append(_mv(60, 62, 0, true, false))
		if castle_bq and int(board[56]) == -ROOK and int(board[57]) == 0 and int(board[58]) == 0 and int(board[59]) == 0:
			if not is_attacked(59, true) and not is_attacked(58, true):
				moves.append(_mv(60, 58, 0, true, false))


func is_attacked(sq: int, by_white: bool) -> bool:
	if sq < 0 or sq > 63:
		return false
	var side := 1 if by_white else -1
	var file := sq % 8
	var rank := sq / 8
	var pawn_rank := rank + (-1 if by_white else 1)
	if pawn_rank >= 0 and pawn_rank <= 7:
		for delta in [-1, 1]:
			var pawn_sq := _at(file + delta, pawn_rank)
			if pawn_sq >= 0 and int(board[pawn_sq]) == side * PAWN:
				return true
	for step in KNIGHT_DIRS:
		var knight_sq := _at(file + step.x, rank + step.y)
		if knight_sq >= 0 and int(board[knight_sq]) == side * KNIGHT:
			return true
	for step in KING_DIRS:
		var king_sq := _at(file + step.x, rank + step.y)
		if king_sq >= 0 and int(board[king_sq]) == side * KING:
			return true
	for step in BISHOP_DIRS:
		if _sees(file, rank, step, side, true):
			return true
	for step in ROOK_DIRS:
		if _sees(file, rank, step, side, false):
			return true
	return false


func _sees(file: int, rank: int, step: Vector2i, side: int, diagonal: bool) -> bool:
	var next_file := file + step.x
	var next_rank := rank + step.y
	while next_file >= 0 and next_file <= 7 and next_rank >= 0 and next_rank <= 7:
		var occupant := int(board[next_rank * 8 + next_file])
		if occupant != 0:
			if occupant * side < 0:
				return false
			var kind := absi(occupant)
			if diagonal:
				return kind == BISHOP or kind == QUEEN
			return kind == ROOK or kind == QUEEN
		next_file += step.x
		next_rank += step.y
	return false


func _king_in_check(white: bool) -> bool:
	return is_attacked(king_square(white), not white)


func _clear_castle(sq: int) -> void:
	match sq:
		4:
			castle_wk = false
			castle_wq = false
		0:
			castle_wq = false
		7:
			castle_wk = false
		60:
			castle_bk = false
			castle_bq = false
		56:
			castle_bq = false
		63:
			castle_bk = false


func _move_castling_rook(king_target: int) -> void:
	match king_target:
		6:
			board[5] = board[7]
			board[7] = 0
		2:
			board[3] = board[0]
			board[0] = 0
		62:
			board[61] = board[63]
			board[63] = 0
		58:
			board[59] = board[56]
			board[56] = 0


func _mv(origin: int, target: int, promo: int = 0, castle: bool = false, ep: bool = false) -> Dictionary:
	return {"from": origin, "to": target, "promo": promo, "castle": castle, "ep": ep}


func _at(file: int, rank: int) -> int:
	if file < 0 or file > 7 or rank < 0 or rank > 7:
		return -1
	return rank * 8 + file


func _file_char(sq: int) -> String:
	return "abcdefgh"[sq % 8]


func _disambiguation(move: Dictionary) -> String:
	var origin := int(move.from)
	var kind := absi(int(board[origin]))
	if kind == PAWN or kind == KING:
		return ""
	var others: Array = []
	for candidate in legal_moves():
		if int(candidate.from) == origin or int(candidate.to) != int(move.to):
			continue
		if absi(int(board[candidate.from])) == kind:
			others.append(candidate)
	if others.is_empty():
		return ""
	var file_unique := true
	var rank_unique := true
	for candidate in others:
		if int(candidate.from) % 8 == origin % 8:
			file_unique = false
		if int(candidate.from) / 8 == origin / 8:
			rank_unique = false
	if file_unique:
		return _file_char(origin)
	if rank_unique:
		return str((origin / 8) + 1)
	return _file_char(origin) + str((origin / 8) + 1)


func _insufficient() -> bool:
	var minors := 0
	for sq in 64:
		var kind := absi(int(board[sq]))
		if kind == PAWN or kind == ROOK or kind == QUEEN:
			return false
		if kind == BISHOP or kind == KNIGHT:
			minors += 1
	return minors <= 1


func _key() -> String:
	var parts := to_fen().split(" ")
	return "%s %s %s %s" % [parts[0], parts[1], parts[2], parts[3]]


func _note_rep() -> void:
	var key := _key()
	rep[key] = int(rep.get(key, 0)) + 1
