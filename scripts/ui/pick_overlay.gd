class_name PickOverlay
extends Control
## Choose `pick_n` of the things shown (marbles, spells, carvings: any Controls), over a dimmed screen: a title, a line
## of words, the things in rows, and Back. Clicking one picks it (with pick_n > 1 it lights up until enough are
## picked). `picked` gives their indices; Back, Esc or a right-click give []. Use:
##   var got: Array = await PickOverlay.ask(parent, "Title", "words", views, 1)

signal picked(indices: Array)

var title := ""
var words := ""
var views: Array = []
var pick_n := 1
var can_back := true
var _chosen: Array = []
var _cells: Array = []
var _done := false


static func ask(parent: Node, p_title: String, p_words: String, p_views: Array, n := 1, back := true) -> Array:
	var o := PickOverlay.new()
	o.title = p_title
	o.words = p_words
	o.views = p_views
	o.pick_n = n
	o.can_back = back
	parent.add_child(o)
	return await o.picked


## A marble to choose (its colour and carving written under it).
static func marble_view(m: Dictionary, px := 96.0) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mv := MarbleView.make(m, px)
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(mv)
	col.add_child(cc)
	var sym := String(m.get("sym", ""))
	var w: String = "Any colour" if sym == "star" else String({"F": "Fire", "W": "Water", "A": "Wind"}.get(String(m.get("c", "")), ""))
	if sym != "" and sym != "star":
		w += "\n" + String(MarbleView.SYM_WORDS.get(sym, sym))
	var l := UiTheme.label(w, 17, Color(0.95, 0.9, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(maxf(px, 170.0), 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(l)
	return col


## A spell (its card, as the main game draws it).
static func spell_view(sp: Dictionary, k := 0.85) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H) * k
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := SpellCard.make(sp)
	card.size = Vector2(SpellCard.W, SpellCard.H)
	card.scale = Vector2(k, k)
	card.hover_off = true
	holder.add_child(card)
	SpellCard._ignore_mouse.call_deferred(card)
	return holder


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.size = size
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var t := UiTheme.heading(title, 44, Color(1, 0.9, 0.55))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if words != "":
		var w := UiTheme.label(words, 23, Color(0.95, 0.9, 0.8))
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size = Vector2(1300, 0)
		w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(w)
	var grid := GridContainer.new()
	grid.columns = clampi(views.size(), 1, 8 if views.size() > 5 else 5)
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for i in views.size():
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", _cell_box(false))
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cell.add_child(views[i])
		Wiggle.attach(views[i], cell)  # (alive: it sways; under the mouse it wiggles more and glows; 2026-11-27)
		var ii := i
		cell.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_click(ii))
		cell.mouse_entered.connect(func(): if not (ii in _chosen): cell.add_theme_stylebox_override("panel", _cell_box(false, true)))
		cell.mouse_exited.connect(func(): if not (ii in _chosen): cell.add_theme_stylebox_override("panel", _cell_box(false)))
		grid.add_child(cell)
		_cells.append(cell)
	if pick_n > 1:
		var n := UiTheme.label("Choose %d." % pick_n, 20, Color(0.85, 0.8, 0.7))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(n)
	if can_back:
		var back := UiTheme.button("Back", func(): _finish([]), 22)
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(back)


static func _cell_box(on: bool, hover := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08 if hover or on else 0.0)
	sb.border_color = Color(1.0, 0.85, 0.35) if on else Color(1, 1, 1, 0.25 if hover else 0.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	return sb


func _click(i: int) -> void:
	if _done:
		return
	Audio.play("ui_click", -6.0)
	if not (i in _chosen):
		Juice.pop(get_tree(), Juice.center(_cells[i]), Color(1.0, 0.88, 0.5))
	if i in _chosen:
		_chosen.erase(i)
	else:
		_chosen.append(i)
	_cells[i].add_theme_stylebox_override("panel", _cell_box(i in _chosen))
	if _chosen.size() >= pick_n:
		_finish(_chosen.duplicate())


func _unhandled_input(ev: InputEvent) -> void:
	if not can_back or _done:
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT) or ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish([])


func _finish(got: Array) -> void:
	if _done:
		return
	_done = true
	picked.emit(got)
	queue_free()
