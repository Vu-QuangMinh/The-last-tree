class_name FontEditScreen
extends Control
## Settings > Font Edit: the groups of text on the left, the settings of the chosen group on the right. Nothing is saved until Apply: the sample shows the change at once,
## Apply writes the fonts (body font + every header group), the game's theme is built again, and the screens opened afterwards (and the Settings screen under this board) use them.
## Close leaves without saving.

signal closed
signal applied

## The groups of the list: "body" is the font of all the ordinary text (a font only); the others are UiTheme.HEADER_GROUPS (font, size, gap between letters, stroke colour).
const BODY := "body"
const SAMPLES := {
	"body": "The quick brown fox jumps over the lazy dog. Đã gửi bản phác thảo sang ImageSet 0123456789",
	"title": "Behind the Curtain",
	"section": "Look · Volume · Music tracks",
	"card": "Thornbark Emblem",
	"event": "The Whispering Well",
	"button": "Chant  Clear  Pass  Menu",
}
const SAMPLE_SIZE := {"body": 22, "title": 40, "section": 24, "card": 30, "event": 26, "button": 24}
const NOTES := {
	"body": "All the ordinary text: labels, buttons, descriptions and the words of an event. Size % is a percentage of what each screen asks for (the insides of cards and the fixed fight layout keep their sizes).",
	"title": "The big headings of a screen: Settings, Codex, The Merchant, Wiki, Unlocks...",
	"section": "The small headings inside a screen: Look, Volume, Music tracks, Active spells, Spellbook...",
	"card": "The name on an artifact card.",
	"event": "The title in the dialogue box of an event.",
	"button": "The Chant, Clear, Pass and Menu buttons.",
}

var _groups: Array = UiTheme.HEADER_GROUPS
var _labels: Array = UiTheme.HEADER_LABELS
var _work := {}  # the unsaved settings: {"font": option, group: style}
var _sel := 0
var _list_buttons: Array = []
var _right: VBoxContainer
var _sample: Label
var _dirty: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	_work = {"font": UiTheme.font_choice()}
	for g in UiTheme.HEADER_GROUPS:
		_work[g] = UiTheme.header_style(g)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
		remove_child(c)
	_list_buttons.clear()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.04, 0.98)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.97, 16))
	panel.custom_minimum_size = Vector2(1100, 640)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := UiTheme.heading("Font Edit", 34, Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	_dirty = UiTheme.label("", 16, Color(1, 0.8, 0.4))
	top.add_child(_dirty)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(300, 0)
	body.add_child(left)
	left.add_child(UiTheme.heading("Groups", 22, UiTheme.ACCENT))
	for i in _groups.size():
		var idx: int = i
		var b := UiTheme.button(_labels[i], func(): _select(idx), 18, "primary" if i == _sel else "default")
		b.custom_minimum_size = Vector2(300, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		left.add_child(b)
		_list_buttons.append(b)
	var sep := VSeparator.new()
	body.add_child(sep)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 14)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_right)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bottom)
	bottom.add_child(UiTheme.button("Reset group", _reset_group, 20, "default"))
	bottom.add_child(UiTheme.button("Close", func(): closed.emit(), 20, "back"))
	bottom.add_child(UiTheme.button("Apply", _apply, 20, "primary"))
	_fill_right()


func _select(i: int) -> void:
	_sel = i
	Audio.play("ui_click")
	for k in _list_buttons.size():
		var kind := "primary" if k == i else "default"
		UiTheme.skin_button(_list_buttons[k], kind)
	_fill_right()


