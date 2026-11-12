extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://ts_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var s := TestModeScreen.new()
	root.add_child(s)
	for k in 3:
		s._show_tab(k)
		await t.create_timer(1.0).timeout
		root.get_texture().get_image().save_png(out + "/ts_%d.png" % k)
	t.quit()
