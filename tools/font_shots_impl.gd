extends RefCounted
## The Settings screen and the main menu in each font of Settings > Font (a still each): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/font_shots.gd -- <out folder>
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://font_shots.json")
	save.data.settings["theme"] = "puppet"
	var only := OS.get_cmdline_user_args().slice(1)
	for f in UiTheme.FONT_OPTIONS:
		if not only.is_empty() and not (f in only):
			continue
		save.set_setting("font", f)
		UiTheme.reset()
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await t.create_timer(1.5).timeout
		main._test_event("lost_sprite")
		await t.create_timer(2.0).timeout
		root.get_texture().get_image().save_png(out + "/font_%s_event.png" % f)
		main.queue_free()
		await t.create_timer(0.5).timeout
	print("FONTS DONE")
	t.quit()
