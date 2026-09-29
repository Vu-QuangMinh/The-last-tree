class_name OrbitSpark
extends Control
## A bright yellow spark running round a spell card's frame, with a short glowing trail: the chant you are
## building will wake this spell. It sits in the card's content box and draws out onto the frame.

var margins := [6.0, 7.0, 6.0, 5.0]  # the card's content margins (left, top, right, bottom): where the frame is
var zoom := 1.0
var loop_time := 2.2  # seconds for one full lap
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(d: float) -> void:
	if is_visible_in_tree():
		_t += d
		queue_redraw()


## A point on the frame, u from 0 to 1 once round (clockwise from the top-left corner).
func _on_frame(u: float, r: Rect2) -> Vector2:
	var w := r.size.x
	var h := r.size.y
	var d := fposmod(u, 1.0) * 2.0 * (w + h)
	if d < w:
		return r.position + Vector2(d, 0)
	d -= w
	if d < h:
		return r.position + Vector2(w, d)
	d -= h
	if d < w:
		return r.position + Vector2(w - d, h)
	d -= w
	return r.position + Vector2(0, h - d)


func _draw() -> void:
	var frame := Rect2(Vector2(-margins[0], -margins[1]), size + Vector2(margins[0] + margins[2], margins[1] + margins[3])).grow(-1.5 * zoom)
	var u := _t / loop_time
	var trail := 16
	for k in range(trail, 0, -1):
		var p := _on_frame(u - k * 0.006, frame)
		var a := 1.0 - float(k) / trail
		draw_circle(p, (2.0 + 4.0 * a) * zoom, Color(1.0, 0.9, 0.3, 0.75 * a))
	var head := _on_frame(u, frame)
	draw_circle(head, 16.0 * zoom, Color(1.0, 0.88, 0.25, 0.22))
	draw_circle(head, 9.0 * zoom, Color(1.0, 0.92, 0.35, 0.8))
	draw_circle(head, 4.5 * zoom, Color(1, 1, 0.9, 1.0))
