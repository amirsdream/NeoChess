extends SceneTree

# Builds data/openings.tsv from the Lichess chess-openings files (a.tsv to e.tsv,
# CC0, https://github.com/lichess-org/chess-openings):
#   godot --headless --path . --script dev/build_openings.gd -- <folder with a.tsv..e.tsv>
# Each opening line is played out once and written with the key of the position
# it ends in, so the game can recognise an opening without replaying 3,800 lines.
# Columns: eco, name, plies, position key, moves.

var states := {"": null}


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <folder with a.tsv .. e.tsv>")
		quit(2)
		return
	states[""] = ChessGame.new()
	var out := PackedStringArray(["eco\tname\tplies\tkey\tmoves"])
	var failed := 0
	for letter in ["a", "b", "c", "d", "e"]:
		var file := FileAccess.open(String(args[0]).path_join(letter + ".tsv"), FileAccess.READ)
		if file == null:
			print("missing ", letter, ".tsv")
			quit(1)
			return
		file.get_line()
		while not file.eof_reached():
			var columns := file.get_line().split("\t")
			if columns.size() < 3:
				continue
			var game: Variant = _play(columns[2])
			if game == null:
				failed += 1
				print("cannot play: ", columns[0], " ", columns[1], " ", columns[2])
				continue
			var plies := _tokens(columns[2]).size()
			out.append("%s\t%s\t%d\t%s\t%s" % [columns[0], columns[1], plies, OpeningNames.key_of(game), columns[2]])
	var target := ProjectSettings.globalize_path("res://data/openings.tsv")
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var result := FileAccess.open(target, FileAccess.WRITE)
	result.store_string("\n".join(out) + "\n")
	result.close()
	print("wrote %d openings (%d failed) to %s" % [out.size() - 1, failed, target])
	quit()


# Plays "1. e4 e5 2. Nf3" and returns the game, or null when a move is illegal.
# Positions are shared between lines that start the same way.
func _play(pgn: String) -> Variant:
	var tokens := _tokens(pgn)
	var prefix := ""
	var game = states[""]
	for token in tokens:
		var next_prefix := prefix + " " + token
		if states.has(next_prefix):
			game = states[next_prefix]
		else:
			var found := Pgn.find_move(game, token)
			var move: Dictionary = found.get("move", {})
			if move.is_empty():
				return null
			var next = game.clone()
			next.make_move(move)
			states[next_prefix] = next
			game = next
		prefix = next_prefix
	return game


func _tokens(pgn: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	for word in pgn.split(" ", false):
		if not word.ends_with("."):
			tokens.append(word)
	return tokens