## The right side: the chosen group's settings, then its sample.
func _fill_right() -> void:
	for c in _right.get_children():
		c.queue_free()
		_right.remove_child(c)
	var group: String = _groups[_sel]
	_right.add_child(UiTheme.heading(_labels[_sel], 26, UiTheme.ACCENT))
	var note := UiTheme.label(String(NOTES[group]), 16, UiTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(note)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(300, 0)
	var current := String(_work.font) if group == BODY else String(_work[group].font)
	if group != BODY:
		opt.add_item("Default")
	var sel := 0
	for i in UiTheme.FONT_OPTIONS.size():
		opt.add_item(UiTheme.FONT_LABELS[i])
		if UiTheme.FONT_OPTIONS[i] == current:
			sel = i + (0 if group == BODY else 1)
	opt.select(sel)
	opt.item_selected.connect(func(i):
		Audio.play("ui_click")
		if group == BODY:
			_work.font = UiTheme.FONT_OPTIONS[i]
		else:
			_work[group].font = "default" if i == 0 else UiTheme.FONT_OPTIONS[i - 1]
		_changed())
	_right.add_child(_row("Font", opt))
	if true:
		var st: Dictionary = _work[group]
		_right.add_child(_row("Size %", _spin(50.0, 250.0, 5.0, float(st.scale), func(x): st.scale = x; _changed())))
		_right.add_child(_row("Gap between letters", _spin(-4.0, 24.0, 1.0, float(st.spacing), func(x): st.spacing = x; _changed())))
		var fc := ColorPickerButton.new()
		fc.custom_minimum_size = Vector2(120, 34)
		fc.color = Color.html(String(st.color)) if String(st.color) != "" else Color(1, 1, 1)
		fc.color_changed.connect(func(c: Color):
			st.color = c.to_html(false)
			_changed())
		var fdef := UiTheme.button("Default colour", func():
			st.color = ""
			_changed(), 16, "default")
		var frow := HBoxContainer.new()
		frow.add_theme_constant_override("separation", 10)
		frow.add_child(fc)
		frow.add_child(fdef)
		_right.add_child(_row("Colour", frow))
		var cp := ColorPickerButton.new()
		cp.custom_minimum_size = Vector2(120, 34)
		cp.edit_alpha = true
		cp.color = Color.html(String(st.stroke))
		cp.color_changed.connect(func(c: Color):
			st.stroke = c.to_html(true)
			_changed())
		var none := UiTheme.button("No stroke", func():
			st.stroke = "00000000"
			cp.color = Color(0, 0, 0, 0)
			_changed(), 16, "default")
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 10)
		crow.add_child(cp)
		crow.add_child(none)
		_right.add_child(_row("Stroke colour", crow))
	var sbox := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.05, 0.9)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	sbox.add_theme_stylebox_override("panel", sb)
	sbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sample = UiTheme.label(String(SAMPLES[group]), int(SAMPLE_SIZE[group]), Color(1, 0.9, 0.55) if group != BODY else UiTheme.TEXT)
	_sample.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sample.custom_minimum_size = Vector2(520, 0)
	sbox.add_child(_sample)
	_right.add_child(sbox)
	_show_sample()


## The sample in the unsaved style.
func _show_sample() -> void:
	if not is_instance_valid(_sample):
		return
	var group: String = _groups[_sel]
	_sample.remove_theme_font_override("font")
	_sample.remove_theme_font_size_override("font_size")
	_sample.remove_theme_constant_override("outline_size")
	_sample.remove_theme_color_override("font_outline_color")
	UiTheme.apply_header(_sample, group, int(SAMPLE_SIZE[group]), _work[group])
	if group == BODY and String(_work[group].font) == "default":
		var f := UiTheme.font_for_option(String(_work.font), "regular")
		if f != null:
			_sample.add_theme_font_override("font", f)  # (the body's font is the game's: the sample shows the one chosen above)


func _changed() -> void:
	_dirty.text = "unsaved changes: press Apply"
	_show_sample()


func _reset_group() -> void:
	Audio.play("ui_click")
	var group: String = _groups[_sel]
	_work[group] = UiTheme.HEADER_DEFAULT.duplicate()
	if group == BODY:
		_work.font = "futura"
	_changed()
	_fill_right()


## Save everything, build the game's theme again, and show this board in the new fonts.
func _apply() -> void:
	Audio.play("ui_click")
	SaveManager.set_setting("font", _work.font)
	for g in UiTheme.HEADER_GROUPS:
		UiTheme.set_header_style(g, _work[g])
	UiTheme.reset()
	UiTheme.reapply_all(get_tree().root)
	applied.emit()
	theme = UiTheme.get_theme()
	_build()
	_dirty.text = "applied"


func _row(text: String, c: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label(text, 18)
	l.custom_minimum_size = Vector2(180, 0)
	row.add_child(l)
	row.add_child(c)
	return row


func _spin(lo: float, hi: float, step: float, value: float, on_change: Callable) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = lo
	sp.max_value = hi
	sp.step = step
	sp.value = value
	sp.custom_minimum_size = Vector2(130, 0)
	sp.value_changed.connect(on_change)
	return sp
