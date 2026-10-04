class_name BoardView
extends Control

signal square_clicked(sq: int)
signal animation_finished

const LIGHT := Color("f0d9b5")
const DARK := Color("b58863")
const FRAME := Color("2a2118")
const GOLD := Color("c6a15b")
const LAST := Color(0.72, 0.55, 0.18, 0.48)
const SELECTED := Color(0.85, 0.72, 0.22, 0.62)
const CHECK := Color(0.78, 0.16, 0.12, 0.58)
const HOVER := Color(1, 1, 1, 0.10)
const EVAL_RESERVE := 46.0
# Arrows for the three best moves: [colour, width compared with the last-move arrow].
const ANALYSIS_ARROWS := [
	[Color(0.30, 0.66, 0.98, 0.95), 1.45],
	[Color(0.30, 0.66, 0.98, 0.78), 0.9],
	[Color(0.30, 0.66, 0.98, 0.6), 0.5],
]
const EVAL_WIDTH := 26.0

var board := PackedInt32Array()
var white_bottom := true
var selected := -1
var targets := {}
var captures := {}
var last_from := -1
var last_to := -1
var show_last_arrow := true
# Stockfish's best moves as arrows, best first: [{from, to}]. The best one is
# drawn thick, the second medium and the third thin.
var analysis_arrows: Array = []
var show_analysis_arrows := true
var show_eval := true
var eval_share := 0.5:
	set(value):
		eval_share = value
		queue_redraw()
var eval_text := "0.0":
	set(value):
		eval_text = value
		queue_redraw()
var check_sq := -1
var hot := {}
var hover_sq := -1

var anim_from := -1
var anim_to := -1
var anim_piece := 0
var anim_t := 1.0
var anim_captured := 0
var anim_captured_sq := -1
var anim_rook_from := -1
var anim_rook_to := -1
var anim_rook_piece := 0
var theme_colors := {}
var piece_textures := {}
var grain: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)
	board.resize(64)
	grain = _make_grain()


func apply_style(colors: Dictionary, textures: Dictionary) -> void:
	theme_colors = colors
	piece_textures = textures
	queue_redraw()


func _c(key: String, fallback: Color) -> Color:
	if theme_colors.has(key):
		return theme_colors[key]
	return fallback


func show_position(
	pos: PackedInt32Array,
	white_at_bottom: bool,
	selected_sq: int,
	target_list: Array,
	capture_list: Array,
	last_a: int,
	last_b: int,
	checked: int,
	hot_squares: Dictionary
) -> void:
	board = pos.duplicate()
	white_bottom = white_at_bottom
	selected = selected_sq
	targets = {}
	captures = {}
	for sq in target_list:
		targets[int(sq)] = true
	for sq in capture_list:
		captures[int(sq)] = true
	last_from = last_a
	last_to = last_b
	check_sq = checked
	hot = hot_squares
	queue_redraw()


func animate(from_sq: int, to_sq: int, piece: int, captured: int = 0, captured_sq: int = -1, rook_from: int = -1, rook_to: int = -1, rook_piece: int = 0) -> void:
	anim_from = from_sq
	anim_to = to_sq
	anim_piece = piece
	anim_captured = captured
	anim_captured_sq = captured_sq
	anim_rook_from = rook_from
	anim_rook_to = rook_to
	anim_rook_piece = rook_piece
	anim_t = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if anim_piece == 0:
		return
	var duration := 0.36
	if absi(anim_piece) == ChessGame.KNIGHT:
		duration = 0.46
	elif absi(anim_piece) == ChessGame.KING:
		duration = 0.42
	anim_t = minf(1.0, anim_t + delta / duration)
	queue_redraw()
	if anim_t >= 1.0:
		anim_piece = 0
		anim_from = -1
		anim_to = -1
		anim_captured = 0
		anim_captured_sq = -1
		anim_rook_from = -1
		anim_rook_to = -1
		anim_rook_piece = 0
		set_process(false)
		animation_finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _sq_at(event.position)
		if hovered != hover_sq:
			hover_sq = hovered
			queue_redraw()
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if hot.has(hovered) else CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var sq := _sq_at(event.position)
		if sq >= 0:
			square_clicked.emit(sq)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		hover_sq = -1
		mouse_default_cursor_shape = CURSOR_ARROW
		queue_redraw()


