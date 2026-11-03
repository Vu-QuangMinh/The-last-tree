class_name TextInspector
extends CanvasLayer
## F7: the text inspector. The game stops (the tree is paused) and nothing under it can be clicked; only the words can: click any text and a window you can drag
## shows its font, size, gap between the letters and colour, and lets you change them (the screen shows the change at once). Save keeps the changes, Cancel puts back everything
## as it was. A text made by UiTheme (label / heading / button) belongs to a style group (Settings > Font Edit): its change is the group's, so every text of that group changes
## with it and Save keeps it for the game. Any other text can only be changed for the screen that is on.

const WINDOW_W := 360.0

static var _open: TextInspector

var _was_paused := false
var _snapshot := {}  # the settings as they were: {"header_styles", "font"}
var _catcher: Control
var _win: PanelContainer
var _fields: VBoxContainer
var _hover: Control
var _sel: Control
var _drag := false
var _group_label: Label
var _text_label: Label
var _font_opt: OptionButton
var _size_spin: SpinBox
var _gap_spin: SpinBox
var _color_btn: ColorPickerButton
var _note: Label
var _building := false
var _banner: Label
var _edit: TextEdit
var _pos_label: Label
var _arrows: HBoxContainer
var _moving := false
var _isolate: CheckBox  # ticked: only the selected text changes; not ticked: every text of its group


## F7: open the inspector (or, when it is open, cancel it).
static func toggle(host: Node) -> void:
	if is_instance_valid(_open):
		_open.cancel()
		return
	_open = TextInspector.new()
	host.get_tree().root.add_child(_open)


func _ready() -> void:
	layer = 120  # (under the wooden pointer, which is on layer 128)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("hg_skip", true)  # (UiTheme.reapply_all leaves the inspector's own words alone)
	_was_paused = get_tree().paused
	get_tree().paused = true
	var hs = SaveManager.setting("header_styles", {})
	var tsx = SaveManager.setting("text_styles", {})
	_snapshot = {"header_styles": (hs as Dictionary).duplicate(true) if hs is Dictionary else {}, "text_styles": (tsx as Dictionary).duplicate(true) if tsx is Dictionary else {}, "text_edits": (SaveManager.setting("text_edits", {}) as Dictionary).duplicate(true), "font": UiTheme.font_choice()}
	_catcher = _Catcher.new()
	_catcher.inspector = self
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_catcher)
	var banner := UiTheme.label("Text inspector: the game is paused. Click any text.   F7 / Esc = close", 20, Color(1, 0.92, 0.6))
	_banner = banner
	banner.set_meta("hg_skip", true)
	banner.position = Vector2(0, 8)
	banner.size = Vector2(1920, 30)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 6)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	_build_window()


func _exit_tree() -> void:
	if _open == self:
		_open = null


