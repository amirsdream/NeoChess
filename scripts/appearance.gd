class_name Appearance
extends RefCounted


static func board_count() -> int:
	return _boards().size()


static func board_name(index: int) -> String:
	return str(_boards()[_index(index, board_count())].name)


static func board(index: int) -> Dictionary:
	var src: Dictionary = _boards()[_index(index, board_count())]
	var copy := src.duplicate()
	copy.erase("name")
	return copy


static func palette(index: int) -> Dictionary:
	var b := board(index)
	var dark: Color = b["dark"]
	var gold: Color = b["trim"]
	var h := dark.h
	var s := clampf(dark.s * 0.85, 0.10, 0.50)
	var white := Color(1, 1, 1)
	return {
		"bg": Color.from_hsv(h, s, 0.115),
		"surface": Color.from_hsv(h, s, 0.16),
		"raised": Color.from_hsv(h, s, 0.21),
		"line": Color.from_hsv(h, s, 0.28),
		"btn_hover": Color.from_hsv(h, s, 0.35),
		"field": Color.from_hsv(h, s, 0.135),
		"picked": Color.from_hsv(h, s, 0.31),
		"off": Color.from_hsv(h, s, 0.19),
		"gold": gold,
		"gold_soft": gold.lerp(white, 0.3),
		"gold_hover": gold.lerp(white, 0.14),
		"gold_down": gold.darkened(0.2),
		"on_gold": Color.from_hsv(h, 0.5, 0.11),
		"text": Color.from_hsv(h, 0.05, 0.96),
		"text_hi": Color.from_hsv(h, 0.03, 1.0),
		"title": Color.from_hsv(h, 0.04, 0.97),
		"line_text": Color.from_hsv(h, 0.10, 0.90),
		"muted": Color.from_hsv(h, 0.14, 0.70),
		"dim": Color.from_hsv(h, 0.15, 0.56),
	}

static func piece_count() -> int:
	return _pieces().size()


static func piece_name(index: int) -> String:
	return str(_pieces()[_index(index, piece_count())].name)


static func piece_set(index: int) -> Dictionary:
	return _pieces()[_index(index, piece_count())].duplicate()


static func _index(index: int, count: int) -> int:
	return clampi(index, 0, count - 1)


static func _boards() -> Array:
	var last := Color(0.86, 0.68, 0.22, 0.40)
	var selected := Color(0.92, 0.76, 0.28, 0.55)
	var check := Color(0.84, 0.16, 0.12, 0.55)
	var hover := Color(1, 1, 1, 0.12)
	var dot := Color(0.07, 0.04, 0.02, 0.72)
	var ring := Color(0.06, 0.04, 0.02, 0.34)
	var night_dot := Color(1, 1, 1, 0.48)
	var night_ring := Color(1, 1, 1, 0.38)
	return [
		_board("Walnut", "f0d9b5", "b58863", "3b2a1e", "c6a15b", "6b4a30", "f6ead8", last, selected, check, hover, dot, ring),
		_board("Maple", "f7e7c3", "c4894a", "4a3018", "e0b15a", "6a4520", "fff3dd", last, selected, check, hover, dot, ring),
		_board("Ocean", "d5e6f5", "5d87a8", "173044", "8ec4e6", "1d4564", "f3f8fc", last, selected, check, hover, dot, ring),
		_board("Pine", "e4f0d4", "5e8a45", "243318", "a8c97a", "2d4a22", "f4fbea", last, selected, check, hover, dot, ring),
		_board("Imperial", "e9e0f6", "7d5eae", "2a2040", "c4b0e6", "3d2a62", "f7f2ff", last, selected, check, hover, dot, ring),
		_board("Marble", "f7f4ee", "a39e96", "3c3a36", "d9d3c8", "4a463f", "fbfaf7", last, selected, check, hover, dot, ring),
		_board("Coral", "fde7dc", "d98470", "4a2c24", "f2b8a4", "6a3428", "fff6f2", last, selected, check, hover, dot, ring),
		_board("Glacier", "eef8fb", "6aafc4", "163844", "b7e4f0", "1a4d60", "f6fdff", last, selected, check, hover, dot, ring),
		_board("Midnight", "6d717c", "3c404a", "14161b", "c6a15b", "e8e6e1", "f7f4ee", Color(0.90, 0.74, 0.32, 0.38), selected, check, Color(1, 1, 1, 0.08), night_dot, night_ring),
		_board("Rosewood", "f8e4ea", "c45d7a", "3d2030", "f0b4c6", "6a3044", "fff5f8", last, selected, check, hover, dot, ring),
		_board("Slate", "d7e0e8", "5a7082", "1c2830", "9bb0c2", "243844", "f4f8fb", last, selected, check, hover, dot, ring),
		_board("Sandstone", "f6e6c4", "c4a05a", "3e2e18", "e6c98a", "5c4320", "fff8e8", last, selected, check, hover, dot, ring),
	]


