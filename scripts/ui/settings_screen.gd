class_name SettingsScreen
extends Control
## Volume settings, opened from the main menu or the in-fight pause menu.

signal closed


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
	v.add_child(_volume_row("Sound", Audio.sfx_level, func(x): Audio.set_sfx_level(x); Audio.play("ui_click")))
	v.add_child(_volume_row("Music", Audio.music_level, func(x): Audio.set_music_level(x)))


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


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
