extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://encounter_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := rs.make_fight(["giant_slime"])
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	f.enemies[0].ignite(4, f.rng)
	fs._refresh_all()
	await t.create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/burn_0.png")
	fs._on_end_turn()
	for k in range(1, 7):
		await t.create_timer(0.17).timeout
		root.get_texture().get_image().save_png(out + "/burn_%d.png" % k)
	t.quit()