func _build_window() -> void:
	_win = PanelContainer.new()
	_win.theme = UiTheme.get_theme()
	_win.add_theme_stylebox_override("panel", UiTheme.panel_box(0.97, 12))
	_win.custom_minimum_size = Vector2(WINDOW_W, 0)
	_win.position = Vector2(1920.0 - WINDOW_W - 40.0, 90.0)
	add_child(_win)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_win.add_child(v)
	var bar := Label.new()  # (the grip: drag the window by its title)
	bar.text = "Text Inspector  (drag me)"
	bar.add_theme_font_size_override("font_size", 18)
	bar.add_theme_color_override("font_color", UiTheme.ACCENT)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(_bar_input)
	v.add_child(bar)
	_group_label = UiTheme.label("Click a text.", 16, Color(1, 0.85, 0.5))
	_group_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_group_label)
	_text_label = UiTheme.label("", 15, UiTheme.MUTED)
	_text_label.visible = false
	v.add_child(_text_label)
	_edit = TextEdit.new()  # (the words themselves: type here to reword the selected text)
	_edit.custom_minimum_size = Vector2(WINDOW_W - 40.0, 76)
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.add_theme_font_size_override("font_size", 16)
	_edit.text_changed.connect(_words_changed)
	_edit.editable = false
	v.add_child(_edit)
	_fields = VBoxContainer.new()
	_fields.add_theme_constant_override("separation", 8)
	v.add_child(_fields)
	_isolate = CheckBox.new()
	_isolate.text = "Isolate text"
	_isolate.button_pressed = true
	_isolate.focus_mode = Control.FOCUS_NONE
	_isolate.add_theme_font_size_override("font_size", 16)
	_isolate.toggled.connect(func(_on): if _sel != null: _select(_sel))
	_fields.add_child(_isolate)
	_font_opt = OptionButton.new()
	_font_opt.add_item("Default")
	for lab in UiTheme.FONT_LABELS:
		_font_opt.add_item(lab)
	_font_opt.custom_minimum_size = Vector2(200, 0)
	_font_opt.item_selected.connect(_font_picked)
	_fields.add_child(_row("Font", _font_opt))
	_size_spin = _spin(6.0, 200.0, 1.0, _size_changed)
	_fields.add_child(_row("Size (px)", _size_spin))
	_gap_spin = _spin(-4.0, 24.0, 1.0, _gap_changed)
	_fields.add_child(_row("Gap", _gap_spin))
	_color_btn = ColorPickerButton.new()
	_color_btn.custom_minimum_size = Vector2(110, 30)
	_color_btn.color_changed.connect(_color_changed)
	_fields.add_child(_row("Colour", _color_btn))
	_arrows = HBoxContainer.new()  # (move the text: click an arrow, or drag the text itself, or use the arrow keys; Shift = 10 px)
	_arrows.add_theme_constant_override("separation", 6)
	for pair in [["◀", Vector2(-1, 0)], ["▲", Vector2(0, -1)], ["▼", Vector2(0, 1)], ["▶", Vector2(1, 0)]]:
		var d: Vector2 = pair[1]
		var ab := Button.new()
		ab.text = pair[0]
		ab.custom_minimum_size = Vector2(38, 30)
		ab.focus_mode = Control.FOCUS_NONE
		ab.pressed.connect(func(): _nudge(d * (10.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)))
		_arrows.add_child(ab)
	_pos_label = Label.new()
	_pos_label.add_theme_font_size_override("font_size", 15)
	_arrows.add_child(_pos_label)
	_fields.add_child(_row("Move", _arrows))
	_note = UiTheme.label("", 14, UiTheme.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(WINDOW_W - 40.0, 0)
	v.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UiTheme.button("Cancel", cancel, 18, "back"))
	row.add_child(UiTheme.button("Save", save, 18, "primary"))
	v.add_child(row)
	_fields.visible = false
	for n in [_win]:
		_skip_restyle(n)


## Mark a whole subtree: UiTheme.reapply_all does not restyle it.
func _skip_restyle(n: Node) -> void:
	n.set_meta("hg_skip", true)


func _row(text: String, c: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	row.add_child(c)
	return row


func _spin(lo: float, hi: float, step: float, cb: Callable) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.step = step
	sp.custom_minimum_size = Vector2(110, 0)
	sp.value_changed.connect(cb)
	return sp


func _bar_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
	elif ev is InputEventMouseMotion and _drag:
		_win.position += ev.relative
		_win.position.x = clampf(_win.position.x, 0.0, 1920.0 - 80.0)
		_win.position.y = clampf(_win.position.y, 0.0, 1080.0 - 40.0)


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_F7 or ev.keycode == KEY_ESCAPE):
		if _unsaved():
			_banner.text = "Unsaved changes!  Press Save to keep them, or Cancel to drop them."  # (F7 / Esc never throws work away by itself)
			_banner.add_theme_color_override("font_color", Color(1, 0.45, 0.35))
		else:
			cancel()
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and _sel != null and ev.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and not _typing():
		var step := 10.0 if ev.shift_pressed else 1.0
		_nudge(Vector2(step * float(int(ev.keycode == KEY_RIGHT) - int(ev.keycode == KEY_LEFT)), step * float(int(ev.keycode == KEY_DOWN) - int(ev.keycode == KEY_UP))))
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and _moving:
		_nudge(ev.relative)
	elif ev is InputEventMouseMotion:
		var h := _pick(_catcher.get_global_mouse_position()) if not _win.get_global_rect().has_point(ev.position) else null
		if h != _hover:
			_hover = h
			_catcher.queue_redraw()


## A box of the window has the keyboard (the arrow keys move the cursor there, not the text).
func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is TextEdit or f is LineEdit


## Press on the words: on the selected text it starts dragging it, elsewhere it selects the text under the pointer.
func _on_catcher_click(pos: Vector2) -> void:
	if is_instance_valid(_sel) and _sel.has_meta("hg") and not _whole_group() and _sel.get_global_rect().grow(3.0).has_point(pos):
		_moving = true
		return
	var t := _pick(pos)
	if t != null:
		_select(t)


