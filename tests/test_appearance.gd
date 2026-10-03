extends "res://tests/test_base.gd"

# Checks the board and piece themes, and that every derived app palette stays
# readable (WCAG contrast) on every board.

const BOARD_KEYS := ["light", "dark", "frame", "trim", "coord_light", "coord_dark", "last", "selected", "check", "hover", "dot", "ring"]
const PIECE_KEYS := ["light", "light_edge", "dark", "dark_edge", "shine", "accent"]
const PALETTE_KEYS := [
	"bg", "surface", "raised", "line", "gold", "gold_soft", "text", "muted", "dim", "gold_hover",
	"gold_down", "on_gold", "text_hi", "title", "line_text", "btn_hover", "field", "picked", "off",
]


func run() -> void:
	_boards()
	_pieces()
	_palettes()
	_piece_art()


func _boards() -> void:
	expect_true("has boards", Appearance.board_count() >= 12)
	var names := {}
	for i in Appearance.board_count():
		var board := Appearance.board(i)
		var name := Appearance.board_name(i)
		expect_true("board %d has a name" % i, name != "")
		expect("board %s name is unique" % name, names.has(name), false)
		names[name] = true
		for key in BOARD_KEYS:
			expect_true("board %s has %s" % [name, key], board.has(key))
		var light: Color = board["light"]
		var dark: Color = board["dark"]
		expect_true("board %s squares differ" % name, _contrast(light, dark) >= 1.5, "(%.2f)" % _contrast(light, dark))
		expect("board data has no name key", board.has("name"), false)
	expect("board index clamps low", Appearance.board_name(-5), Appearance.board_name(0))
	expect("board index clamps high", Appearance.board_name(999), Appearance.board_name(Appearance.board_count() - 1))


func _pieces() -> void:
	expect_true("has piece sets", Appearance.piece_count() >= 12)
	var names := {}
	for i in Appearance.piece_count():
		var set := Appearance.piece_set(i)
		var name := Appearance.piece_name(i)
		expect("piece set %s name is unique" % name, names.has(name), false)
		names[name] = true
		for key in PIECE_KEYS:
			expect_true("piece set %s has %s" % [name, key], set.has(key))
		var light: Color = set["light"]
		var dark: Color = set["dark"]
		expect_true("piece set %s sides are distinguishable" % name, _contrast(light, dark) >= 3.0, "(%.2f)" % _contrast(light, dark))


func _palettes() -> void:
	for i in Appearance.board_count():
		var name := Appearance.board_name(i)
		var pal := Appearance.palette(i)
		for key in PALETTE_KEYS:
			expect_true("palette %s has %s" % [name, key], pal.has(key))
		expect("palette %s size" % name, pal.size(), PALETTE_KEYS.size())
		var text: Color = pal["text"]
		var muted: Color = pal["muted"]
		var dim: Color = pal["dim"]
		var gold: Color = pal["gold"]
		var gold_soft: Color = pal["gold_soft"]
		var on_gold: Color = pal["on_gold"]
		for surface_key in ["bg", "surface", "raised", "field"]:
			var surface: Color = pal[surface_key]
			_at_least("%s text on %s" % [name, surface_key], text, surface, 7.0)
			_at_least("%s muted on %s" % [name, surface_key], muted, surface, 4.5)
			_at_least("%s accent on %s" % [name, surface_key], gold_soft, surface, 4.5)
		_at_least("%s dim on raised" % name, dim, pal["raised"], 3.0)
		_at_least("%s button text" % name, pal["text"], pal["line"], 4.5)
		_at_least("%s text on picked chip" % name, text, pal["picked"], 4.5)
		_at_least("%s label on accent" % name, on_gold, gold, 4.5)
		_at_least("%s label on accent hover" % name, on_gold, pal["gold_hover"], 4.5)
		_at_least("%s accent against background" % name, gold, pal["bg"], 3.0)
		expect_true("%s surfaces step up" % name, _luma(pal["bg"]) < _luma(pal["surface"]) and _luma(pal["surface"]) < _luma(pal["raised"]))


func _piece_art() -> void:
	for i in Appearance.piece_count():
		var textures := PieceArt.textures_for(i)
		expect("piece art %s count" % Appearance.piece_name(i), textures.size(), 12)
		for code in [1, 2, 3, 4, 5, 6, -1, -2, -3, -4, -5, -6]:
			expect_true("piece art %s has %d" % [Appearance.piece_name(i), code], textures.has(code))
	var first := PieceArt.textures_for(0)
	expect("art is cached", PieceArt.textures_for(0) == first, true)
	expect("index clamps", PieceArt.textures_for(-3).size(), 12)


func _at_least(label: String, foreground: Color, background: Color, minimum: float) -> void:
	var ratio := _contrast(foreground, background)
	expect_true("contrast " + label, ratio >= minimum, "(%.2f, needs %.1f)" % [ratio, minimum])


func _luma(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


func _contrast(a: Color, b: Color) -> float:
	var la := _luma(a)
	var lb := _luma(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
