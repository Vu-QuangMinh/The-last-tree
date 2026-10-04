class_name AmberCounter
extends PanelContainer
## Your Leaves (the run's money), always in the top-right corner during a run: a little leaf and the amount. When it changes,
## the counter pops and the difference floats up (+30 / -40).

var get_run: Callable  # () -> RunState, or null when no run is going on
var _shown := -1
var _label: Label
var _gem: Control
var _t := 0.0


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.04, 0.9)
	sb.border_color = Color(0.45, 0.8, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 10
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	var pill := UiSkin.box("amber_counter_pill", [22, 20, 22, 20], [18, 4, 24, 6])
	add_theme_stylebox_override("panel", pill if pill != null else sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = Keywords.tooltip("Leaves", "Your money for this run. Spend it at the merchant and in events; fights give more.")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	var coin := UiSkin.icon("icon_amber", 38)  # New theme: the painted amber leaf instead of the one drawn in code
	if coin != null:
		_gem = coin
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		_gem = Control.new()
		_gem.custom_minimum_size = Vector2(34, 36)
		_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gem.draw.connect(_draw_gem)
	h.add_child(_gem)
	_label = UiTheme.label("0", 26, Color(0.75, 1.0, 0.6))
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.04))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_label)


## A leaf (the run's money): a green blade with a lighter midrib and veins, a little stem, and a soft shine.
func _draw_gem() -> void:
	var c := _gem.size / 2.0 + Vector2(1, 1)
	var len := 15.0
	var w := 8.5
	var ang := -0.65  # tilted, tip up and to the right
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal()
	var pts := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0 * 2.0 - 1.0  # -1 (base) .. 1 (tip) along the top edge
		pts.append(c + dir * t * len + side * sqrt(maxf(0.0, 1.0 - t * t)) * w)
	for i in range(19, 0, -1):
		var t := float(i) / 20.0 * 2.0 - 1.0
		pts.append(c + dir * t * len - side * sqrt(maxf(0.0, 1.0 - t * t)) * w)
	_gem.draw_colored_polygon(pts, Color(0.2, 0.55, 0.18))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.82)
	_gem.draw_colored_polygon(inner, Color(0.42, 0.8, 0.3))
	# midrib, veins and stem
	var rib := Color(0.8, 1.0, 0.65, 0.9)
	_gem.draw_line(c - dir * len * 1.25, c + dir * len * 0.85, rib, 1.6, true)
	for k in [-0.45, 0.0, 0.45]:
		var at: Vector2 = c + dir * len * k
		_gem.draw_line(at, at + (dir + side).normalized() * w * 0.75, Color(rib, 0.6), 1.0, true)
		_gem.draw_line(at, at + (dir - side).normalized() * w * 0.75, Color(rib, 0.6), 1.0, true)
	var shine := 0.25 + 0.2 * sin(_t * 2.0)
	_gem.draw_circle(c + side * w * 0.35 - dir * len * 0.2, 3.0, Color(1, 1, 0.9, shine))


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null
	return Keywords.make_tooltip(for_text)


func _process(d: float) -> void:
	_t += d
	position.x = 1920.0 - 24.0 - size.x  # keep the right edge in place as the number grows
	if not _gem is TextureRect:
		_gem.queue_redraw()
	var run: RunState = get_run.call() if get_run.is_valid() else null
	visible = run != null
	if run == null:
		_shown = -1
		return
	if run.amber == _shown:
		return
	if _shown >= 0:
		_changed(run.amber - _shown)
	_shown = run.amber
	_label.text = str(_shown)


func _changed(diff: int) -> void:
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)
	var f := UiTheme.label(("+%d" if diff > 0 else "%d") % diff, 24, Color(0.7, 1.0, 0.5) if diff > 0 else Color(1.0, 0.5, 0.45))
	f.add_theme_constant_override("outline_size", 6)
	f.add_theme_color_override("font_outline_color", Color.BLACK)
	f.position = position + Vector2(size.x - 64, size.y + 4)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(f)  # not inside the panel, which would squeeze it in
	var ft := f.create_tween().set_parallel(true)
	ft.tween_property(f, "position:y", f.position.y + 26, 0.9)
	ft.tween_property(f, "modulate:a", 0.0, 0.9).set_delay(0.3)
	ft.chain().tween_callback(f.queue_free)
