extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var ids: Array = String(args[1] if args.size() > 1 else "corrector").split(",")
	var phase2 := args.has("phase2")
	var save = root.get_node("SaveManager")
	save.use_test_file("user://boss_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := rs.make_fight(ids)
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	for e in f.enemies:
		if e.id == "corrector":
			e.intent = {"kind": "virus", "n": 3, "name": "Syntax Error"}
			if phase2:
				e.phase = 2
				e.intent2 = {"kind": "lock", "len": 2, "name": "Breakpoint"}
	fs._refresh_all()
	await t.create_timer(1.2).timeout
	root.get_texture().get_image().save_png(out + "/shot_%s%s.png" % [ids[0], "_2" if phase2 else ""])
	t.quit()
