extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://debuff_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["ashling"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	var ids: Array = f.loadout.map(func(s): return s.id)
	f.player.ignited[ids[0]] = 1
	f.player.ignite_dmg[ids[0]] = 5
	f.player.virus[ids[1]] = 3
	f.player.toll = 5
	f.player.confuse_turns = 1
	fs._refresh_all()
	await t.create_timer(0.8).timeout
	root.get_texture().get_image().save_png(out + "/debuffs.png")
	t.quit()
