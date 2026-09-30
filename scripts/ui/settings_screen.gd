class_name SettingsScreen
extends Control
## Volume settings, opened from the main menu or the in-fight pause menu.

signal closed

var _preview_rows: Array = []  # [{category, tracks, opt, btn}]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	var t := UiTheme.label("Settings", 34, Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UiTheme.button("Close  (Esc)", func(): closed.emit(), 18))
	v.add_child(UiTheme.label("Volume", 22, UiTheme.ACCENT))
	v.add_child(_volume_row("Overall", Audio.overall_level, func(x): Audio.set_overall_level(x); Audio.play("ui_click")))
	v.add_child(_volume_row("Sound", Audio.sfx_level, func(x): Audio.set_sfx_level(x); Audio.play("ui_click")))
	v.add_child(_volume_row("Music", Audio.music_level, func(x): Audio.set_music_level(x)))
	v.add_child(UiTheme.label("Music tracks", 22, UiTheme.ACCENT))
	v.add_child(_track_row("Map music", "map"))
	v.add_child(_track_row("Main Menu music", "menu"))
	v.add_child(_track_row("Fight music", "fight"))
	v.add_child(_track_row("Boss music", "boss"))
	Audio.preview_changed.connect(_on_preview_changed)


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
