class_name Ink
extends RefCounted
## The hand-inked look (pilot: the fight screen): thick, slightly wobbly dark outlines that "boil" a few times a
## second like hand-drawn animation, pencil hatching for shade, hard offset shadows, bright saturated fills.

const INK := Color(0.1, 0.08, 0.14)  # the outline colour: a warm near-black
const BOIL_FPS := 6.0  # how often a drawn line wiggles to a new shape


## Changes a few times a second: pass it to the wobble so outlines boil instead of crawling smoothly.
static func boil() -> int:
	return int(Time.get_ticks_msec() / 1000.0 * BOIL_FPS)


## A cheap, repeatable noise in -1..1.
static func noise(a: float, b: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return (v - floorf(v)) * 2.0 - 1.0


## The outline of a rounded rectangle, every point nudged a little: it looks drawn by hand.
static func wobbly_rect(r: Rect2, radius: float, seed: int, amp := 1.6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(radius, radius), Vector2(r.end.x - radius, r.position.y + radius),
		r.end - Vector2(radius, radius), Vector2(r.position.x + radius, r.end.y - radius)]
	var start := [PI, -PI / 2.0, 0.0, PI / 2.0]
	var k := 0
	for c in 4:
		for s in 7:
			var a: float = start[c] + s * (PI / 2.0) / 6.0
			var p: Vector2 = corners[c] + Vector2.from_angle(a) * radius
			pts.append(p + Vector2(noise(k, seed), noise(seed, k)) * amp)
			k += 1
		# a couple of points along each straight side so the edge isn't ruler-straight
		var next_c: Vector2 = corners[(c + 1) % 4] + Vector2.from_angle(start[(c + 1) % 4]) * radius
		var this_end: Vector2 = pts[pts.size() - 1]
		for s in 3:
			var q := this_end.lerp(next_c, (s + 1) / 4.0)
			pts.append(q + Vector2(noise(k, seed + 3), noise(seed + 3, k)) * amp)
			k += 1
	pts.append(pts[0])
	return pts


## A sticker-like panel: hard offset shadow, bright fill, a light inner edge, a thick wobbly ink outline and a
## patch of pencil hatching in the lower-right corner.
static func panel(ci: CanvasItem, r: Rect2, fill: Color, seed: int, radius := 14.0, ink_w := 4.0) -> void:
	var b := boil()
	var shadow := wobbly_rect(r.grow(1.0), radius, seed + b)
	var sh := PackedVector2Array()
	for p in shadow:
		sh.append(p + Vector2(6, 7))
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
	var outline := wobbly_rect(r, radius, seed + b)
	ci.draw_colored_polygon(outline, fill)
	# a lighter band along the top: light from above
	var top := Rect2(r.position + Vector2(radius * 0.6, 5), Vector2(r.size.x - radius * 1.2, 3))
	ci.draw_rect(top, Color(1, 1, 1, 0.14))
	hatch(ci, Rect2(r.end - Vector2(minf(90.0, r.size.x * 0.35), minf(34.0, r.size.y * 0.45)), Vector2(minf(90.0, r.size.x * 0.35), minf(34.0, r.size.y * 0.45))).grow(-6.0), Color(INK, 0.28), 7.0, seed)
	ci.draw_polyline(outline, INK, ink_w)


## Pencil hatching: short diagonal strokes filling a rectangle, each a little uneven.
static func hatch(ci: CanvasItem, r: Rect2, col: Color, spacing := 7.0, seed := 0) -> void:
	var n := int((r.size.x + r.size.y) / spacing)
	for i in n:
		var d := i * spacing
		var a := r.position + Vector2(d, 0)
		var z := r.position + Vector2(d - r.size.y, r.size.y)
		# clip the diagonal to the rectangle
		if a.x > r.end.x:
			a = Vector2(r.end.x, r.position.y + (a.x - r.end.x))
		if z.x < r.position.x:
			z = Vector2(r.position.x, r.end.y - (r.position.x - z.x))
		if a.y > r.end.y or z.y < r.position.y:
			continue
		var j := noise(i, seed) * 1.5
		ci.draw_line(a + Vector2(j, 0), z + Vector2(0, j), col, 1.6)


## Turn a PanelContainer into an inked panel (its children sit inside the margins).
static func style_panel(p: PanelContainer, fill: Color, seed: int, radius := 14.0, margin := 14.0) -> void:
	var e := StyleBoxEmpty.new()
	e.content_margin_left = margin
	e.content_margin_right = margin
	e.content_margin_top = margin - 4.0
	e.content_margin_bottom = margin
	p.add_theme_stylebox_override("panel", e)
	p.draw.connect(func(): panel(p, Rect2(Vector2.ZERO, p.size), fill, seed, radius))
	var tick := Ticker.new()
	tick.target = p
	p.add_child(tick)


## A bright sticker-style button: saturated fill, ink outline, hard shadow; lighter when hovered, pushed down
## when pressed. Its background is drawn by a node behind it, so the label stays on top.
static func button(b: Button, fill: Color, seed := 0) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 18
		e.content_margin_right = 18
		e.content_margin_top = 6
		e.content_margin_bottom = 12
		b.add_theme_stylebox_override(state, e)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 0.9))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 6)
	var back := ButtonBack.new()
	back.button = b
	back.fill = fill
	back.seed = seed
	b.add_child(back)


## Redraws its target whenever the ink boils (a few times a second).
class Ticker extends Control:
	var target: CanvasItem
	var _last := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		var b := Ink.boil()
		if b != _last and is_instance_valid(target):
			_last = b
			target.queue_redraw()


## The painted body of an inked button, drawn behind the button's own label.
class ButtonBack extends Control:
	var button: Button
	var fill := Color.WHITE
	var seed := 0

	func _ready() -> void:
		show_behind_parent = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f := fill
		if button.disabled:
			f = fill.lerp(Color(0.32, 0.32, 0.38), 0.7)
		elif button.is_hovered():
			f = fill.lightened(0.18)
		var down := button.button_pressed or (button.is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		var off := Vector2(0, 4) if down else Vector2.ZERO
		var r := Rect2(off + Vector2(2, 2), size - Vector2(4, 10))
		var outline := Ink.wobbly_rect(r, 12.0, seed + Ink.boil(), 1.2)
		if not down:
			var sh := PackedVector2Array()
			for p in outline:
				sh.append(p + Vector2(0, 6))
			draw_colored_polygon(sh, fill.darkened(0.55) if not button.disabled else Color(0.15, 0.15, 0.18))
		draw_colored_polygon(outline, f)
		draw_rect(Rect2(r.position + Vector2(12, 5), Vector2(maxf(0.0, r.size.x - 24), 4)), Color(1, 1, 1, 0.28))
		draw_polyline(outline, Ink.INK, 3.5)
