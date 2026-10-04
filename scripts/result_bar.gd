class_name ResultBar
extends Control

# A thin bar showing how often White won, drew and lost, like the opening
# explorers on chess sites.

var white_wins := 0
var drawn := 0
var black_wins := 0
var light := Color("e8dccb")
var middle := Color("8a7b6a")
var dark := Color("3a3128")
var outline := Color("5a4d3e")


func _init() -> void:
	custom_minimum_size = Vector2(120, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_counts(white_count: int, draw_count: int, black_count: int) -> void:
	white_wins = white_count
	drawn = draw_count
	black_wins = black_count
	queue_redraw()


func _draw() -> void:
	var total := white_wins + drawn + black_wins
	var box := Rect2(Vector2.ZERO, size)
	if total <= 0:
		draw_rect(box, middle)
		return
	var x := 0.0
	var parts := [[white_wins, light], [drawn, middle], [black_wins, dark]]
	for i in parts.size():
		var amount := int(parts[i][0])
		if amount <= 0:
			continue
		var width := size.x * float(amount) / float(total)
		if x + width > size.x or i == parts.size() - 1:
			width = size.x - x
		draw_rect(Rect2(x, 0, width, size.y), parts[i][1] as Color)
		x += width
	draw_rect(box, outline, false, 1.0)
