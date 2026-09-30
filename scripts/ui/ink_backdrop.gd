class_name InkBackdrop
extends Control
## The hand-inked background (pilot: fights): a bright sky with a warm sun and puffy clouds, three layers of
## saturated hills with thick wobbly ink outlines and pencil hatching, the glowing Last Tree, swaying grass,
## drifting sparkles and a light paper grain. act picks the colours (1 summer, 2 dusk, 3 frost).

var act := 1
var _t := 0.0
var _grain := PackedVector2Array()

const PAL := {
	1: {"sky": [Color(0.36, 0.78, 0.93), Color(1.0, 0.85, 0.55)], "sun": Color(1.0, 0.93, 0.55),
		"hills": [Color(0.55, 0.82, 0.72), Color(0.3, 0.7, 0.46), Color(0.2, 0.55, 0.36)], "ground": Color(0.46, 0.3, 0.18),
		"grass": Color(0.3, 0.68, 0.32), "leaf": [Color(0.45, 0.85, 0.4), Color(0.28, 0.66, 0.34)]},
	2: {"sky": [Color(0.5, 0.36, 0.78), Color(1.0, 0.62, 0.5)], "sun": Color(1.0, 0.7, 0.55),
		"hills": [Color(0.72, 0.5, 0.78), Color(0.52, 0.34, 0.66), Color(0.36, 0.22, 0.5)], "ground": Color(0.32, 0.2, 0.26),
		"grass": Color(0.5, 0.36, 0.6), "leaf": [Color(0.62, 0.8, 0.4), Color(0.42, 0.62, 0.32)]},
	3: {"sky": [Color(0.5, 0.72, 0.95), Color(0.9, 0.96, 1.0)], "sun": Color(1.0, 0.98, 0.85),
		"hills": [Color(0.78, 0.88, 0.97), Color(0.56, 0.72, 0.9), Color(0.4, 0.55, 0.78)], "ground": Color(0.5, 0.58, 0.7),
		"grass": Color(0.82, 0.9, 0.98), "leaf": [Color(0.5, 0.8, 0.6), Color(0.35, 0.62, 0.5)]},
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := RandomNumberGenerator.new()
	g.seed = 1234
	for i in 900:
		_grain.append(Vector2(g.randf() * 1920.0, g.randf() * 1080.0))


func _process(d: float) -> void:
	_t += d
	queue_redraw()


## A ridge line across the screen: seeded bumps, and a slight hand-drawn boil.
func _ridge(base: float, height: float, seed: int, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var w := size.x
	var b := Ink.boil()
	for i in n + 1:
		var x := w * i / float(n)
		var y := base - height * (0.5 + 0.5 * sin(i * 0.9 + seed) * 0.6 + 0.4 * sin(i * 0.37 + seed * 2.0))
		pts.append(Vector2(x, y + Ink.noise(i + b * 7, seed) * 1.6))
	return pts


func _hill(pts: PackedVector2Array, fill: Color, seed: int) -> void:
	var poly := pts.duplicate()
	poly.append(Vector2(size.x, size.y))
	poly.append(Vector2(0, size.y))
	draw_colored_polygon(poly, fill)
	# pencil shading: short strokes hanging under the ridge
	for i in range(1, pts.size() - 1):
		var p := pts[i]
		for k in 3:
			var q := p + Vector2(k * 9.0 - 9.0 + Ink.noise(i, k + seed) * 3.0, 12.0 + k * 4.0)
			draw_line(q, q + Vector2(-10, 16), Color(Ink.INK, 0.22), 1.6)
	draw_polyline(pts, Ink.INK, 4.0)


func _blob(c: Vector2, r: float, fill: Color, seed: int, outline := true) -> void:
	var pts := PackedVector2Array()
	var b := Ink.boil()
	var n := 40
	for i in n:
		var a := i * TAU / n
		pts.append(c + Vector2.from_angle(a) * r * (1.0 + 0.025 * Ink.noise(i, seed + b)))
	draw_colored_polygon(pts, fill)  # (a filled shape must not repeat its first point)
	if outline:
		pts.append(pts[0])
		draw_polyline(pts, Ink.INK, 3.5)


func _cloud(c: Vector2, s: float, seed: int) -> void:
	var parts := [[Vector2(-1.1, 0.25), 0.7], [Vector2(0, 0), 1.0], [Vector2(1.1, 0.2), 0.75], [Vector2(0.5, 0.45), 0.6], [Vector2(-0.5, 0.45), 0.6]]
	for p in parts:
		_blob(c + p[0] * s, p[1] * s + 4.0, Color.WHITE, seed, true)
	for p in parts:
		_blob(c + p[0] * s, p[1] * s, Color.WHITE, seed, false)  # hide inner outlines
	draw_line(c + Vector2(-s, s * 0.7), c + Vector2(s * 1.2, s * 0.7), Color(Ink.INK, 0.25), 2.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var pal: Dictionary = PAL.get(act, PAL[1])
	# sky
	for i in 30:
		var y0 := h * 0.7 * i / 30.0
		draw_rect(Rect2(0, y0, w, h * 0.7 / 30.0 + 1), pal.sky[0].lerp(pal.sky[1], i / 29.0))
	draw_rect(Rect2(0, h * 0.7, w, h * 0.3), pal.sky[1])
	# the sun, big and warm, with sketchy rays
	var sun := Vector2(w * 0.8, h * 0.2)
	for k in 12:
		var a := k * TAU / 12.0 + _t * 0.08
		draw_line(sun + Vector2.from_angle(a) * 100.0, sun + Vector2.from_angle(a) * (130.0 + 10.0 * sin(_t * 2.0 + k)), Color(pal.sun.darkened(0.2), 0.8), 4.0)
	_blob(sun, 80.0, pal.sun, 3)
	draw_arc(sun + Vector2(18, 18), 50.0, 0.2, 1.4, 12, Color(Ink.INK, 0.25), 3.0)
	# clouds drifting
	_cloud(Vector2(fposmod(w * 0.3 + _t * 12.0, w + 400.0) - 200.0, h * 0.1), 42.0, 5)
	_cloud(Vector2(fposmod(w * 0.62 + _t * 7.0, w + 400.0) - 200.0, h * 0.27), 32.0, 9)
	# far hills
	_hill(_ridge(h * 0.6, 120.0, 2, 14), pal.hills[0], 2)
	# the Last Tree on the middle hill: glowing, leaves in blobs
	var base := Vector2(w * 0.12, h * 0.6)
	draw_circle(base + Vector2(0, -h * 0.24), h * 0.2, Color(1.0, 0.95, 0.6, 0.2 + 0.05 * sin(_t * 1.5)))
	var trunk := PackedVector2Array([base + Vector2(-22, 0), base + Vector2(-12, -h * 0.2), base + Vector2(12, -h * 0.2), base + Vector2(22, 0)])
	draw_colored_polygon(trunk, Color(0.55, 0.34, 0.2))
	trunk.append(trunk[0])
	draw_polyline(trunk, Ink.INK, 4.0)
	for k in 4:
		var y := base.y - 25.0 - k * 38.0
		draw_line(Vector2(base.x - 8, y), Vector2(base.x + 6, y - 14), Color(Ink.INK, 0.4), 2.0)
	var crown := []
	for i in 7:
		var a := -PI / 2.0 + (i - 3) * 0.42
		crown.append([base + Vector2(0, -h * 0.24) + Vector2.from_angle(a) * 56.0 + Vector2(0, sin(_t * 1.2 + i) * 2.0), 56.0 + 10.0 * sin(i * 1.7)])
	for b in crown:
		_blob(b[0], b[1] + 4.0, Ink.INK, 20, false)  # the ink rim around the whole crown
	for i in crown.size():
		_blob(crown[i][0], crown[i][1], pal.leaf[i % 2], 30 + i, false)
	for i in crown.size():
		# a leafy scribble on each clump
		var q: Vector2 = crown[i][0]
		draw_arc(q + Vector2(8, 10), crown[i][1] * 0.5, 0.2, 1.6, 8, Color(Ink.INK, 0.3), 2.5)
	# middle and near hills
	_hill(_ridge(h * 0.72, 70.0, 5, 18), pal.hills[1], 5)
	_hill(_ridge(h * 0.82, 50.0, 8, 22), pal.hills[2], 8)
	# ground and swaying grass
	draw_rect(Rect2(0, h * 0.9, w, h * 0.1), pal.ground)
	draw_line(Vector2(0, h * 0.9), Vector2(w, h * 0.9), Ink.INK, 4.0)
	for i in 70:
		var x := w * i / 70.0 + Ink.noise(i, 1) * 8.0
		var sway := sin(_t * 2.0 + i * 0.6) * 6.0
		var root := Vector2(x, h * 0.9)
		draw_line(root, root + Vector2(sway - 4, -22), pal.grass, 3.0)
		draw_line(root + Vector2(4, 0), root + Vector2(sway + 6, -16), pal.grass.darkened(0.2), 3.0)
	# sparkles drifting up
	var cols := [Color(1, 0.95, 0.5), Color(1, 0.6, 0.8), Color(0.6, 0.95, 1.0)]
	for i in 26:
		var x := fposmod(Ink.noise(i, 4) * 900.0 + 960.0 + sin(_t * 0.6 + i) * 30.0, w)
		var y := fposmod(h * 0.9 - _t * (20.0 + (i % 5) * 8.0) - i * 60.0, h * 0.9)
		var tw := 0.5 + 0.5 * sin(_t * 3.0 + i)
		var c: Color = cols[i % 3]
		draw_circle(Vector2(x, y), 2.0 + 2.0 * tw, Color(c, 0.4 + 0.5 * tw))
		draw_line(Vector2(x - 6 * tw, y), Vector2(x + 6 * tw, y), Color(c, 0.6 * tw), 1.5)
		draw_line(Vector2(x, y - 6 * tw), Vector2(x, y + 6 * tw), Color(c, 0.6 * tw), 1.5)
	# paper grain
	for p in _grain:
		draw_rect(Rect2(p, Vector2(2, 2)), Color(Ink.INK, 0.05))
