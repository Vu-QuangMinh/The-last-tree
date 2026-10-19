extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "C:/temp/shots"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://tweezer_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["handyman"])
	f.talk_id = ""  # (no talk before the fight)
	var fs := FightScreen.new()
	fs.setup(r, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	for k in 4:
		fs._add_stock_index(k)
		await t.create_timer(0.3).timeout
	await t.create_timer(1.5).timeout
	var sw = f.enemies.filter(func(x): return x.id == "hand_sword")[0]
	f._hand_down(sw)
	fs._sync_views()
	fs._refresh_all()
	await t.create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out + "/tr_revive.png")
	var twz = f.enemies.filter(func(x): return x.id == "hand_tweezer")[0]
	f._do_move(twz, {"kind": "steal", "n": 2})
	for k in 14:
		await t.create_timer(0.35).timeout
		root.get_texture().get_image().save_png(out + "/tr_poke%d.png" % k)
	t.quit()
