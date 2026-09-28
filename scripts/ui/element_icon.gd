class_name ElementIcon
extends Control
## One element drawn as a coloured orb with a glyph: flame (Fire), drop (Water), swirl (Air), ? (hidden).

var el := "F"
var armored := false
var ghost := false  # will be removed by the current chant (preview)
var temp := false  # conjured: fades at end of turn
var frozen := false
var hexed := false
var highlight := false
var dim := false


static func make(p_el: String, px := 40.0) -> ElementIcon:
	var i := ElementIcon.new()
	i.el = p_el
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0 - 2.0
	var c := size / 2.0
	var col: Color = Elements.COLORS.get(el, Color.GRAY)
	var a := 1.0
	if ghost:
		a = 0.28
	elif dim:
		a = 0.45
	if highlight:
		draw_circle(c, r + 3.0, Color(1, 1, 1, 0.9))
	draw_circle(c, r, Color(col.darkened(0.55), a))
	if el == "?":
		# any element: a swirl of all three colours
		_tri_blend(c, r, a)
	else:
		draw_circle(c, r * 0.86, Color(col.darkened(0.15), a))
	draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.12 * a))
	var g := Color(1, 1, 1, 0.92 * a)
	match el:
		"F":
			_flame(c, r * 0.62, g)
		"W":
			_drop(c, r * 0.6, g)
		"A":
			_swirl(c, r * 0.6, g)
		_:
			var f := get_theme_default_font()
			var fs := int(r * 1.35)
			draw_string_outline(f, c + Vector2(-fs * 0.28, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(r * 0.18)), Color(0, 0, 0, 0.55 * a))
			draw_string(f, c + Vector2(-fs * 0.28, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, g)
	if armored:
		draw_arc(c, r + 1.0, 0, TAU, 32, Color(0.85, 0.85, 0.9, a), 4.0)
		_mini_shield(c + Vector2(r * 0.62, -r * 0.62), r * 0.38, a)
	if temp:
		for i in 12:
			var t0 := i * TAU / 12.0
			draw_arc(c, r + 1.5, t0, t0 + TAU / 24.0, 4, Color(1, 1, 1, 0.9), 2.0)
	if frozen:
		draw_circle(c, r, Color(0.7, 0.9, 1.0, 0.55))
		for k in 3:
			var d := Vector2.from_angle(k * PI / 3.0) * r * 0.7
			draw_line(c - d, c + d, Color(1, 1, 1, 0.95), 2.0)
	if hexed:
		draw_arc(c, r + 1.0, 0, TAU, 32, Color(0.75, 0.3, 0.95), 3.0)
		draw_circle(c + Vector2(-r * 0.62, -r * 0.62), r * 0.22, Color(0.75, 0.3, 0.95))
	if ghost:
		var d := r * 0.55
		draw_line(c + Vector2(-d, -d), c + Vector2(d, d), Color(1, 0.35, 0.3, 0.9), 3.0)
		draw_line(c + Vector2(d, -d), c + Vector2(-d, d), Color(1, 0.35, 0.3, 0.9), 3.0)


## Three curved wedges, Fire / Water / Air, blending into each other around the orb.
func _tri_blend(c: Vector2, r: float, a: float) -> void:
	var cols := [Elements.COLORS["F"], Elements.COLORS["W"], Elements.COLORS["A"]]
	var rr := r * 0.86
	var steps := 48
	for i in steps:
		var t0 := i / float(steps)
		var t1 := (i + 1) / float(steps)
		# blend between neighbouring colours so the edges melt together
		var seg := t0 * 3.0
		var k := int(seg) % 3
		var col: Color = cols[k].lerp(cols[(k + 1) % 3], smoothstep(0.55, 1.0, seg - floorf(seg)))
		var a0 := t0 * TAU - PI / 2.0 + 0.35
		var a1 := t1 * TAU - PI / 2.0 + 0.35
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a0) * rr, c + Vector2.from_angle(a1) * rr])
		draw_colored_polygon(pts, Color(col.darkened(0.05), a))
	draw_circle(c, rr * 0.45, Color(1, 1, 1, 0.12 * a))


func _flame(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0 * TAU
		# teardrop pointing up with a flicker
		var rad := s * (0.62 + 0.38 * sin(t / 2.0))
		var p := Vector2(sin(t) * rad * 0.8, -cos(t) * rad)
		if i % 6 == 3:
			p *= 0.85
		pts.append(c + p + Vector2(0, s * 0.18))
	pts[0] = c + Vector2(0, -s * 1.05)
	pts[24] = pts[0]
	draw_colored_polygon(pts, col)
	draw_circle(c + Vector2(0, s * 0.35), s * 0.3, Color(1, 0.85, 0.4, col.a))


func _drop(c: Vector2, s: float, col: Color) -> void:
	var bc := c + Vector2(0, s * 0.3)
	var r := s * 0.62
	draw_circle(bc, r, col)
	var tri := PackedVector2Array([c + Vector2(0, -s * 1.1), bc + Vector2(r * 0.93, -r * 0.37), bc + Vector2(-r * 0.93, -r * 0.37)])
	draw_colored_polygon(tri, col)


func _swirl(c: Vector2, s: float, col: Color) -> void:
	for k in 3:
		var y := (k - 1) * s * 0.55
		var w := s * (1.0 - absf(k - 1) * 0.2)
		draw_line(c + Vector2(-w, y), c + Vector2(w * 0.5, y), col, 3.0)
		draw_arc(c + Vector2(w * 0.5, y - s * 0.18), s * 0.18, PI * 0.5, PI * 2.0, 10, col, 3.0)


func _mini_shield(p: Vector2, s: float, a: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-s, -s * 0.8), p + Vector2(s, -s * 0.8), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
	draw_colored_polygon(pts, Color(0.8, 0.82, 0.9, a))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.2, 0.2, 0.25, a), 1.5)
