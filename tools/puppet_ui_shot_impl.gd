extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp/puppet_ui.png"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://puppet_ui_save.json")
	save.data.settings["theme"] = "puppet"
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.08, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	root.theme = UiTheme.get_theme()
	# 1: a wooden panel with text, a hint board, badges, counter
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9))
	panel.position = Vector2(40, 40)
	var lab := UiTheme.label("A wooden panel\nwith two lines", 22)
	panel.add_child(lab)
	bg.add_child(panel)
	var hint := PanelContainer.new()
	hint.add_theme_stylebox_override("panel", UiSkin.box("panel_paper_frame", [46, 46, 46, 46], [36, 28, 34, 34]))
	hint.custom_minimum_size = Vector2(440, 0)
	hint.position = Vector2(40, 220)
	var hl := UiTheme.label("Seedling: the hint text sits on the white board.\nSecond line of it.", 18, Color(0.14, 0.11, 0.08))
	hint.add_child(hl)
	bg.add_child(hint)
	var badge := PanelContainer.new()
	var pill := UiSkin.box("status_badge_pill", [17, 16, 17, 16], [14, 3, 14, 5])
	pill.modulate_color = Color(1.0, 0.6, 0.5)
	badge.add_theme_stylebox_override("panel", pill)
	badge.add_child(UiTheme.label("Burn 3", 16, Color(0.2, 0.1, 0.05)))
	badge.position = Vector2(40, 460)
	bg.add_child(badge)
	var counter := AmberCounter.new()
	counter.position = Vector2(200, 456)
	bg.add_child(counter)
	# 2: buttons
	var x := 560.0
	for k in ["Small", "Menu", "Play"]:
		var b := UiTheme.button("%s button" % k, func(): pass, 20)
		b.custom_minimum_size = Vector2(240, 56)
		b.position = Vector2(x, 60.0)
		if k == "Menu":
			UiTheme.use_menu_style(b)
		if k == "Play":
			UiTheme.use_play_style(b)
		bg.add_child(b)
		x += 280.0
	# 3: slot frame with fake slots, essence balls with overlays, skull
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.position = Vector2(580, 170)
	for i in 5:
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(56, 56)
		c.color = Color(0.4, 0.4, 0.5, 0.5)
		row.add_child(c)
	bg.add_child(row)
	UiSkin.frame_behind(row)
	var ox := 580.0
	for el in ["F", "W", "A", "X"]:
		var e := ElementIcon.make(el if el != "X" else "A", 64.0)
		e.position = Vector2(ox, 300)
		bg.add_child(e)
		ox += 84.0
	var fz := ElementIcon.make("W", 64.0)
	fz.frozen = true
	fz.position = Vector2(ox, 300)
	bg.add_child(fz)
	ox += 84.0
	var sk := UiSkin.icon("icon_skull", 64)
	sk.position = Vector2(ox, 300)
	bg.add_child(sk)
	var xo := UiSkin.icon("x_essence_overlay", 64)
	xo.position = Vector2(ox + 84.0, 300)
	bg.add_child(xo)
	var tm := UiSkin.icon("target_marker", 120)
	tm.position = Vector2(ox + 170.0, 280)
	bg.add_child(tm)
	# 4: scroll container + slider
	var sc := ScrollContainer.new()
	sc.position = Vector2(580, 440)
	sc.custom_minimum_size = Vector2(300, 220)
	sc.size = Vector2(300, 220)
	var vb := VBoxContainer.new()
	for i in 20:
		vb.add_child(UiTheme.label("scroll line %d" % i, 18))
	sc.add_child(vb)
	bg.add_child(sc)
	ScrollThumb.attach(sc)
	var sl := HSlider.new()
	sl.position = Vector2(920, 460)
	sl.custom_minimum_size = Vector2(300, 28)
	sl.size = Vector2(300, 28)
	sl.value = 60
	bg.add_child(sl)
	# 5: shop merchant + keeper portrait
	var m := UiSkin.icon("merchant_portrait", 220)
	m.position = Vector2(1300, 40)
	bg.add_child(m)
	var kp := UiSkin.icon("portrait_keeper", 120)
	kp.position = Vector2(1560, 40)
	bg.add_child(kp)
	# 6: the pause board (its own shot: it shades the whole screen) and a toast
	if OS.get_environment("SHOT_PART") == "pause":
		var pm := PauseMenu.new()
		pm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.add_child(pm)
	var ts: VBoxContainer = load("res://scripts/ui/toasts.gd").new()
	ts.position = Vector2(40, 560)
	bg.add_child(ts)
	ts.show_toast("A toast: {icon:icon_heart|♥} +5 Leaves", Color(0.8, 0.5, 0.2))
	await t.create_timer(2.0).timeout
	root.get_texture().get_image().save_png(out)
	t.quit()
