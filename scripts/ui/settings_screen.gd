class_name SettingsScreen
extends Control
## Volume settings, opened from the main menu or the in-fight pause menu.

signal closed

var _preview_rows: Array = []  # [{category, tracks, opt, btn}]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	theme = UiTheme.get_theme()
	_preview_rows.clear()
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := UiTheme.heading("Settings", 34, Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UiTheme.button(UiTheme.hk("Close", "Esc"), func(): closed.emit(), 18))
	v.add_child(UiTheme.heading("Look", 22, UiTheme.ACCENT))
	v.add_child(_theme_row())
	v.add_child(_font_row())
	v.add_child(_tick_row("Show Hotkey", "show_hotkeys", true))
	v.add_child(UiTheme.heading("Volume", 22, UiTheme.ACCENT))
	v.add_child(_volume_row("Overall", Audio.overall_level, func(x): Audio.set_overall_level(x); Audio.play("ui_click")))
	v.add_child(_volume_row("Sound", Audio.sfx_level, func(x): Audio.set_sfx_level(x); Audio.play("ui_click")))
	v.add_child(_volume_row("Music", Audio.music_level, func(x): Audio.set_music_level(x)))
	v.add_child(UiTheme.heading("Music tracks", 22, UiTheme.ACCENT))
	v.add_child(_track_row("Map music", "map"))
	v.add_child(_track_row("Main Menu music", "menu"))
	v.add_child(_track_row("Fight music", "fight"))
	v.add_child(_track_row("Boss music", "boss"))
	v.add_child(_tick_row("Dev Mode", "dev_mode", false))
	if not Audio.preview_changed.is_connected(_on_preview_changed):
		Audio.preview_changed.connect(_on_preview_changed)


## Theme: Default (everything drawn in code) or New (the hand-drawn art). Picking one rebuilds this screen in it;
## screens opened afterwards use it too.
func _theme_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label("Theme", 18)
	l.custom_minimum_size = Vector2(160, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(280, 0)
	var current: String = SaveManager.setting("theme", "new")
	for i in UiSkin.OPTIONS.size():
		opt.add_item(UiSkin.LABELS[i])
		if UiSkin.OPTIONS[i] == current:
			opt.select(i)
	opt.item_selected.connect(func(i):
		Audio.play("ui_click")
		UiSkin.set_theme(UiSkin.OPTIONS[i])
		_rebuild.call_deferred())
	row.add_child(opt)
	return row


## Font: Futura or Acherus for the whole game. Picking one rebuilds this screen in it; screens opened afterwards use it too.
func _font_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label("Font", 18)
	l.custom_minimum_size = Vector2(160, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(280, 0)
	var current := UiTheme.font_choice()
	for i in UiTheme.FONT_OPTIONS.size():
		opt.add_item(UiTheme.FONT_LABELS[i])
		if UiTheme.FONT_OPTIONS[i] == current:
			opt.select(i)
	opt.item_selected.connect(func(i):
		Audio.play("ui_click")
		SaveManager.set_setting("font", UiTheme.FONT_OPTIONS[i])
		UiTheme.reset()
		_rebuild.call_deferred())
	row.add_child(opt)
	return row


## A tick box saved as a setting (Artifact Slot Hover as the frame, Card Overlay Used as the tick in the New theme).
## Show Hotkey off = button texts lose their key: "Chant  (Enter)" becomes "Chant". Screens opened afterwards follow it.
## Dev Mode adds the Dev buttons to the main menu.
func _tick_row(text: String, key: String, default: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var on: bool = SaveManager.setting(key, default)
	var frame := UiSkin.tex("artifact_slot_hover")
	var tick := UiSkin.tex("card_overlay_used")
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
	ck.offset_left = 9
	ck.offset_top = 9
	ck.offset_right = -9
	ck.offset_bottom = -9
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
		c.queue_free()
		remove_child(c)
	_build()


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


## A label, a dropdown of every track file found in assets/music/<category>/, and a Play
## button to preview whichever one is selected.
func _track_row(label_text: String, category: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiTheme.label(label_text, 18)
	l.custom_minimum_size = Vector2(160, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(280, 0)
	var tracks := Audio.list_tracks(category)
	var current := Audio.get_track(category)
	if tracks.is_empty():
		opt.add_item("(no tracks in assets/music/%s/)" % category)
		opt.disabled = true
	else:
		for i in tracks.size():
			opt.add_item(tracks[i].get_basename())
			if tracks[i] == current:
				opt.select(i)
	row.add_child(opt)
	var play_btn := UiTheme.button("▶", func(): pass, 18)
	play_btn.custom_minimum_size = Vector2(48, 0)
	play_btn.disabled = tracks.is_empty()
	row.add_child(play_btn)
	var entry := {"category": category, "tracks": tracks, "opt": opt, "btn": play_btn}
	_preview_rows.append(entry)
	play_btn.pressed.connect(func():
		if not tracks.is_empty() and opt.selected >= 0:
			Audio.preview_track(category, tracks[opt.selected]))
	opt.item_selected.connect(func(i):
		Audio.play("ui_click")
		Audio.set_track(category, tracks[i])
		_on_preview_changed(Audio.current_preview_path()))
	return row


func _on_preview_changed(path: String) -> void:
	for e in _preview_rows:
		var mine := ""
		var tracks: Array = e.tracks
		var opt: OptionButton = e.opt
		if not tracks.is_empty() and opt.selected >= 0:
			mine = Audio.MUSIC_DIR + e.category + "/" + tracks[opt.selected]
		(e.btn as Button).text = "■" if path != "" and path == mine else "▶"


func _exit_tree() -> void:
	if Audio.preview_changed.is_connected(_on_preview_changed):
		Audio.preview_changed.disconnect(_on_preview_changed)
	Audio.stop_preview()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
