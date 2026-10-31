extends SceneTree
## Show FPS: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/fps_shot.gd -- <out folder>
func _init() -> void:
	await process_frame
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	create_timer(60.0).timeout.connect(quit)
	var save = root.get_node("SaveManager")
	save.use_test_file("user://fps_shot.json")
	save.data.settings["theme"] = "puppet"
	save.data.settings["show_fps"] = true
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out + "/fps_menu.png")
	m.open_settings()
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out + "/fps_settings.png")
	quit()
