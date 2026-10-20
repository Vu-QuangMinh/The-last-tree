extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://handyman_fall_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["handyman"])
	f.talk_id = ""  # (no talk before the fight)
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.5).timeout
	_shot(root, out + "/hf_1_start.png")
	# the tweezer hand reaches for the bag
	var twz = f.enemies.filter(func(x): return x.id == "hand_tweezer")[0]
	f._do_move(twz, {"kind": "steal", "n": 1})
	for k in 3:
		await t.create_timer(0.4).timeout
		_shot(root, out + "/hf_1b_steal%d.png" % k)
	await t.create_timer(1.5).timeout
	# the sword hand (left) is knocked out: it drops, the crossbow grows in its place
	_knock(f, "hand_sword")
	for k in 4:
		await t.create_timer(0.35).timeout
		_shot(root, out + "/hf_2_fall%d.png" % k)
	await t.create_timer(1.5).timeout
	_shot(root, out + "/hf_3_after.png")
	# the rest of the left side and the right side
	_knock(f, "hand_tweezer")
	await t.create_timer(1.2).timeout
	_knock(f, "hand_crossbow")
	await t.create_timer(1.2).timeout
	_knock(f, "hand_hammer")
	await t.create_timer(1.2).timeout
	_knock(f, "hand_spear")
	await t.create_timer(1.5).timeout
	_shot(root, out + "/hf_4_five_down.png")
	# the last one: all six lie there, he cries, shakes, and pulls them up
	_knock(f, "hand_shield")
	for k in 14:
		await t.create_timer(0.45).timeout
		_shot(root, out + "/hf_5_rally%d.png" % k)
	await t.create_timer(1.0).timeout
	_shot(root, out + "/hf_6_pulled.png")
	await t.create_timer(1.5).timeout
	_shot(root, out + "/hf_7_laststand.png")
	# the last stand: every hand shatters, and he shows himself
	for e in f.enemies.filter(func(x): return x.has_passive("hand")):
		_knock(f, e.id)
		await t.create_timer(0.3).timeout
	for k in 4:
		await t.create_timer(0.8).timeout
		_shot(root, out + "/hf_8_phase3_%d.png" % k)
	print("alive ", f.alive().map(func(e): return "%s:%d" % [e.id, e.size()]), " phase ", f.hm.phase)
	t.quit()


func _knock(f: Fight, id: String) -> void:
	var e = f.enemies.filter(func(x): return x.id == id)[0]
	e.elements.clear()
	f._cleanup()


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

