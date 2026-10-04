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
	var strip := UiSkin.box("toast_strip", [38, 0, 38, 0], [40, 6, 30, 9])
	p.add_theme_stylebox_override("panel", strip if strip != null else UiTheme.panel_box(0.85, 10))
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()  # the text, with each {icon:name|fallback} marker turned into a picture (or its fallback)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(row)
	var rest := text
	var pics := []
	var rx := RegEx.create_from_string("\\{icon:([^|}]*)\\|([^}]*)\\}")
	for m in rx.search_all(text):
		var art := UiSkin.icon(m.get_string(1), 26)
		if art != null:
			pics.append(art)
			rest = rest.replace(m.get_string(), "\u0001")
		else:
			rest = rest.replace(m.get_string(), m.get_string(2))
	var pieces := rest.split("\u0001")
	for i in pieces.size():
		var part := pieces[i].strip_edges()
		if part != "":
			var l := UiTheme.label(part, 18, color.darkened(0.55) if strip != null else color)  # dark text on the cream strip
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(l)
		if i < pics.size():
			row.add_child(pics[i])
	add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(LIFE)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _process(_d: float) -> void:
	var area := get_parent_area_size()
	size.x = 700
	position = Vector2(area.x / 2.0 - 350, 170)
