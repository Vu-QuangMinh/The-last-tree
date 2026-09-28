extends VBoxContainer
## Short messages under the timer that fade out.

const LIFE := 3.0
const MAX := 4


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 6)
	Events.toast.connect(show_toast)


func show_toast(text: String, color: Color) -> void:
	if color == UiTheme.DANGER:
		Audio.play("ui_error")
	if get_child_count() >= MAX:
		get_child(0).queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.85, 10))
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var l := UiTheme.label(text, 18, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(LIFE)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _process(_d: float) -> void:
	var area := get_parent_area_size()
	size.x = 700
	position = Vector2(area.x / 2.0 - 350, 170)
