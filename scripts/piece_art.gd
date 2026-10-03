class_name PieceArt
extends RefCounted

const FILE_FOR := {
	1: "wP",
	2: "wN",
	3: "wB",
	4: "wR",
	5: "wQ",
	6: "wK",
	-1: "bP",
	-2: "bN",
	-3: "bB",
	-4: "bR",
	-5: "bQ",
	-6: "bK",
}

static var _svg_text := {}
static var _cache := {}


static func textures_for(palette_index: int) -> Dictionary:
	var index := clampi(palette_index, 0, Appearance.piece_count() - 1)
	if _cache.has(index):
		return _cache[index]
	var palette := Appearance.piece_set(index)
	var result := {}
	for code in FILE_FOR:
		var piece := int(code)
		var svg := _tint(_source(str(FILE_FOR[piece])), piece > 0, palette)
		var image := Image.new()
		var err := image.load_svg_from_string(svg, 6.0)
		if err != OK or image.is_empty():
			push_error("Could not draw %s (%s)." % [FILE_FOR[piece], error_string(err)])
			continue
		_relief(image)
		result[piece] = ImageTexture.create_from_image(image)
	_cache[index] = result
	return result


static func _source(file_name: String) -> String:
	if _svg_text.has(file_name):
		return str(_svg_text[file_name])
	var text := FileAccess.get_file_as_string("res://pieces/%s.svg.txt" % file_name)
	_svg_text[file_name] = text
	return text


static func _tint(svg: String, light: bool, palette: Dictionary) -> String:
	var fill := _hex(palette.light)
	var edge := _hex(palette.light_edge)
	var body := _hex(palette.dark)
	var dark_edge := _hex(palette.dark_edge)
	var shine := _hex(palette.shine)
	var accent := _hex(palette.accent)
	if light:
		svg = svg.replace('stroke="#000"', 'stroke="%s"' % edge)
		svg = svg.replace('fill="#000"', 'fill="%s"' % edge)
		svg = svg.replace('fill="#fff"', 'fill="%s"' % fill)
	else:
		svg = svg.replace('stroke="#ececec"', 'stroke="%s"' % shine)
		svg = svg.replace('fill="#ececec"', 'fill="%s"' % shine)
		svg = svg.replace('stroke="#000"', 'stroke="%s"' % dark_edge)
		svg = svg.replace('fill="#000"', 'fill="%s"' % body)
		svg = svg.replace('fill="#fff"', 'fill="%s"' % shine)
		svg = _ensure_fill(svg, body)
	return _accent_cross(svg, accent)


static func _accent_cross(svg: String, accent: String) -> String:
	var marks := PackedStringArray([
		'd="M22.5 11.63V6M20 8h5"',
		'd="M22.5 11.6V6"',
		'd="M20 8h5"',
	])
	for mark in marks:
		if svg.contains(mark):
			svg = svg.replace(mark, 'stroke="%s" %s' % [accent, mark])
	return svg


static func _ensure_fill(svg: String, fill: String) -> String:
	var out := ""
	var cursor := 0
	while true:
		var start := svg.find("<", cursor)
		if start < 0:
			out += svg.substr(cursor)
			break
		out += svg.substr(cursor, start - cursor)
		var end := svg.find(">", start)
		if end < 0:
			out += svg.substr(start)
			break
		var tag := svg.substr(start, end - start + 1)
		var shaped := tag.begins_with("<path") or tag.begins_with("<circle") or tag.begins_with("<ellipse") or tag.begins_with("<polygon") or tag.begins_with("<rect")
		if shaped and not tag.contains("fill="):
			if tag.ends_with("/>"):
				tag = tag.substr(0, tag.length() - 2) + (' fill="%s"/>' % fill)
			else:
				tag = tag.substr(0, tag.length() - 1) + (' fill="%s">' % fill)
		out += tag
		cursor = end + 1
	return out


static func _hex(color: Color) -> String:
	return "#" + color.to_html(false)


static func _relief(image: Image) -> void:
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	var min_x := w
	var min_y := h
	var max_x := 0
	var max_y := 0
	for y in h:
		var row := y * w
		for x in w:
			if data[(row + x) * 4 + 3] > 24:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x <= min_x or max_y <= min_y:
		return
	var span_x := float(max_x - min_x)
	var span_y := float(max_y - min_y)
	for y in range(min_y, max_y + 1):
		var row := y * w
		var v := float(y - min_y) / span_y
		for x in range(min_x, max_x + 1):
			var i := (row + x) * 4
			var alpha := int(data[i + 3])
			if alpha < 8:
				continue
			var u := float(x - min_x) / span_x
			var light := 1.22 - v * 0.42 - u * 0.08
			if v < 0.34:
				light += (0.34 - v) * 0.45
			var spec := 0.0
			if v > 0.08 and v < 0.36:
				spec = (1.0 - absf(v - 0.2) / 0.18) * 0.16 * sin(u * PI)
			var edge := 0.0
			if x == min_x or y == min_y or x == max_x or y == max_y or data[(row + x - 1) * 4 + 3] < 16 or data[((y - 1) * w + x) * 4 + 3] < 16:
				edge = 0.08
			data[i] = clampi(int(float(data[i]) * light + (spec + edge) * 255.0), 0, 255)
			data[i + 1] = clampi(int(float(data[i + 1]) * light + (spec + edge) * 255.0), 0, 255)
			data[i + 2] = clampi(int(float(data[i + 2]) * light + spec * 220.0), 0, 255)
	image.set_data(w, h, false, Image.FORMAT_RGBA8, data)
