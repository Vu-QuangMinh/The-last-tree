extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var mode: String = OS.get_environment("BALL_MODE") if OS.get_environment("BALL_MODE") != "" else "refund"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://ball_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["greenseer"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	if mode == "cards":  # eight spells: the row must stop at the Chant strip's right end
		var base: Array = f.loadout.duplicate()
		while f.loadout.size() < 8:
			f.loadout.append(base[f.loadout.size() % base.size()])
		fs._build_spells()
		fs._refresh_all()
		await t.create_timer(1.0).timeout
		root.get_texture().get_image().save_png(out + "/cards8.png")
		t.quit()
		return
	var uids: Array = []
	var els: Array = []
	var slots: Array = []
	for i in 4:
		uids.append(f.player.stock[i].uid)
		els.append(f.player.stock[i].el)
		slots.append(i)
	if mode == "refund":
		fs._refund_flight({"uids": uids, "els": els, "slots": slots})
	else:
		fs._stash_flight({"drawn": els, "eff": {}}, Vector2(1000, 700))
	for k in 24:
		await t.create_timer(0.15).timeout
		var img := root.get_texture().get_image()
		img.get_region(Rect2i(560, 700, 1040, 200)).save_png("%s/ball_%03d.png" % [out, k])
	t.quit()
