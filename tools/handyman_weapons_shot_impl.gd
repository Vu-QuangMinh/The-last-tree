extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://handyman_weapons_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["handyman"])
	f.talk_id = ""
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var sword = f.enemies.filter(func(x): return x.id == "hand_sword")[0]
	f.player.hp = 45.0
	f._do_move(sword, {"kind": "attack", "n": 5})
	for k in 6:
		await t.create_timer(0.25).timeout
		_shot(root, out + "/hw_sword%d.png" % k)
	await t.create_timer(2.0).timeout
	_knock(f, "hand_sword")  # (the crossbow grows)
	_knock(f, "hand_tweezer")  # (the hammer grows)
	await t.create_timer(3.0).timeout
	f.cast_counts = {"water_wall": 3}
	var hammer = f.enemies.filter(func(x): return x.id == "hand_hammer")[0]
	f._do_move(hammer, {"kind": "hammer_spell"})
	for k in 6:
		await t.create_timer(0.3).timeout
		_shot(root, out + "/hw_hammer%d.png" % k)
	await t.create_timer(2.0).timeout
	var bow = f.enemies.filter(func(x): return x.id == "hand_crossbow")[0]
	f.player.hp = 40.0
	f._do_move(bow, {"kind": "attack", "n": 12})
	for k in 8:
		await t.create_timer(0.3).timeout
		_shot(root, out + "/hw_arrow%d.png" % k)
	for k in 4:
		await t.create_timer(0.4).timeout
		_shot(root, out + "/hw_arrowb%d.png" % k)
	await t.create_timer(1.5).timeout
	_shot(root, out + "/hw_after.png")
	_knock(f, "hand_crossbow")  # (the spear grows)
	await t.create_timer(3.0).timeout
	var spear = f.enemies.filter(func(x): return x.id == "hand_spear")[0]
	f.player.hp = 30.0
	f._do_move(spear, {"kind": "attack", "n": 8})
	for k in 8:
		await t.create_timer(0.25).timeout
		_shot(root, out + "/hw_spear%d.png" % k)
	t.quit()


func _knock(f: Fight, id: String) -> void:
	var e = f.enemies.filter(func(x): return x.id == id)[0]
	e.elements.clear()
	f._cleanup()


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