## The text under a point: the top-most visible Label / RichTextLabel / Button with words in it (the smallest one when several lie on the same level).
func _pick(pos: Vector2) -> Control:
	var best: Control = null
	var best_key := [-99999, -1.0e9]
	var stack: Array = [get_tree().root]
	var hits: Array = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == self:
			continue
		for c in n.get_children():
			stack.append(c)
		if n is Control and _has_words(n) and n.is_visible_in_tree() and n.get_global_rect().has_point(pos):
			hits.append(n)
	for n in hits:
		var key := [_abs_z(n), -(n as Control).get_global_rect().get_area()]
		if best == null or key[0] > best_key[0] or (key[0] == best_key[0] and key[1] > best_key[1]):
			best = n
			best_key = key
	return best


func _has_words(n: Control) -> bool:
	if n is Label:
		return (n as Label).text.strip_edges() != ""
	if n is RichTextLabel:
		return (n as RichTextLabel).get_parsed_text().strip_edges() != ""
	if n is Button:
		return (n as Button).text.strip_edges() != ""
	return false


func _abs_z(c: CanvasItem) -> int:
	var z := 0
	var n: Node = c
	while n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return z


func _select(c: Control) -> void:
	_sel = c
	_catcher.queue_redraw()
	_fields.visible = true
	_building = true
	_edit.text = _text_of(c)
	_edit.editable = not (c is RichTextLabel)
	_isolate.disabled = not c.has_meta("hg")
	_arrows.get_parent().visible = c.has_meta("hg") and not _whole_group()  # (the whole row: its label too)
	var style := _style()
	if c.has_meta("hg"):
		var g := String(c.get_meta("hg"))
		_group_label.text = "Group: %s" % UiTheme.HEADER_LABELS[UiTheme.HEADER_GROUPS.find(g)]
		_note.text = "Not ticked: every text of the group changes with it (sizes can move the layout)." if _whole_group() else "Ticked: only this text changes; nothing else moves."
	else:
		_group_label.text = "Not in a style group"
		_note.text = "This text is not made by the game's text helpers: the change is for the screen that is open, and Save cannot keep it."
	var fsel := 0
	for i in UiTheme.FONT_OPTIONS.size():
		if UiTheme.FONT_OPTIONS[i] == String(style.font):
			fsel = i + 1
	_font_opt.select(fsel)
	_size_spin.value = _current_size(c)
	_gap_spin.value = float(style.spacing)
	_color_btn.color = _current_color(c)
	_show_pos()
	_building = false


func _text_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	return (c as Button).text


func _current_size(c: Control) -> float:
	return float(c.get_theme_font_size("font_size" if not (c is RichTextLabel) else "normal_font_size"))


func _current_color(c: Control) -> Color:
	return c.get_theme_color("font_color" if not (c is RichTextLabel) else "default_color")


func _whole_group() -> bool:
	return not _isolate.button_pressed and _sel != null and _sel.has_meta("hg")


## The style being edited: the group's (whole group), or this text's own: {"font", "px", "spacing", "color"}, started from how it looks now.
func _style() -> Dictionary:
	if _whole_group():
		return UiTheme.header_style(String(_sel.get_meta("hg")))
	var ts := UiTheme.text_style(_sel)
	if not ts.is_empty():
		return ts
	if _sel.has_meta("ins_style"):
		return _sel.get_meta("ins_style")
	var g: Dictionary = UiTheme.header_style(String(_sel.get_meta("hg"))) if _sel.has_meta("hg") else UiTheme.HEADER_DEFAULT
	return {"font": g.font, "px": 0, "spacing": float(g.spacing), "color": "", "dx": 0, "dy": 0}


func _commit(st: Dictionary) -> void:
	if _whole_group():
		var g := String(_sel.get_meta("hg"))
		var all = SaveManager.data.settings.get("header_styles", {})  # (no save_game: only Save writes the file)
		if not (all is Dictionary):
			all = {}
		all[g] = st
		SaveManager.data.settings["header_styles"] = all
		UiTheme.reapply_all(get_tree().root)
	elif _sel.has_meta("hg"):
		var key := UiTheme.text_key(_sel)
		var all2 = SaveManager.data.settings.get("text_styles", {})
		if not (all2 is Dictionary):
			all2 = {}
		all2[key] = st
		SaveManager.data.settings["text_styles"] = all2
		UiTheme.apply_header(_sel, String(_sel.get_meta("hg")), int(_sel.get_meta("hg_size")))  # (this one text only)
	else:
		_sel.set_meta("ins_style", st)
		_direct(_sel, st)
	_catcher.queue_redraw()


