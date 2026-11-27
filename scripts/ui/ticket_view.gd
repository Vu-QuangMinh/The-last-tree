class_name TicketView
extends Control
## A ticket (see Tickets), drawn as a carnival ticket: notched corners and saw-tooth ends, a striped border, a sunburst
## inside, a cream plate in the middle with the ticket's picture. No words on it (the user, 2026-11-27): hovering it
## says what it does. A Rare ticket has a gold border. Painted art can replace the whole thing: UI art
## "ticket_<id>" when it exists. Click: `pressed`.

signal pressed(view: TicketView)

const RATIO := 2.1  # width / height

var id := ""
var slot := -1  # (in a ticket bar: which slot it stands in)
var selected := false
var dim := false


static func make(p_id: String, h := 60.0) -> TicketView:
	var v := TicketView.new()
	v.id = p_id
	v.custom_minimum_size = Vector2(h * RATIO, h)
	v.size = v.custom_minimum_size
	return v


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size / 2.0
	tooltip_text = Tickets.tooltip(id)
	mouse_entered.connect(func(): if not selected: create_tween().tween_property(self, "scale", Vector2.ONE * 1.06, 0.08))
	mouse_exited.connect(func(): if not selected: create_tween().tween_property(self, "scale", Vector2.ONE, 0.08))
	_build_symbol()


func _make_custom_tooltip(for_text: String) -> Object:
	return Keywords.make_tooltip(for_text) if for_text != "" else null


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func set_selected(on: bool) -> void:
	selected = on
	position.y += -8.0 if on else 8.0  # (a picked ticket lifts, as in Balatro)
	queue_redraw()


# ------------------------------------------------------------------ the picture

const EMOJI := {"heart": "❤", "shield": "🛡", "hourglass": "⌛", "tools": "🛠", "coins": "🪙", "masks": "🎭", "redo": "🔄",
	"scissors": "✂", "question": "❓", "star_up": "⭐"}


## The picture in the middle: an emoji, the marbles' own art, or a shape drawn here (halo, wax, %).
func _build_symbol() -> void:
	if UiSkin.tex("ticket_" + id) != null:
		return
	var sym := String(Tickets.get_def(id).get("sym", "question"))
	var h := size.y
	var plate := _plate_rect()
	var px := plate.size.y * 0.78
	match sym:
		"marble", "marbles", "twins", "chisel":
			var els: Array = {"marble": ["W"], "marbles": ["F", "A"], "twins": ["F", "F"], "chisel": ["A"]}[sym]
			var gap := px * 0.62
			var x0 := plate.get_center().x - gap * (els.size() - 1) / 2.0
			for k in els.size():
				var mv := MarbleView.make({"c": els[k], "sym": "star" if sym == "chisel" else ""}, px)
				mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mv.position = Vector2(x0 + k * gap - px / 2.0, plate.get_center().y - px / 2.0)
				add_child(mv)
			if sym == "twins" or sym == "chisel":
				var mark := UiTheme.label("+" if sym == "twins" else "✎", int(h * 0.3), Color(0.25, 0.15, 0.1))
				mark.position = Vector2(plate.end.x - h * 0.32, plate.position.y - h * 0.04)
				mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(mark)
		"halo", "wax", "percent":
			pass  # (drawn in _draw)
		_:
			var l := UiTheme.label(String(EMOJI.get(sym, "?")), int(px * 0.82), Color(0.75, 0.12, 0.12))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.position = plate.position
			l.size = plate.size
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(l)
			if sym == "star_up":
				var up := UiTheme.label("▲", int(h * 0.26), Color(0.2, 0.65, 0.25))
				up.position = Vector2(plate.end.x - h * 0.3, plate.position.y - h * 0.02)
				up.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(up)


func _plate_rect() -> Rect2:
	var h := size.y
	var b := h * 0.2
	return Rect2(Vector2(size.x * 0.3, b + h * 0.04), Vector2(size.x * 0.4, h - 2.0 * b - h * 0.08))


