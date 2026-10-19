extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://trinity_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	run.loadout.clear()
	for id in Fight.TRINITY_PARTS:
		run.learn_spell(id)
		if not (id in run.loadout):
			run.loadout.append(id)
	var f := run.make_fight(["greenseer"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.5).timeout
	root.get_texture().get_image().save_png(out + "/trinity_row.png")
	var parts: Array = f.loadout.filter(func(s): return s.id in Fight.TRINITY_PARTS)
	var froms := []
	for s in parts:
		var c: SpellCard = fs._card_for(s.id)
		froms.append(c.global_position if c else Vector2(960, 760))
	TrinityScene.play(fs, parts, froms, gd.db.get_spell("trinity"))
	for k in 14:
		await t.create_timer(0.4).timeout
		root.get_texture().get_image().save_png("%s/trinity_%02d.png" % [out, k])
	t.quit()
