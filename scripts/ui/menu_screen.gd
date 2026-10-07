class_name MenuScreen
extends Control
## Title screen.

signal play
signal continue_run  # pick up the saved run
signal codex
signal unlocks
signal how_to
signal tutorial
signal settings
signal room_test  # Dev Mode


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	add_child(Backdrop.new())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dev: bool = SaveManager.setting("dev_mode", false)
	if dev:
		v.offset_right = -480.0  # the whole column moves left: the Dev buttons take the right side
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	var title_art := UiSkin.tex("game_title")
	if title_art != null:  # New theme: the painted logo, at its own proportions
		var logo := TextureRect.new()
		logo.texture = title_art
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = title_art.get_size()
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(logo)
	else:
		var t := UiTheme.label("The Last Tree", 88, Color(0.85, 1, 0.75))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 12)
		t.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.04))
		v.add_child(t)
	var s := UiTheme.label("Chant fire, water and wind. Keep the last tree standing.", 24, UiTheme.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	var st: Dictionary = SaveManager.data.stats
	var tut_label := "Tutorial" if SaveManager.setting("tutorial_done", false) else "Tutorial  (recommended)"
	var items := [["Play", play], [tut_label, tutorial], ["How to play · Wiki", how_to], ["Codex", codex], ["Unlocks  (✿ %d)" % SaveManager.data.seedlings, unlocks], ["Settings", settings], ["Quit", null]]
	if SaveManager.has_run():
		items.insert(0, ["Continue", continue_run])  # the saved run, where you left it
		items[1][0] = "New run"
	for pair in items:
		var sig = pair[1]
		var b := UiTheme.button(pair[0], func(): if sig == null: get_tree().quit() else: sig.emit(), 26)
		b.custom_minimum_size = Vector2(360, 60)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if pair[0] == "Play" or pair[0] == "Continue":
			UiTheme.use_play_style(b)
		elif pair[0].begins_with("Unlocks"):
			UiSkin.seedling_button(b, "Unlocks  (%d)" % SaveManager.data.seedlings, pair[0], 26)
		v.add_child(b)
	var info := UiTheme.label("Runs %d  ·  Wins %d  ·  Best act %d" % [st.runs, st.wins, st.get("best_act", 0)], 18, UiTheme.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	if dev:
		_dev_column()


## Dev Mode: a column of test buttons on the right (more to come).
func _dev_column() -> void:
	var d := VBoxContainer.new()
	d.position = Vector2(1180, 0)
	d.size = Vector2(360, 1080)
	d.alignment = BoxContainer.ALIGNMENT_CENTER
	d.add_theme_constant_override("separation", 16)
	add_child(d)
	var h := UiTheme.heading("Dev", 30, UiTheme.ACCENT)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_child(h)
	for pair in [["Room Test", room_test]]:
		var sig: Signal = pair[1]
		var b := UiTheme.button(pair[0], func(): sig.emit(), 26)
		b.custom_minimum_size = Vector2(360, 60)
		d.add_child(b)
