extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://dragon_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["winter_wyvern"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var d: EnemyState = f.enemies[0]
	_shot(root, out + "/dragon_idle.png")
	var moves: Array = d.def.moves
	for i in moves.size():
		d.intent = moves[i]
		d.fireball = 10 if moves[i].kind == "fireball_blast" else 0
		fs._sync_views()
		fs._refresh_all()
		await t.create_timer(1.3).timeout
		_shot(root, out + "/dragon_%d.png" % i)
		fs._views[d].creature.dragon_fx()
		var steps := [0.25, 0.2, 0.2, 0.2]  # (the wing stays open in every move)
		for k in steps.size():
			await t.create_timer(steps[k]).timeout
			_shot(root, out + "/dragon_%d_fx%d.png" % [i, k])
		print(i, " ", EnemyDefs.describe_move(moves[i]), "  hit at ", fs._views[d].creature.dragon_hit_time())
		await t.create_timer(1.0).timeout
	# the wing folding down over the front, then over the back (your Essence flies at an Armoured one)
	d.intent = {"kind": "attack", "n": 1}
	d.fireball = 0
	fs._sync_views()
	await t.create_timer(0.5).timeout
	for side in [1, -1]:
		fs._views[d].creature.dragon_guard(side)
		for k in 9:
			await t.create_timer(0.07).timeout
			_shot(root, out + "/guard%d_%d.png" % [1 if side > 0 else 2, k])
		await t.create_timer(1.5).timeout
	# the Fireball goes off: it flies into the HP bar and bursts there (frames every 0.15 s)
	d.intent = moves[3]
	d.fireball = 10
	fs._sync_views()
	await t.create_timer(1.2).timeout
	fs._enemy_attack({"enemy": d, "n": 10, "blocked": false})
	d.fireball = 0
	for k in 8:
		await t.create_timer(0.15).timeout
		_shot(root, out + "/ball_%d.png" % k)
	await t.create_timer(1.5).timeout
	# the roar: two slow waves (frames every 0.3 s)
	d.intent = moves[4]
	fs._sync_views()
	await t.create_timer(1.0).timeout
	fs._views[d].creature.dragon_fx()
	for k in 6:
		await t.create_timer(0.3).timeout
		_shot(root, out + "/roar_%d.png" % k)
	print("done")


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)
