class_name SettingsScreen
extends Control
## Volume settings, opened from the main menu or the in-fight pause menu.

signal closed

var _font_edit: FontEditScreen
var _music_edit: MusicEditScreen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.04, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 16))
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var scroll := ScrollContainer.new()  # (Header styles made the list taller than the screen)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(640, 880)
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := UiTheme.heading("Settings", 34, Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UiTheme.button(UiTheme.hk("Close", "Esc"), func(): closed.emit(), 18))
	v.add_child(UiTheme.heading("Look", 22, UiTheme.ACCENT))
	v.add_child(_theme_row())
	v.add_child(_font_edit_row())
	v.add_child(_tick_row("Show Hotkey", "show_hotkeys", true))
	v.add_child(_tick_row("Show FPS", "show_fps", false))
	v.add_child(UiTheme.heading("Volume", 22, UiTheme.ACCENT))
	v.add_child(_volume_row("Overall", Audio.overall_level, func(x): Audio.set_overall_level(x); Audio.play("ui_click")))
	v.add_child(_volume_row("Sound", Audio.sfx_level, func(x): Audio.set_sfx_level(x); Audio.play("ui_click")))
	v.add_child(_volume_row("Music", Audio.music_level, func(x): Audio.set_music_level(x)))
	v.add_child(UiTheme.heading("Music tracks", 22, UiTheme.ACCENT))
	v.add_child(_music_edit_row())
	v.add_child(UiTheme.heading("Game", 22, UiTheme.ACCENT))
	v.add_child(_tick_row("Dev Mode", "dev_mode", false))
	_cream_buttons(self)
	if UiSkin.is_newui2():
		_dark_ink(self)


## NewUI Ver2: the settings board is a light panel, so its words (not the buttons') are dark.
const DARK_INK := Color(0.13, 0.07, 0.04)


func _dark_ink(n: Node) -> void:
	for c in n.get_children():
		if c is Label:
			(c as Label).add_theme_color_override("font_color", DARK_INK)
			(c as Label).add_theme_constant_override("outline_size", 0)
		_dark_ink(c)


## Theme: Puppet (the HUD as it was) or New UI (the HUD of page 2 of Chant UI for puppet.pdf). Screens opened afterwards use it; a fight already on the screen keeps its own.
func _theme_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label("Theme", 18)
	l.custom_minimum_size = Vector2(160, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(280, 0)
	for i in UiSkin.OPTIONS.size():
		opt.add_item(UiSkin.LABELS[i])
		if UiSkin.OPTIONS[i] == UiSkin.theme_id():
			opt.select(i)
	opt.item_selected.connect(func(i):
		Audio.play("ui_click")
		UiSkin.set_theme(UiSkin.OPTIONS[i])
		_rebuild.call_deferred())
	row.add_child(opt)
	return row


## Every button of this screen is the cream plaque with brown words (the dropdowns too); the tick boxes keep their own art.
func _cream_buttons(n: Node) -> void:
	for c in n.get_children():
		if c is Button and not (c is CheckBox) and c != null and not c.has_meta("hg_skip"):
			UiTheme.skin_button(c, "back")
		_cream_buttons(c)


## Music Edit: its own board (MusicEditScreen) with every place that has music.
func _music_edit_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label("Tracks", 18)
	l.custom_minimum_size = Vector2(160, 0)
	row.add_child(l)
	row.add_child(UiTheme.button("Music Edit", _open_music_edit, 18))
	return row


func _open_music_edit() -> void:
	if is_instance_valid(_music_edit):
		return
	_music_edit = MusicEditScreen.new()
	_music_edit.closed.connect(func():
		_music_edit.queue_free()
		_music_edit = null)
	add_child(_music_edit)


## Font Edit: its own board (FontEditScreen) for the body font and the header groups; Apply there saves them and this screen is built again in the new fonts.
func _font_edit_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label("Fonts", 18)
	l.custom_minimum_size = Vector2(160, 0)
	row.add_child(l)
	row.add_child(UiTheme.button("Font Edit", _open_font_edit, 18))
	return row


func _open_font_edit() -> void:
	if is_instance_valid(_font_edit):
		return
	_font_edit = FontEditScreen.new()
	_font_edit.closed.connect(func():
		_font_edit.queue_free()
		_font_edit = null)
	_font_edit.applied.connect(func(): call_deferred("_rebuild"))
	add_child(_font_edit)


## Show Hotkey off = button texts lose their key: "Chant  (Enter)" becomes "Chant". Screens opened afterwards follow it.
## Dev Mode adds the Dev buttons to the main menu.
func _tick_row(text: String, key: String, default: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var on: bool = SaveManager.setting(key, default)
	var frame := UiSkin.tex("artifact_slot_hover")
	var tick := UiSkin.tex("card_overlay_used")
	var v2 := UiSkin.is_newui2() and UiSkin.tex("nu2_check_box") != null and UiSkin.tex("nu2_check_mark") != null
	if v2:  # (NewUI Ver2: its own tick box and brass check mark)
		frame = UiSkin.tex("nu2_check_box")
		tick = UiSkin.tex("nu2_check_mark")
	if frame == null or tick == null:
		var cb := CheckBox.new()
		cb.text = text
		cb.button_pressed = on
		cb.toggled.connect(func(v): SaveManager.set_setting(key, v))
		row.add_child(cb)
		return row
	var box := Control.new()
	box.custom_minimum_size = Vector2(44, 44)
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fr := TextureRect.new()
	fr.texture = frame
	fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fr)
	var ck := TextureRect.new()
	ck.texture = tick
	ck.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ck.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := -3.0 if v2 else 9.0  # (the brass mark may stand out of the box a little)
	ck.offset_left = inset
	ck.offset_top = inset
	ck.offset_right = -inset
	ck.offset_bottom = -inset
	if v2:
		ck.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		fr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ck.visible = on
	box.add_child(ck)
	var label := UiTheme.label(text, 18)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var toggle := func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var now: bool = not SaveManager.setting(key, default)  # (read it each time: a lambda keeps its own copy of `on`)
			ck.visible = now
			SaveManager.set_setting(key, now)
			Audio.play("ui_click")
	box.gui_input.connect(toggle)
	label.gui_input.connect(toggle)
	row.add_child(box)
	row.add_child(label)
	return row


func _rebuild() -> void:
	for c in get_children():
		if c == _font_edit or c == _music_edit:
			continue  # (the Font Edit board stays open over the screen that is built again)
		c.queue_free()
		remove_child(c)
	_build()
	if is_instance_valid(_font_edit):
		move_child(_font_edit, -1)
	if is_instance_valid(_music_edit):
		move_child(_music_edit, -1)


func _volume_row(label_text: String, start: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label(label_text, 18)
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = start
	slider.custom_minimum_size = Vector2(340, 0)
	row.add_child(slider)
	var pct := UiTheme.label("%d%%" % roundi(start * 100), 18, UiTheme.MUTED)
	pct.custom_minimum_size = Vector2(60, 0)
	row.add_child(pct)
	slider.value_changed.connect(func(x):
		pct.text = "%d%%" % roundi(x * 100)
		on_change.call(x))
	return row


## A label, a dropdown of every track file found in assets/Global/Music/<category>/, and a Play
## button to preview whichever one is selected.
func _exit_tree() -> void:
	Audio.stop_preview()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		if is_instance_valid(_music_edit):
			_music_edit.closed.emit()
		elif is_instance_valid(_font_edit):
			_font_edit.closed.emit()  # (Esc closes the Font Edit board first)
		else:
			closed.emit()
		get_viewport().set_input_as_handled()
