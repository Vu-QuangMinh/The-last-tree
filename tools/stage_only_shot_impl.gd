extends RefCounted


func run(t: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var act := int(args[0]) if args.size() > 0 else 2
	var out: String = args[1] if args.size() > 1 else "C:/temp/stage_only.png"
	var save = t.root.get_node("SaveManager")
	save.use_test_file("user://stage_only_save.json")
	save.data.settings["theme"] = "puppet"
	var st := PuppetStage.new(act)
	t.root.add_child(st)
	st.fit(1920.0)
	await t.create_timer(1.0).timeout
	t.root.get_texture().get_image().save_png(out)
	t.quit()
