extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	t.create_timer(90.0).timeout.connect(t.quit)
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://ver2_menu_shot_save.json")
	save.data.settings["theme"] = "newui2"
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var pm := PauseMenu.new()
	root.add_child(pm)
	var pnl := PanelContainer.new()
	pnl.position = Vector2(40, 40)
	pnl.custom_minimum_size = Vector2(300, 160)
	pnl.position = Vector2(40, 40)
	var l := Label.new()
	l.text = "A panel"
	pnl.add_child(l)
	root.add_child(pnl)
	for k in ["primary", "default", "danger", "back", "buy"]:
		var b := Button.new()
		b.text = k.capitalize()
		b.position = Vector2(40, 230 + 60 * ["primary", "default", "danger", "back", "buy"].find(k))
		b.custom_minimum_size = Vector2(200, 44)
		UiTheme.skin_button(b, k, 18)
		root.add_child(b)
		var b2 := Button.new()  # (the same button held down)
		b2.text = k.capitalize()
		b2.position = b.position + Vector2(230, 0)
		b2.custom_minimum_size = Vector2(200, 44)
		UiTheme.skin_button(b2, k, 18)
		b2.add_theme_stylebox_override("normal", b2.get_theme_stylebox("hover"))  # (right column: hover)
		root.add_child(b2)
	await t.create_timer(1.5).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/ver2_menu.png")
	t.quit()
