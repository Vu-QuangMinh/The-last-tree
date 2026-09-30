class_name KindGlyph
extends Control
## Stand-in for a spell category icon that has no picture yet (assets/card/icons/kind_<kind>.png):
## a shield for Defensive, a sparkle for Utility.

var kind := "defense"


static func make(p_kind: String, px: Vector2) -> KindGlyph:
	var g := KindGlyph.new()
	g.kind = p_kind
	g.custom_minimum_size = px
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _draw() -> void:
	var w := size.x
	var h := size.y
	var ink := Color(0.12, 0.14, 0.24)
	var pts := PackedVector2Array()
	var fill: Color
	var shine: Color
	if kind == "defense":
		pts = PackedVector2Array([Vector2(0.1, 0.08), Vector2(0.9, 0.08), Vector2(0.9, 0.52), Vector2(0.5, 0.96), Vector2(0.1, 0.52)])
		fill = Color(0.42, 0.6, 0.86)
		shine = Color(0.66, 0.8, 0.96)
	else:
		# four-point sparkle
		for i in 8:
			var a := i * PI / 4.0 - PI / 2.0
			var rad := 0.48 if i % 2 == 0 else 0.17
			pts.append(Vector2(0.5 + cos(a) * rad, 0.5 + sin(a) * rad))
		fill = Color(0.96, 0.76, 0.22)
		shine = Color(1.0, 0.92, 0.55)
		ink = Color(0.42, 0.27, 0.04)
	var scaled := PackedVector2Array()
	for p in pts:
		scaled.append(Vector2(p.x * w, p.y * h))
	draw_colored_polygon(scaled, fill)
	var inner := PackedVector2Array()
	var mid := Vector2(0.5 * w, 0.5 * h)
	for p in scaled:
		inner.append(mid + (p - mid) * 0.6)
	draw_colored_polygon(inner, shine)
	scaled.append(scaled[0])
	draw_polyline(scaled, ink, maxf(1.5, w * 0.06), true)
