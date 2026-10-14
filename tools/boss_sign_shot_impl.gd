extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://boss_sign_save.json")
	save.data.settings["theme"] = "puppet"
	var st := PuppetStage.new(1)
	root.add_child(st)
	for kind in ["victory", "boss_defeated"]:
		await st.drop_sign("x", Color.WHITE, kind).finished
		await t.create_timer(0.4).timeout
		root.get_texture().get_image().save_png("%s/sign_%s.png" % [out, kind])
	t.quit()
