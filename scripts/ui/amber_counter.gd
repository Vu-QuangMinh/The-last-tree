class_name AmberCounter
extends PanelContainer
## Your Amber, always in the top-right corner during a run: a little amber gem and the amount. When it changes,
## the counter pops and the difference floats up (+30 / -40).

var get_run: Callable  # () -> RunState, or null when no run is going on
var _shown := -1
var _label: Label
var _gem: Control
var _t := 0.0


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.04, 0.9)
	sb.border_color = Color(0.95, 0.62, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 10
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	var pill := UiSkin.box("amber_counter_pill", [22, 20, 22, 20], [18, 4, 24, 6])
	add_theme_stylebox_override("panel", pill if pill != null else sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = Keywords.tooltip("Amber", "Your money for this run. Spend it at the merchant and in events; fights give more.")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_gem = Control.new()
	_gem.custom_minimum_size = Vector2(27, 29) if UiSkin.tex("icon_amber") != null else Vector2(34, 36)
	_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem.draw.connect(_draw_gem)
	h.add_child(_gem)
	_label = UiTheme.label("0", 26, Color(1.0, 0.86, 0.5))
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_label)


## An amber drop: warm orange with a darker rim, a bright highlight and a tiny trapped leaf.
func _draw_gem() -> void:
	if UiSkin.draw_fit(_gem, "icon_amber", _gem.size / 2.0, 27.0):  # New theme: 80% of the old 34 px
		return
	var c := _gem.size / 2.0 + Vector2(0, 1)
	var r := 14.0
	var pts := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24.0
		var rr := r * (1.0 + 0.18 * maxf(0.0, -sin(a)))  # a little pointed at the top
		pts.append(c + Vector2(cos(a) * r * 0.9, sin(a) * rr))
	_gem.draw_colored_polygon(pts, Color(0.62, 0.3, 0.02))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.8)
	_gem.draw_colored_polygon(inner, Color(1.0, 0.6, 0.12))
	_gem.draw_circle(c + Vector2(-4, -5), 4.0, Color(1, 0.95, 0.75, 0.85))
	var shine := 0.35 + 0.25 * sin(_t * 2.0)
	_gem.draw_circle(c + Vector2(3, 4), 5.5, Color(1.0, 0.85, 0.4, shine))
	_gem.draw_line(c + Vector2(-2, 6), c + Vector2(4, 1), Color(0.35, 0.2, 0.05, 0.7), 1.5)


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null
	return Keywords.make_tooltip(for_text)


func _process(d: float) -> void:
	_t += d
	position.x = 1920.0 - 24.0 - size.x  # keep the right edge in place as the number grows
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
	var f := UiTheme.label(("+%d" if diff > 0 else "%d") % diff, 24, Color(1.0, 0.85, 0.35) if diff > 0 else Color(1.0, 0.5, 0.45))
	f.add_theme_constant_override("outline_size", 6)
	f.add_theme_color_override("font_outline_color", Color.BLACK)
	f.position = position + Vector2(size.x - 64, size.y + 4)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(f)  # not inside the panel, which would squeeze it in
	var ft := f.create_tween().set_parallel(true)
	ft.tween_property(f, "position:y", f.position.y + 26, 0.9)
	ft.tween_property(f, "modulate:a", 0.0, 0.9).set_delay(0.3)
	ft.chain().tween_callback(f.queue_free)