## A text of no group: its own overrides.
func _direct(c: Control, st: Dictionary) -> void:
	var f := UiTheme.header_font("body", st)
	if f != null:
		c.add_theme_font_override("font", f)
	var px := int(st.get("px", 0))
	if px > 0:
		c.add_theme_font_size_override("font_size" if not (c is RichTextLabel) else "normal_font_size", px)
	var col := String(st.get("color", ""))
	if col != "":
		c.add_theme_color_override("font_color" if not (c is RichTextLabel) else "default_color", Color.html(col))


## Move the selected text by `d` pixels (kept for this one text; Save keeps it for the game).
func _nudge(d: Vector2) -> void:
	if _sel == null or not _sel.has_meta("hg") or _whole_group():
		return
	var st := _style()
	st.dx = float(st.get("dx", 0)) + d.x
	st.dy = float(st.get("dy", 0)) + d.y
	_commit(st)
	_show_pos()


func _show_pos() -> void:
	if _sel == null or not is_instance_valid(_pos_label):
		return
	var st := _style()
	_pos_label.text = "x %+d  y %+d" % [roundi(float(st.get("dx", 0))), roundi(float(st.get("dy", 0)))]


## The words are typed: the text changes at once (a text made by the game's helpers keeps the new words for the game on Save; the first words are its key).
func _words_changed() -> void:
	if _building or _sel == null or _sel is RichTextLabel:
		return
	var words := _edit.text
	if _sel.has_meta("hg"):
		var key := UiTheme.text_key(_sel)
		var all = SaveManager.data.settings.get("text_edits", {})
		if not (all is Dictionary):
			all = {}
		if words == key:
			all.erase(key)
		else:
			all[key] = words
		SaveManager.data.settings["text_edits"] = all
		UiTheme.apply_text_edit(_sel)
	elif _sel is Label:
		(_sel as Label).text = words
	elif _sel is Button:
		(_sel as Button).text = words
	_catcher.queue_redraw()


func _font_picked(i: int) -> void:
	if _building or _sel == null:
		return
	var st := _style()
	st.font = "default" if i == 0 else UiTheme.FONT_OPTIONS[i - 1]
	_commit(st)


func _size_changed(v: float) -> void:
	if _building or _sel == null:
		return
	var st := _style()
	if _whole_group():
		st.scale = clampf(roundf(v / maxf(float(_sel.get_meta("hg_size")), 1.0) * 100.0), 20.0, 400.0)
	else:
		st.px = int(v)
	_commit(st)


func _gap_changed(v: float) -> void:
	if _building or _sel == null:
		return
	var st := _style()
	st.spacing = v
	_commit(st)


func _color_changed(c: Color) -> void:
	if _building or _sel == null:
		return
	var st := _style()
	st.color = c.to_html(false)
	_commit(st)


## Something was changed and not saved yet.
func _unsaved() -> bool:
	for k in ["header_styles", "text_styles", "text_edits"]:
		if hash(SaveManager.data.settings.get(k, {})) != hash(_snapshot[k]):
			return true
	return false


## Keep the changes: the settings are written.
func save() -> void:
	Audio.play("ui_click")
	SaveManager.save_game()
	_close()


## Put everything back as it was.
func cancel() -> void:
	SaveManager.data.settings["header_styles"] = _snapshot.header_styles
	SaveManager.data.settings["text_styles"] = _snapshot.text_styles
	SaveManager.data.settings["text_edits"] = _snapshot.text_edits
	SaveManager.data.settings["font"] = _snapshot.font
	UiTheme.reapply_all(get_tree().root)
	_close()


func _close() -> void:
	get_tree().paused = _was_paused
	queue_free()


## The layer that takes every click (nothing under it gets one) and draws the outlines of the hovered and the selected text.
class _Catcher extends Control:
	var inspector: TextInspector

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				inspector._on_catcher_click(ev.position)
			else:
				inspector._moving = false
			accept_event()

	func _draw() -> void:
		for pair in [[inspector._hover, Color(1, 0.9, 0.3, 0.9), 2.0], [inspector._sel, Color(1, 0.5, 0.2, 1.0), 3.0]]:
			var c: Control = pair[0]
			if is_instance_valid(c) and c.is_visible_in_tree():
				draw_rect(c.get_global_rect().grow(3.0), pair[1], false, pair[2])
