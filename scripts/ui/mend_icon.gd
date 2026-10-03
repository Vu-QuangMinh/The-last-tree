class_name MendIcon
extends Control
## The Mend intent's symbol: a red heart with a green arrow pointing up inside it.


static func make(px := 34.0) -> MendIcon:
	var m := MendIcon.new()
	m.custom_minimum_size = Vector2(px, px)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return m


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	# the classic heart curve, fitted to the box
	var pts := PackedVector2Array()
	for i in 48:
		var t := TAU * i / 48.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y + 1.5) * (s / 36.0))
	var ink := Color(0.25, 0.06, 0.05)
	draw_colored_polygon(pts, Color(0.88, 0.16, 0.16))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, ink, maxf(2.0, s * 0.07), true)
	# a soft shine on the upper left lobe
	draw_circle(c + Vector2(-s * 0.2, -s * 0.16), s * 0.07, Color(1, 0.75, 0.75, 0.7))
	# the green arrow, pointing up
	var u := s / 36.0
	var arrow := PackedVector2Array([
		c + Vector2(0, -10) * u, c + Vector2(8, -1) * u, c + Vector2(3.2, -1) * u, c + Vector2(3.2, 9) * u,
		c + Vector2(-3.2, 9) * u, c + Vector2(-3.2, -1) * u, c + Vector2(-8, -1) * u,
	])
	draw_colored_polygon(arrow, Color(0.35, 0.9, 0.35))
	var ac := arrow.duplicate()
	ac.append(arrow[0])
	draw_polyline(ac, Color(0.05, 0.3, 0.08), maxf(1.5, s * 0.05), true)
