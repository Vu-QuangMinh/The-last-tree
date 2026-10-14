extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://menu_shot_save.json")
	save.data.settings["theme"] = "puppet"
	if OS.get_environment("SHOT_DEV") != "":
		save.data.settings["dev_mode"] = true
	save.data.seedlings = 7
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	if OS.get_environment("SHOT_RUN") != "":  # a saved run: Continue + New run
		save.data.run = {"x": 1}
	var m := MenuScreen.new()
	root.add_child(m)
	for k in 3:
		await t.create_timer(4.0 if k > 0 else 3.0).timeout
		root.get_texture().get_image().save_png("%s/menu_%d.png" % [out, k])
	m._toggle_more()
	await t.create_timer(0.5).timeout
	root.get_texture().get_image().save_png("%s/menu_more.png" % out)
	t.quit()
