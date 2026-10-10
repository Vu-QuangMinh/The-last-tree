extends VBoxContainer
## Short messages under the timer that fade out.

const LIFE := 5.0  # a toast stays 5 s; while the mouse is on it, it stays; after the mouse leaves it, 5 s more
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
	var strip := UiSkin.box("toast_strip", [57, 0, 61, 0] if UiSkin.is_circus() else [38, 0, 38, 0], [64, 6, 68, 9] if UiSkin.is_circus() else [40, 6, 30, 9])  # (Cirus: a ticket with bigger ends)
	p.add_theme_stylebox_override("panel", strip if strip != null else UiTheme.panel_box(0.85, 10))
	p.mouse_filter = MOUSE_FILTER_STOP
	p.mouse_entered.connect(func(): _hold(p))
	p.mouse_exited.connect(func(): _arm(p))
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
	_arm(p)


## (Re)start a toast's countdown: LIFE seconds, then it fades.
func _arm(p: Control) -> void:
	if not is_instance_valid(p):
		return
	_hold(p)
	var tw := p.create_tween()
	tw.tween_interval(LIFE)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	p.set_meta("life", tw)


## The mouse is on a toast: stop its countdown and show it fully.
func _hold(p: Control) -> void:
	if not is_instance_valid(p):
		return
	var old = p.get_meta("life", null)
	if old != null and old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	p.modulate.a = 1.0


func _process(_d: float) -> void:
	var area := get_parent_area_size()
	size.x = 700
	position = Vector2(area.x / 2.0 - 350, 170)
