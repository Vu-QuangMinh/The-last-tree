class_name WingsIcon
extends Control
## A pair of angel wings: a fallen Handyman hand that will be resurrected (shown beside an hourglass of turns left).

const SIZE := 40.0


static func make() -> WingsIcon:
	var w := WingsIcon.new()
	w.custom_minimum_size = Vector2(SIZE * 1.3, SIZE)
	w.size = w.custom_minimum_size
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return w


func _draw() -> void:
	var c := Vector2(size.x / 2.0, size.y * 0.55)
	for side in [-1.0, 1.0]:
		_wing(c + Vector2(side * 3.0, 0), side)
	# a little halo above
	draw_arc(c + Vector2(0, -SIZE * 0.36), SIZE * 0.16, 0, TAU, 24, Color(1.0, 0.85, 0.35), 2.5, true)


## One wing: three layered feathers fanning out to one side.
func _wing(root: Vector2, side: float) -> void:
	var outline := Color(0.75, 0.6, 0.25)
	for k in 3:
		var f := float(k)
		var tip := root + Vector2(side * (SIZE * (0.62 - f * 0.1)), -SIZE * (0.34 - f * 0.2))
		var low := root + Vector2(side * SIZE * (0.3 - f * 0.05), SIZE * (0.12 + f * 0.08))
		var pts := PackedVector2Array([root, tip, low])
		draw_colored_polygon(pts, Color(1, 1, 1).darkened(f * 0.08))
		pts.append(root)
		draw_polyline(pts, outline, 1.5, true)