func _draw() -> void:
	var layout := _layout()
	var origin: Vector2 = layout.origin
	var square: float = layout.sq
	var frame: float = layout.frame
	var outer := Rect2(origin - Vector2(frame, frame), Vector2(square * 8.0 + frame * 2.0, square * 8.0 + frame * 2.0))
	var trim := _c("trim", GOLD)
	draw_rect(outer.grow(14.0), Color(0, 0, 0, 0.38))
	draw_rect(outer.grow(7.0), trim.darkened(0.35))
	draw_rect(outer.grow(3.0), trim.lightened(0.12))
	draw_rect(outer, _c("frame", FRAME))
	draw_line(outer.position + Vector2(2, 2), outer.position + Vector2(outer.size.x - 2, 2), Color(1, 1, 1, 0.22), 2.0, true)
	draw_line(outer.position + Vector2(2, outer.size.y - 2), outer.end - Vector2(2, 2), Color(0, 0, 0, 0.35), 2.0, true)
	if show_eval:
		_draw_eval(layout)

	for sq in 64:
		var cell := _cell(sq, layout)
		var file := sq % 8
		var rank := sq / 8
		var dark := (file + rank) % 2 == 0
		var base := _c("dark", DARK) if dark else _c("light", LIGHT)
		draw_rect(cell, base)
		if grain != null:
			var src := Rect2(float((file * 17) % 64), float((rank * 13) % 64), 52.0, 52.0)
			draw_texture_rect_region(grain, cell, src, base)
		var hi := Color(1, 1, 1, 0.16 if not dark else 0.08)
		var lo := Color(0, 0, 0, 0.22 if dark else 0.14)
		draw_line(cell.position + Vector2(1, 1), cell.position + Vector2(cell.size.x - 1, 1), hi, 1.5, true)
		draw_line(cell.position + Vector2(1, 1), cell.position + Vector2(1, cell.size.y - 1), hi, 1.5, true)
		draw_line(cell.position + Vector2(1, cell.size.y - 1), cell.end - Vector2(1, 1), lo, 1.5, true)
		draw_line(cell.position + Vector2(cell.size.x - 1, 1), cell.end - Vector2(1, 1), lo, 1.5, true)
		if sq == last_from or sq == last_to:
			draw_rect(cell, _c("last", LAST))
		if sq == check_sq:
			draw_rect(cell, _c("check", CHECK))
		if sq == selected:
			draw_rect(cell, _c("selected", SELECTED))
		if sq == hover_sq and sq != selected:
			draw_rect(cell, _c("hover", HOVER))
	var board_rect := Rect2(origin, Vector2(square * 8.0, square * 8.0))
	draw_rect(Rect2(board_rect.position, Vector2(board_rect.size.x, 14)), Color(0, 0, 0, 0.16))
	draw_rect(Rect2(board_rect.position, Vector2(10, board_rect.size.y)), Color(0, 0, 0, 0.08))

	var font := _font()
	var font_size := int(clampf(square * 0.16, 11, 18))
	for sq in 64:
		var cell := _cell(sq, layout)
		var file := sq % 8
		var rank := sq / 8
		var sx := file if white_bottom else 7 - file
		var sy := (7 - rank) if white_bottom else rank
		if sx != 0 and sy != 7:
			continue
		var dark := (file + rank) % 2 == 0
		var tint := _c("coord_dark", Color("f3e6d0")) if dark else _c("coord_light", Color("7a5332"))
		if sx == 0:
			draw_string(font, cell.position + Vector2(4, font_size + 2), str(rank + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
		if sy == 7:
			draw_string(font, cell.position + Vector2(0, cell.size.y - 5), "abcdefgh"[file], HORIZONTAL_ALIGNMENT_RIGHT, cell.size.x - 4, font_size, tint)

	for sq in 64:
		if anim_piece != 0 and (sq == anim_to or sq == anim_rook_to):
			continue
		var piece := int(board[sq])
		if piece != 0:
			_draw_piece(_cell(sq, layout).get_center(), piece, square)

	for sq in targets:
		var cell := _cell(int(sq), layout)
		var center := cell.get_center()
		if captures.has(sq):
			draw_arc(center, square * 0.40, 0, TAU, 48, _c("ring", Color(0, 0, 0, 0.28)), maxf(square * 0.075, 4.0), true)
		else:
			draw_circle(center, square * 0.13, _c("dot", Color(0.12, 0.08, 0.04, 0.38)))

	if anim_piece != 0 and anim_from >= 0 and anim_to >= 0:
		var travel := anim_t * anim_t * (3.0 - 2.0 * anim_t)
		if anim_captured != 0 and anim_captured_sq >= 0:
			var fade := clampf(1.0 - anim_t / 0.62, 0.0, 1.0)
			if fade > 0.0:
				var caught := _cell(anim_captured_sq, layout).get_center()
				_draw_piece(caught, anim_captured, square, 0.0, Vector2.ONE * (1.0 - (1.0 - fade) * 0.18), fade)
		if anim_rook_piece != 0 and anim_rook_from >= 0 and anim_rook_to >= 0:
			var rook_start := _cell(anim_rook_from, layout).get_center()
			var rook_finish := _cell(anim_rook_to, layout).get_center()
			_draw_flight(rook_start, rook_finish, anim_rook_piece, square, travel, 0.05)
		var start := _cell(anim_from, layout).get_center()
		var finish := _cell(anim_to, layout).get_center()
		var hop := 0.16
		match absi(anim_piece):
			ChessGame.KNIGHT:
				hop = 0.32
			ChessGame.KING:
				hop = 0.09
			ChessGame.PAWN:
				hop = 0.13
		_draw_flight(start, finish, anim_piece, square, travel, hop)
		if anim_t > 0.78:
			var ring := (anim_t - 0.78) / 0.22
			draw_arc(finish, square * (0.18 + ring * 0.42), 0, TAU, 40, Color(1, 1, 1, (1.0 - ring) * 0.28), 2.0, true)

	if show_last_arrow and last_from >= 0 and last_to >= 0 and last_from != last_to:
		var fade := 1.0
		if anim_piece != 0:
			fade = clampf((anim_t - 0.25) / 0.6, 0.0, 1.0)
		_draw_arrow(_cell(last_from, layout).get_center(), _cell(last_to, layout).get_center(), square, fade)
	if show_analysis_arrows and anim_piece == 0:
		for rank in range(mini(analysis_arrows.size(), ANALYSIS_ARROWS.size()) - 1, -1, -1):
			var arrow: Dictionary = analysis_arrows[rank]
			var style: Array = ANALYSIS_ARROWS[rank]
			var from_sq := int(arrow["from"])
			var to_sq := int(arrow["to"])
			if from_sq >= 0 and to_sq >= 0:
				_draw_arrow(_cell(from_sq, layout).get_center(), _cell(to_sq, layout).get_center(), square, 1.0, style[0], float(style[1]))


# Sets the arrows for the best moves, best first, and redraws.
func set_analysis_arrows(arrows: Array) -> void:
	analysis_arrows = arrows
	queue_redraw()


func _layout() -> Dictionary:
	var frame := 22.0
	var reserve := EVAL_RESERVE if show_eval else 0.0
	var outer := minf(size.x - reserve, size.y)
	var side := maxf(outer - frame * 2.0, 8.0)
	var left := reserve + (size.x - reserve - outer) * 0.5
	var origin := Vector2(left, (size.y - outer) * 0.5) + Vector2(frame, frame)
	return {"frame": frame, "origin": origin, "sq": side / 8.0}


func _draw_eval(layout: Dictionary) -> void:
	var origin: Vector2 = layout.origin
	var square: float = layout.sq
	var frame: float = layout.frame
	var bar := Rect2(origin.x - frame - 10.0 - EVAL_WIDTH, origin.y, EVAL_WIDTH, square * 8.0)
	var dark_fill := Color("2a2521")
	var light_fill := Color("eee8de")
	draw_rect(bar.grow(3.0), Color(0, 0, 0, 0.5))
	var share := clampf(eval_share, 0.0, 1.0)
	var white_h := bar.size.y * share
	var black_h := bar.size.y - white_h
	if white_bottom:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x, black_h)), dark_fill)
		draw_rect(Rect2(bar.position + Vector2(0.0, black_h), Vector2(bar.size.x, white_h)), light_fill)
	else:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x, white_h)), light_fill)
		draw_rect(Rect2(bar.position + Vector2(0.0, white_h), Vector2(bar.size.x, black_h)), dark_fill)
	var mid := bar.position.y + bar.size.y * 0.5
	draw_line(Vector2(bar.position.x, mid), Vector2(bar.end.x, mid), Color(_c("trim", Color(0.78, 0.63, 0.36)), 0.85), 1.5)
	var font := _font()
	var white_ahead := share >= 0.5
	var at_bottom := white_ahead == white_bottom
	var ty := bar.end.y - 8.0 if at_bottom else bar.position.y + 17.0
	var tint := Color("2a2521") if white_ahead else Color("eee8de")
	draw_string(font, Vector2(bar.position.x, ty), eval_text, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 11, tint)


