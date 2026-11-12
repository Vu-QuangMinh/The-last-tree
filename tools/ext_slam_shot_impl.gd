extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://ext_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, rs.make_fight(["mob_torch"]))
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	for n in [6, 7, 8]:
		fs._h_anim._extension_slam(n)
		await t.create_timer(0.55).timeout
		root.get_texture().get_image().save_png(out + "/ext_%d.png" % n)
		await t.create_timer(1.2).timeout
	t.quit()