func _draw() -> void:
	var art := UiSkin.tex("ticket_" + id)
	if art != null:
		draw_texture_rect(art, Rect2(Vector2.ZERO, size), false, Color(0.55, 0.55, 0.55) if dim else Color.WHITE)
		return
	var w := size.x
	var h := size.y
	var rare := Tickets.is_rare(id)
	var rim := Color(0.96, 0.62, 0.2) if not rare else Color(0.95, 0.78, 0.25)
	var rim_dark := Color(0.85, 0.45, 0.12) if not rare else Color(0.75, 0.55, 0.1)
	var shade := Color(1, 1, 1) if not dim else Color(0.55, 0.55, 0.55)
	# the outline: corners bitten out (a quarter circle each), the two ends saw-toothed
	var outer := _ticket_shape(Rect2(Vector2.ZERO, size), h * 0.16, h * 0.07)
	draw_colored_polygon(outer, Color(0.35, 0.18, 0.08) * shade)
	var inner_shape := _ticket_shape(Rect2(Vector2(2, 2), size - Vector2(4, 4)), h * 0.14, h * 0.06)
	draw_colored_polygon(inner_shape, rim * shade)
	# the border's stripes
	var b := h * 0.17
	var step := h * 0.12
	var x := b * 0.6
	while x < w - b * 0.6:
		draw_line(Vector2(x, 4), Vector2(x, b), rim_dark * shade, step * 0.4)
		draw_line(Vector2(x, h - b), Vector2(x, h - 4), rim_dark * shade, step * 0.4)
		x += step
	# the sunburst inside the border
	var inner := Rect2(Vector2(b, b), Vector2(w - 2.0 * b, h - 2.0 * b))
	draw_rect(inner, Color(0.98, 0.86, 0.86) * shade)
	var c := inner.get_center()
	var rays := 16
	for k in rays:
		if k % 2 == 1:
			continue
		var a0 := TAU * k / rays
		var a1 := TAU * (k + 1) / rays
		draw_colored_polygon(_ray(c, a0, a1, inner), Color(0.96, 0.62, 0.66, 0.85) * shade)
	draw_rect(inner, Color(0.85, 0.15, 0.2) * shade, false, maxf(1.5, h * 0.025))
	# the cream plate in the middle, a thin red line round it
	var plate := _plate_rect()
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(1.0, 0.97, 0.9) * shade
	pb.border_color = Color(0.85, 0.15, 0.2) * shade
	pb.set_border_width_all(maxi(1, int(h * 0.025)))
	pb.set_corner_radius_all(int(h * 0.06))
	draw_style_box(pb, plate)
	# stars on the sunburst, either side of the plate (as on the printed tickets)
	for sx in [inner.position.x + inner.size.x * 0.13, inner.end.x - inner.size.x * 0.13]:
		_star(Vector2(sx, c.y), h * 0.09, Color(0.95, 0.55, 0.15) * shade)
	_draw_symbol(plate)
	if selected:
		draw_polyline(outer + PackedVector2Array([outer[0]]), Color(1.0, 0.95, 0.6), 3.0, true)