static func _board(
	set_name: String,
	light: String,
	dark: String,
	frame: String,
	trim: String,
	coord_light: String,
	coord_dark: String,
	last: Color,
	selected: Color,
	check: Color,
	hover: Color,
	dot: Color,
	ring: Color
) -> Dictionary:
	return {
		"name": set_name,
		"light": Color(light),
		"dark": Color(dark),
		"frame": Color(frame),
		"trim": Color(trim),
		"coord_light": Color(coord_light),
		"coord_dark": Color(coord_dark),
		"last": last,
		"selected": selected,
		"check": check,
		"hover": hover,
		"dot": dot,
		"ring": ring,
	}


static func _pieces() -> Array:
	return [
		_piece("Ivory & Ebony", "f7f3ea", "2b241c", "1a1a1a", "0c0c0c", "e4dccf", "d4af37"),
		_piece("Porcelain & Ink", "ffffff", "3a3a3a", "1e1e1e", "111111", "f2f2f2", "c8c8c8"),
		_piece("Gold & Bronze", "f6e2b8", "6e4e1e", "6a3d1c", "3a2010", "e8c48a", "ffe7a3"),
		_piece("Silver & Graphite", "e8eef3", "4d5c68", "2a3136", "14181c", "c9d4dc", "f7fbff"),
		_piece("Crimson & Black", "f8e8e4", "6b2430", "6e1c28", "2e0c12", "f0b8b4", "ffd0a6"),
		_piece("Navy & Ivory", "f4f1e8", "1c335c", "15284a", "0a162c", "c5d4ee", "e7c56a"),
		_piece("Forest & Cream", "f3f6ea", "1d4a32", "173d2c", "0c2418", "c6e2c4", "e4c15a"),
		_piece("Rose & Plum", "fdeef4", "7a3a56", "4a2040", "2a1026", "f3c4d6", "ffe0ee"),
		_piece("Ice & Cobalt", "f5fbff", "1f6488", "0e4c6c", "062636", "c8e8f6", "ffffff"),
		_piece("Amber & Charcoal", "fff1d4", "7a5210", "3a2c24", "1a120e", "f0d0a0", "ffe08a"),
		_piece("Mint & Pine", "e9fff6", "1a6552", "103e36", "08241e", "b8f0e0", "fff6d4"),
		_piece("High Contrast", "ffffff", "000000", "111111", "000000", "ffffff", "ffcc00"),
	]


static func _piece(
	set_name: String,
	light: String,
	light_edge: String,
	dark: String,
	dark_edge: String,
	shine: String,
	accent: String
) -> Dictionary:
	return {
		"name": set_name,
		"light": Color(light),
		"light_edge": Color(light_edge),
		"dark": Color(dark),
		"dark_edge": Color(dark_edge),
		"shine": Color(shine),
		"accent": Color(accent),
	}
