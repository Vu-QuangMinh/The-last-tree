class_name TicketOffer
extends Control
## A ticket you found (after a fight, from an event; see TicketFlow.offer): the ticket, big, on a dimmed screen, what it
## does under it, and Take it / Leave it. With your slots full, Take it is greyed out and the words say so: use a ticket
## or throw one away from the ticket bar (top left, it stays clickable over this), and Take it lights up (Balatro).

signal closed

var id := ""
var run: RunState
var _take: Button
var _note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.size = size
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var d := Tickets.get_def(id)
	var t := UiTheme.heading(String(d.get("name", "A ticket")), 46, Color(0.55, 0.9, 0.55) if Tickets.is_rare(id) else Color(1, 0.9, 0.55))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := TicketView.make(id, 150.0)
	tv.mouse_filter = Control.MOUSE_FILTER_PASS  # (only for the hover: it wiggles more and glows)
	cc.add_child(tv)
	Wiggle.attach(tv)
	box.add_child(cc)
	var w := UiTheme.label(String(d.get("desc", "")) + ("\n" + String(Tickets.USE_WORDS.get(String(d.get("use", "")), "")) if Tickets.USE_WORDS.has(String(d.get("use", ""))) and not String(d.get("desc", "")).begins_with("Only") else ""), 24, Color(0.95, 0.9, 0.8))  # (words that already say where, "Only in a fight: ...": no second line)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.custom_minimum_size = Vector2(1000, 0)
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(w)
	_note = UiTheme.label("", 21, Color(1.0, 0.75, 0.4))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_note)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	_take = UiTheme.button("Take it", _take_it, 24)
	_take.custom_minimum_size = Vector2(220, 56)
	row.add_child(_take)
	var leave := UiTheme.button("Leave it", func():
		Audio.play("ui_click", -6.0)
		_close(), 22)
	leave.custom_minimum_size = Vector2(200, 56)
	row.add_child(leave)
	tv.scale = Vector2(0.3, 0.3)
	tv.create_tween().tween_property(tv, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_process(0.0)


func _process(_dt: float) -> void:
	var room := run.ticket_room()
	_take.disabled = not room
	_note.text = "" if room else "Your ticket slots are full: use a ticket or throw one away (top left) to make room."


func _take_it() -> void:
	if not run.gain_ticket(id):
		return
	Audio.play("elem_pickup")
	Juice.pop(get_tree(), Vector2(960, 430), Color(1.0, 0.75, 0.4), "", true)
	_close()


func _close() -> void:
	closed.emit()
	queue_free()
