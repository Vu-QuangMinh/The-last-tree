class_name CardBadge
extends Control
## A small badge in a top corner of a spell card: a symbol with a number in it. Ignite: a flame at the top right (the
## number is what casting the spell burns you for). Virus: a green poison drop at the top left (the Poison casting it
## gives you). It sits in the card's content box and reaches out onto the frame, like the OrbitSpark.

var kind := "ignite"  # "ignite" (top right) or "virus" (top left)
var number := 0
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
	if number <= 0:
		return
	var frame := Rect2(Vector2(-margins[0], -margins[1]), size + Vector2(margins[0] + margins[2], margins[1] + margins[3]))
	var r := 24.0 * zoom
	var c := frame.position + Vector2(r * 0.55, r * 0.6) if kind == "virus" else frame.position + Vector2(frame.size.x - r * 0.55, r * 0.6)
	var pulse := 1.0 + 0.05 * sin(_t * (7.0 if kind == "ignite" else 4.0))
	var col := Color(1.0, 0.45, 0.1) if kind == "ignite" else Color(0.4, 0.85, 0.2)
	draw_circle(c, r * 1.25 * pulse, Color(col, 0.25))  # (a soft glow behind it)
	if not UiSkin.draw_fit(self, "status_burn" if kind == "ignite" else "status_poison", c, r * 2.2 * pulse):
		# (no art: a drawn flame or drop)
		var pts := PackedVector2Array()
		for k in 24:
			var a := k * TAU / 24.0
			var rr := r * (1.0 + (0.55 if kind == "ignite" else 0.4) * maxf(0.0, -sin(a)) * (1.0 - absf(cos(a))))
			pts.append(c + Vector2(cos(a) * r * 0.85, sin(a) * rr))
		draw_colored_polygon(pts, col)
	# the number in the middle, white with a dark outline
	var font := ThemeDB.fallback_font
	var px := int(24.0 * zoom)
	var txt := str(number)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := c + Vector2(-w / 2.0, px * 0.36)
	draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(6.0 * zoom), Color(0.12, 0.04, 0.0) if kind == "ignite" else Color(0.03, 0.12, 0.02))
	draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
