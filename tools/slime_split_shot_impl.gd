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
	var f := rs.make_fight(["ashling", "giant_slime"])
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, f)
	root.add_child(fs)
	await t.create_timer(5.0).timeout
	root.get_texture().get_image().save_png(out + "/split_0.png")
	var g: EnemyState = f.enemies.filter(func(e): return e.id == "giant_slime")[0]
	g.reset_hp("")
	f._cleanup()
	var k := 1
	for wait in [0.4, 0.8, 0.9, 0.6, 0.5, 1.5]:
		await t.create_timer(wait).timeout
		root.get_texture().get_image().save_png(out + "/split_%d.png" % k)
		k += 1
	t.quit()