func _cell(sq: int, layout: Dictionary) -> Rect2:
	var file := sq % 8
	var rank := sq / 8
	var sx := file if white_bottom else 7 - file
	var sy := (7 - rank) if white_bottom else rank
	var origin: Vector2 = layout.origin
	var square: float = layout.sq
	return Rect2(origin + Vector2(sx * square, sy * square), Vector2(square, square))


func _sq_at(pos: Vector2) -> int:
	var layout := _layout()
	var origin: Vector2 = layout.origin
	var square: float = layout.sq
	var local := pos - origin
	if local.x < 0.0 or local.y < 0.0 or local.x >= square * 8.0 or local.y >= square * 8.0:
		return -1
	var sx := int(local.x / square)
	var sy := int(local.y / square)
	sx = clampi(sx, 0, 7)
	sy = clampi(sy, 0, 7)
	var file := sx if white_bottom else 7 - sx
	var rank := (7 - sy) if white_bottom else sy
	return rank * 8 + file


func _font() -> Font:
	var theme_font := get_theme_default_font()
	return theme_font if theme_font != null else ThemeDB.fallback_font


func _draw_arrow(start: Vector2, finish: Vector2, square: float, fade: float = 1.0, tint: Color = Color(0.86, 0.64, 0.2, 0.92), width_scale: float = 1.0) -> void:
	var delta := finish - start
	if delta.length() < square * 0.4 or fade <= 0.0:
		return
	var dir := delta.normalized()
	var side := Vector2(-dir.y, dir.x)
	var inset := minf(square * 0.22, delta.length() * 0.38)
	var tail := start + dir * inset
	var tip := finish - dir * minf(square * 0.12, delta.length() * 0.3)
	var width := maxf(square * 0.085, 5.0) * width_scale
	var head := maxf(width * 2.6, square * 0.2)
	var neck := tip - dir * head
	var color := Color(tint.r, tint.g, tint.b, tint.a * fade)
	var shade := Color(0.12, 0.06, 0.02, 0.88 * fade)
	draw_line(tail, neck, shade, width + 5.0, true)
	draw_line(tail, neck, color, width, true)
	var tip_shade := PackedVector2Array([tip + dir * 2.5, neck + side * (head * 0.68), neck - side * (head * 0.68)])
	var tip_fill := PackedVector2Array([tip, neck + side * (head * 0.5), neck - side * (head * 0.5)])
	draw_colored_polygon(tip_shade, shade)
	draw_colored_polygon(tip_fill, color)
	draw_circle(tail, width * 0.55 + 2.5, shade)
	draw_circle(tail, width * 0.55, color)


