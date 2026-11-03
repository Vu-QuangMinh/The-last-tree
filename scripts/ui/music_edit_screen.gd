class_name MusicEditScreen
extends Control
## Settings > Music Edit: every place of the game that has music (Audio.MUSIC_SLOTS), grouped, on the left; on the right the chosen slot: where it plays, the track it plays
## (the files of assets/Global/Music/<slot>/ that belong to the Theme chosen at the top, see Audio.MUSIC_THEMES), and a listen button. A slot with no track of its own plays its fallback's (shown). Picking a track is kept at once.

signal closed

var _sel := 0
var _theme := "suno_nov03"
var _list_buttons: Array = []
var _right: VBoxContainer
var _play_btn: Button
var _play_path := ""
var _seek: HSlider
var _time: Label
var _setting_seek := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	Audio.preview_changed.connect(_on_preview_changed)
	_theme = Audio.music_theme
	_build()


func _exit_tree() -> void:
	if Audio.preview_changed.is_connected(_on_preview_changed):
		Audio.preview_changed.disconnect(_on_preview_changed)
	Audio.stop_preview()


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
	panel.custom_minimum_size = Vector2(1100, 760)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := UiTheme.heading("Music Edit", 34, Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UiTheme.label("Theme", 18))
	var theme_opt := OptionButton.new()
	theme_opt.custom_minimum_size = Vector2(220, 0)
	for i in Audio.MUSIC_THEMES.size():
		theme_opt.add_item(String(Audio.MUSIC_THEMES[i][1]))
		if Audio.MUSIC_THEMES[i][0] == _theme:
			theme_opt.select(i)
	UiTheme.skin_button(theme_opt, "back")
	theme_opt.item_selected.connect(func(i):
		Audio.play("ui_click")
		Audio.stop_preview()
		_theme = String(Audio.MUSIC_THEMES[i][0])
		SaveManager.set_setting("music_edit_theme", _theme)
		Audio.set_theme(_theme)
		_build())
	top.add_child(theme_opt)
	top.add_child(UiTheme.button("Close", func(): closed.emit(), 20, "back"))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(330, 640)
	body.add_child(scroll)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(left)
	var group := ""
	for i in Audio.MUSIC_SLOTS.size():
		var r: Array = Audio.MUSIC_SLOTS[i]
		if String(r[2]) != group:
			group = String(r[2])
			left.add_child(UiTheme.heading(group, 20, UiTheme.ACCENT))
		var idx: int = i
		var n := Audio.list_tracks_in_theme(String(r[0]), _theme).size()
		var b := UiTheme.button("%s%s" % [r[1], "  (%d)" % n if n > 0 else ""], func(): _select(idx), 17, "primary" if i == _sel else "default")
		b.custom_minimum_size = Vector2(300, 38)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		left.add_child(b)
		_list_buttons.append(b)
	body.add_child(VSeparator.new())
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 14)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_right)
	_fill_right()


func _select(i: int) -> void:
	_sel = i
	Audio.play("ui_click")
	Audio.stop_preview()
	for k in _list_buttons.size():
		UiTheme.skin_button(_list_buttons[k], "primary" if k == i else "default")
	_fill_right()


