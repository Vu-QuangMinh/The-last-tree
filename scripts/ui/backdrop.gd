class_name Backdrop
extends Control
## Painted background: dusk sky, layered forest silhouettes, the last tree glowing in the middle.
## act changes the mood (1 dusk green, 2 rot purple, 3 winter blue).

var act := 1
var tree_glow := true
var _t := 0.0

const SKY := {1: [Color(0.1, 0.16, 0.14), Color(0.28, 0.36, 0.26)], 2: [Color(0.12, 0.08, 0.14), Color(0.34, 0.22, 0.3)], 3: [Color(0.08, 0.1, 0.16), Color(0.4, 0.48, 0.58)]}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var sky: Array = SKY.get(act, SKY[1])
	for i in 24:
		var y0 := h * i / 24.0
		draw_rect(Rect2(0, y0, w, h / 24.0 + 1), sky[0].lerp(sky[1], i / 23.0 * 0.9))
	# far hills and three layers of trees
	for layer in 3:
		var base := h * (0.52 + layer * 0.08)
		var col: Color = sky[0].lerp(Color.BLACK, 0.2 + layer * 0.25)
		var pts := PackedVector2Array([Vector2(0, h)])
		var n := 40 + layer * 10
		for i in n + 1:
			var x := w * i / float(n)
			var spike := (sin(i * 12.9898 + layer * 4.1) * 43758.5453)
			spike = spike - floorf(spike)
			var y := base - (20 + spike * (60 + layer * 30)) * (1.0 if i % 2 == 0 else 0.35)
			pts.append(Vector2(x, y))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, col)
	# the last tree
	if tree_glow:
		var c := Vector2(w * 0.5, h * 0.62)
		draw_circle(c + Vector2(0, -h * 0.2), h * 0.22, Color(0.55, 0.9, 0.5, 0.05 + 0.02 * sin(_t)))
		draw_rect(Rect2(c.x - 18, c.y - h * 0.2, 36, h * 0.2), Color(0.12, 0.09, 0.07))
		for i in 7:
			var a := -PI / 2 + (i - 3) * 0.32
			var r := h * (0.16 + 0.03 * sin(i * 1.7))
			draw_circle(c + Vector2(0, -h * 0.24) + Vector2.from_angle(a) * r * 0.6, r * 0.55, Color(0.16, 0.3, 0.16, 0.95))
		for i in 12:
			var p := c + Vector2(sin(_t * 0.7 + i * 2.1) * h * 0.2, -h * 0.25 + cos(_t * 0.5 + i) * h * 0.12)
			draw_circle(p, 3, Color(0.75, 1, 0.6, 0.5 + 0.4 * sin(_t * 2 + i)))
	# ground
	draw_rect(Rect2(0, h * 0.8, w, h * 0.2), sky[0].lerp(Color.BLACK, 0.7))