func _draw_flight(start: Vector2, finish: Vector2, piece: int, square: float, travel: float, hop: float) -> void:
	var delta := finish - start
	var side := Vector2.ZERO
	if delta.length() > 0.001:
		side = Vector2(-delta.y, delta.x).normalized()
	var arc := sin(anim_t * PI)
	var ground := start.lerp(finish, travel)
	var pos := ground + side * arc * square * 0.055 + Vector2(0, -arc * square * hop)
	var settle := 0.0
	if anim_t > 0.84:
		settle = sin((anim_t - 0.84) / 0.16 * PI) * 0.07
	var scale := Vector2(1.0 + arc * 0.05 + settle, 1.0 + arc * 0.12 - settle)
	_draw_piece(pos, piece, square, arc * square * hop, scale, 1.0, ground)


func _draw_piece(center: Vector2, piece: int, square: float, lift: float = 0.0, scale: Vector2 = Vector2.ONE, alpha: float = 1.0, shadow_at: Vector2 = Vector2(-1, -1)) -> void:
	var texture: Texture2D = piece_textures.get(piece)
	if texture == null:
		return
	var ground := center if shadow_at.x < 0.0 else shadow_at
	var lift_ratio := clampf(lift / maxf(square, 1.0), 0.0, 0.55)
	var shadow_size := Vector2(square, square) * (1.0 - lift_ratio * 0.28)
	var shadow := Rect2(ground - shadow_size * 0.5 + Vector2(square * 0.02, square * 0.045 + lift_ratio * square * 0.02), shadow_size)
	draw_texture_rect(texture, shadow, false, Color(0, 0, 0, alpha * (0.34 - lift_ratio * 0.2)))
	var body := Vector2(square, square) * scale
	var rect := Rect2(center - body * 0.5 + Vector2(0, -lift * 0.15), body)
	draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))


func _make_grain() -> Texture2D:
	var n := 128
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var speck := _grain_hash(x, y)
			var fine := _grain_hash(x * 3 + 19, y * 5 + 7)
			var fiber := 0.5 + 0.5 * sin(float(y) * 1.35)
			var value := 0.93 + fiber * 0.035 + (speck - 0.5) * 0.07 + (fine - 0.5) * 0.04
			image.set_pixel(x, y, Color(value, value * 0.992, value * 0.975))
	return ImageTexture.create_from_image(image)


func _grain_hash(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 255) / 255.0
