class_name HedgeWall
extends Control
## One of the Bramble Matron's walls, drawn as a thorny hedge: leafy bushes with thorns and red berries. It shrinks
## as its Essence is cut (fill = how much of the wall still stands), and a cut-down wall is a stump of broken twigs.

var fill := 1.0  # 0..1
var flip := false  # the right wall is drawn mirrored
var _t := 0.0
var offset := Vector2.ZERO  # (its attack: it lunges by moving what it draws)
var squash := 1.0


static func make(p_fill: float, p_flip: bool, sz: Vector2) -> HedgeWall:
	var h := HedgeWall.new()
	h.fill = p_fill
	h.flip = p_flip
	h.custom_minimum_size = sz
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func _draw() -> void:
	draw_set_transform(offset + size / 2.0 * (1.0 - squash), 0.0, Vector2(squash, squash))
	var w := size.x
	var h := size.y
	var ground := h - 6.0
	var ink := Color(0.16, 0.1, 0.06)
	if fill <= 0.0:
		# cut down: a low stump of broken twigs
		draw_rect(Rect2(w * 0.3, ground - 14.0, w * 0.4, 14.0), Color(0.36, 0.24, 0.14))
		for k in 5:
			var x := w * (0.28 + 0.11 * k)
			var lean := (k - 2) * 0.25
			draw_line(Vector2(x, ground - 12.0), Vector2(x + lean * 18.0, ground - 26.0 - (k % 2) * 8.0), Color(0.3, 0.2, 0.1), 3.0, true)
		return
	var top := ground - (h - 12.0) * clampf(0.35 + 0.65 * fill, 0.0, 1.0)
	# the bushes: overlapping leafy clumps, darker at the back
	var clumps := [[0.22, 0.75, 0.30], [0.5, 0.62, 0.34], [0.78, 0.74, 0.29], [0.35, 0.38, 0.27], [0.66, 0.36, 0.27], [0.5, 0.16, 0.23]]
	for i in clumps.size():
		var cl: Array = clumps[i]
		var cx: float = w * (1.0 - cl[0] if flip else cl[0])
		var cy: float = lerpf(ground, top, 1.0 - cl[1]) + sin(_t * 1.6 + i) * 1.2  # a gentle sway
		var r: float = w * cl[2] * (0.75 + 0.25 * fill)
		var shade := Color(0.16, 0.36, 0.14).lerp(Color(0.32, 0.56, 0.22), float(i) / clumps.size())
		draw_circle(Vector2(cx, cy), r + 2.5, ink)
		draw_circle(Vector2(cx, cy), r, shade)
		draw_circle(Vector2(cx - r * 0.3, cy - r * 0.35), r * 0.35, Color(shade.lightened(0.25), 0.6))
	# thorns sticking out, and red berries
	for k in 9:
		var a := k * 2.4 + 0.5
		var base := Vector2(w * (0.18 + 0.64 * fmod(k * 0.37, 1.0)), lerpf(ground - 8.0, top + 10.0, fmod(k * 0.53, 1.0)))
		var dir := Vector2.from_angle(a)
		var side := Vector2(-dir.y, dir.x) * 3.0
		draw_colored_polygon(PackedVector2Array([base - side, base + dir * 10.0, base + side]), Color(0.42, 0.28, 0.14))
	for k in 5:
		var p := Vector2(w * (0.25 + 0.5 * fmod(k * 0.61, 1.0)), lerpf(ground - 12.0, top + 14.0, fmod(k * 0.29 + 0.1, 1.0)))
		draw_circle(p, 3.5, Color(0.25, 0.04, 0.05))
		draw_circle(p, 2.6, Color(0.85, 0.15, 0.18))
	# the roots it grows from
	draw_line(Vector2(w * 0.15, ground), Vector2(w * 0.85, ground), Color(0.3, 0.2, 0.1), 4.0, true)