func _fill_right() -> void:
	for c in _right.get_children():
		c.queue_free()
		_right.remove_child(c)
	var r: Array = Audio.MUSIC_SLOTS[_sel]
	var slot := String(r[0])
	_right.add_child(UiTheme.heading(String(r[1]), 26, UiTheme.ACCENT))
	var where := UiTheme.label("Plays: %s" % r[3], 17, UiTheme.MUTED)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(where)
	var all_tracks := Audio.list_tracks(slot)
	var tracks := Audio.list_tracks_in_theme(slot, _theme)
	var folder := UiTheme.label("Folder: assets/Global/Music/%s/" % slot, 15, UiTheme.MUTED)
	_right.add_child(folder)
	var real := Audio.resolve_category(slot)
	if tracks.is_empty() and not all_tracks.is_empty():
		var other := UiTheme.label("No track of this theme here: it plays a random track of another theme (%d there)." % all_tracks.size(), 17, Color(1, 0.8, 0.4))
		other.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_right.add_child(other)
		return
	if tracks.is_empty():
		var note := "No track here yet."
		if real != "":
			note += " It plays the tracks of \"%s\"." % real
		else:
			note += " Nothing plays here: the music of the screen before goes on."
		var l := UiTheme.label(note, 17, Color(1, 0.8, 0.4))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_right.add_child(l)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var cap := UiTheme.label("Track", 18)
	cap.custom_minimum_size = Vector2(90, 0)
	row.add_child(cap)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(380, 0)
	var pin := Audio.get_pin(slot)
	opt.add_item("Random (a new track each time)")  # (item 0 = no pin; the tracks follow)
	for i in tracks.size():
		opt.add_item(tracks[i].get_basename())
		if tracks[i] == pin:
			opt.select(i + 1)
	UiTheme.skin_button(opt, "back")
	var shown := func() -> String: return tracks[maxi(opt.selected - 1, 0)]  # (the track the listen button and the bar use: the picked one, else the first)
	opt.item_selected.connect(func(i):
		Audio.play("ui_click")
		Audio.set_track(slot, tracks[i - 1] if i > 0 else "")
		_play_path = Audio.MUSIC_DIR + slot + "/" + shown.call()
		_on_preview_changed(Audio.current_preview_path()))
	row.add_child(opt)
	_play_btn = UiTheme.button("▶", func():
		Audio.preview_track(slot, shown.call()), 18, "primary")
	_play_btn.custom_minimum_size = Vector2(56, 0)
	row.add_child(_play_btn)
	var del := UiTheme.button("X", func():  # (deletes the track file from the game at once, no question)
		if opt.selected >= 1:
			Audio.play("ui_click")
			Audio.delete_track(slot, tracks[opt.selected - 1])
			_build(), 18, "danger")
	del.custom_minimum_size = Vector2(56, 0)
	row.add_child(del)
	_right.add_child(row)
	var bar := HBoxContainer.new()  # (under the track: where the listen is; click or drag to jump)
	bar.add_theme_constant_override("separation", 10)
	_time = UiTheme.label("0:00", 15, UiTheme.MUTED)
	_time.custom_minimum_size = Vector2(90, 0)
	bar.add_child(_time)
	_seek = HSlider.new()
	_seek.min_value = 0.0
	_seek.max_value = 1.0
	_seek.step = 0.001
	_seek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seek.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_seek.custom_minimum_size = Vector2(0, 26)
	_seek.focus_mode = Control.FOCUS_NONE
	_seek.value_changed.connect(func(v):
		if not _setting_seek:
			if Audio.current_preview_path() == "":
				Audio.preview_track(slot, shown.call())  # (a click on the bar starts the listen)
			var total := Audio.preview_length()
			if total > 0.0:
				Audio.seek_preview(v * total))
	bar.add_child(_seek)
	_right.add_child(bar)
	_play_path = Audio.MUSIC_DIR + slot + "/" + shown.call()
	var hint := UiTheme.label("%d track(s) in this theme. Random: every time this place starts, it plays one of them. Pick one to pin it. A track you add to the folder shows up here." % tracks.size(), 15, UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(hint)
	_on_preview_changed(Audio.current_preview_path())


func _process(_dt: float) -> void:
	if not is_instance_valid(_seek) or not is_instance_valid(_time):
		return
	var total := Audio.preview_length() if Audio.current_preview_path() == _play_path else 0.0
	var pos := Audio.preview_position() if total > 0.0 else 0.0
	if not _seek.has_focus() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or total <= 0.0:
		_setting_seek = true
		_seek.value = pos / total if total > 0.0 else 0.0
		_setting_seek = false
	_time.text = "%s / %s" % [_mmss(pos), _mmss(total)] if total > 0.0 else "0:00"


func _mmss(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


func _on_preview_changed(path: String) -> void:
	if is_instance_valid(_play_btn):
		_play_btn.text = "■" if path != "" and path == _play_path else "▶"


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