## The shapes this file draws itself (the rest are child nodes).
func _draw_symbol(plate: Rect2) -> void:
	if UiSkin.tex("ticket_" + id) != null:
		return
	var sym := String(Tickets.get_def(id).get("sym", ""))
	var c := plate.get_center()
	var r := plate.size.y * 0.36
	match sym:
		"halo":  # (Blessing: a golden halo, seen a little from the front)
			for k in 3:
				draw_arc(c + Vector2(0, r * 0.1), r * (1.0 - k * 0.04), 0.0, TAU, 40, Color(1.0, 0.8, 0.2, 0.35 if k else 1.0), r * (0.28 if k else 0.18), true)
			draw_set_transform(c, 0.0, Vector2(1.0, 0.38))
			draw_arc(Vector2.ZERO, r * 1.15, 0.0, TAU, 40, Color(0.95, 0.72, 0.1), r * 0.32, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"wax":  # (a purple wax seal: a wavy blob with a stamped ring)
			var pts := PackedVector2Array()
			for k in 28:
				var a := TAU * k / 28.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 + 0.1 * sin(a * 7.0)))
			draw_colored_polygon(pts, Color(0.5, 0.2, 0.6))
			draw_arc(c, r * 0.62, 0.0, TAU, 32, Color(0.7, 0.45, 0.8), r * 0.14, true)
			draw_circle(c - Vector2(r * 0.3, r * 0.35), r * 0.15, Color(1, 1, 1, 0.35))
		"percent":  # (Discount: a fat red %)
			var f: Font = UiTheme.cut("bold") if UiTheme.cut("bold") != null else ThemeDB.fallback_font
			var fs := int(plate.size.y * 0.9)
			draw_string(f, Vector2(plate.position.x, c.y + fs * 0.35), "%", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, fs, Color(0.8, 0.12, 0.15))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + TAU * k / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


## One ray of the sunburst: the wedge from c between two angles, cut to the rectangle.
func _ray(c: Vector2, a0: float, a1: float, rect: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array([c, _exit(c, a0, rect)])
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var a := fposmod((corner - c).angle(), TAU)
		if a > fposmod(a0, TAU) and a < fposmod(a1, TAU) and fposmod(a0, TAU) < fposmod(a1, TAU):
			pts.append(corner)
	pts.append(_exit(c, a1, rect))
	return pts


## Where a ray from c (inside the rectangle) at angle a leaves it.
static func _exit(c: Vector2, a: float, rect: Rect2) -> Vector2:
	var d := Vector2(cos(a), sin(a))
	var t := INF
	if d.x > 0.0001:
		t = minf(t, (rect.end.x - c.x) / d.x)
	elif d.x < -0.0001:
		t = minf(t, (rect.position.x - c.x) / d.x)
	if d.y > 0.0001:
		t = minf(t, (rect.end.y - c.y) / d.y)
	elif d.y < -0.0001:
		t = minf(t, (rect.position.y - c.y) / d.y)
	return c + d * t


## The ticket's outline in `r`: a quarter circle (radius `bite`) bitten out of each corner, and the two short ends cut
## into small teeth (depth `tooth`).
static func _ticket_shape(r: Rect2, bite: float, tooth: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	# top-left bite, then along the top
	for k in 7:
		var a := PI / 2.0 - PI / 2.0 * k / 6.0
		pts.append(Vector2(x0, y0) + Vector2(cos(a), sin(a)) * bite)
	for k in 7:
		var a := PI - PI / 2.0 * k / 6.0
		pts.append(Vector2(x1, y0) + Vector2(cos(a), sin(a)) * bite)
	# the right end: teeth down to the bottom-right bite
	var n := maxi(3, int((r.size.y - 2.0 * bite) / (tooth * 2.2)))
	for k in n * 2 + 1:
		var y := y0 + bite + (r.size.y - 2.0 * bite) * k / (n * 2.0)
		pts.append(Vector2(x1 - (tooth if k % 2 == 1 else 0.0), y))
	for k in 7:
		var a := -PI / 2.0 - PI / 2.0 * k / 6.0
		pts.append(Vector2(x1, y1) + Vector2(cos(a), sin(a)) * bite)
	for k in 7:
		var a := 0.0 - PI / 2.0 * k / 6.0
		pts.append(Vector2(x0, y1) + Vector2(cos(a), sin(a)) * bite)
	for k in n * 2 + 1:
		var y := y1 - bite - (r.size.y - 2.0 * bite) * k / (n * 2.0)
		pts.append(Vector2(x0 + (tooth if k % 2 == 1 else 0.0), y))
	var out := PackedVector2Array()  # (no point twice in a row: the bites and the teeth meet at the same spots)
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.01:
			out.append(p)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= 0.01:
		out.remove_at(out.size() - 1)
	return out
