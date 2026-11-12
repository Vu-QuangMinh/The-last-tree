extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://bug_hunter_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := rs.make_fight(["bug_hunter"])
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, f)
	root.add_child(fs)
	await t.create_timer(9.0).timeout
	var cr: Creature = fs._views[f.enemies[0]].creature
	print("has_bug ", cr.has_bug())
	root.get_texture().get_image().save_png(out + "/bh_idle.png")
	var hits: Array = cr.bug_strike(1)
	print("hits ", hits)
	await t.create_timer(0.7).timeout
	root.get_texture().get_image().save_png(out + "/bh_down.png")
	await t.create_timer(float(hits[0]) - 0.7 + 0.25).timeout
	root.get_texture().get_image().save_png(out + "/bh_hit.png")
	t.quit()
