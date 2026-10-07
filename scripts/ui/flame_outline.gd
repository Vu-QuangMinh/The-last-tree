class_name FlameOutline
extends Control
## A thin line of flame running all the way round a spell card's frame, flickering: the spell is Ignited (casting
## it burns you). It sits in the card's content box and draws out onto the frame, like the OrbitSpark.

var margins := [6.0, 7.0, 6.0, 5.0]  # the card's content margins (left, top, right, bottom): where the frame is
var zoom := 1.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(d: float) -> void:
	if is_visible_in_tree():
		_t += d
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(-margins[0], -margins[1]), size + Vector2(margins[0] + margins[2], margins[1] + margins[3])).grow(-1.5 * zoom)
	# the glowing line itself
	draw_rect(r.grow(1.0 * zoom), Color(1.0, 0.35, 0.05, 0.35), false, 5.0 * zoom)
	draw_rect(r, Color(1.0, 0.65, 0.2, 0.95), false, 2.0 * zoom)
	# little tongues of flame licking outwards all the way round, each flickering on its own
	var step := 11.0 * zoom
	var per := 2.0 * (r.size.x + r.size.y)
	var n := int(per / step)
	for k in n:
		var d := k * step
		var p: Vector2
		var out: Vector2
		if d < r.size.x:
			p = r.position + Vector2(d, 0)
			out = Vector2.UP
		elif d < r.size.x + r.size.y:
			p = r.position + Vector2(r.size.x, d - r.size.x)
			out = Vector2.RIGHT
		elif d < 2.0 * r.size.x + r.size.y:
			p = r.position + Vector2(r.size.x - (d - r.size.x - r.size.y), r.size.y)
			out = Vector2.DOWN
		else:
			p = r.position + Vector2(0, r.size.y - (d - 2.0 * r.size.x - r.size.y))
			out = Vector2.LEFT
		var flick := 0.5 + 0.5 * sin(_t * 9.0 + k * 1.7) * sin(_t * 5.3 + k * 0.9)
		var h := (4.0 + 7.0 * flick) * zoom
		var side := Vector2(-out.y, out.x) * 3.0 * zoom
		var tip := p + out * h + side * 0.4 * sin(_t * 7.0 + k)
		draw_colored_polygon(PackedVector2Array([p - side, tip, p + side]), Color(1.0, 0.45 + 0.3 * flick, 0.1, 0.85))
		draw_colored_polygon(PackedVector2Array([p - side * 0.45, p + out * h * 0.55, p + side * 0.45]), Color(1.0, 0.9, 0.5, 0.9))
