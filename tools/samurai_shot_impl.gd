extends RefCounted


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://samurai_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["samurai", "samurai_retainer"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.5).timeout
	_shot(root, out + "/samurai_stage.png")
	var sam: EnemyState = f.enemies[0]
	var ret: EnemyState = f.enemies[1]
	# his three stances: wait until he is in each one
	for k in 3:
		sam.intent = sam.def.moves[k]
		fs._refresh_all()
		await t.create_timer(2.2).timeout
		_shot(root, out + "/samurai_pose_%s.png" % sam.intent.pose)
	# the slash: In no kamae, one shot every 0.08 s
	sam.intent = sam.def.moves[0]
	fs._refresh_all()
	await t.create_timer(2.4).timeout
	fs._enemy_attack({"enemy": sam, "n": 10, "blocked": false, "part": "", "hit": 0, "hits": 1})
	for k in 10:
		await t.create_timer(0.08).timeout
		_shot(root, out + "/samurai_in_%d.png" % k)
	await t.create_timer(1.0).timeout
	# the swing of the Iai charge, one shot every 0.1 s
	sam.intent = sam.def.moves[2]
	fs._refresh_all()
	await t.create_timer(2.0).timeout
	for hit in 3:
		var ev := {"enemy": sam, "n": 3, "blocked": false, "part": "", "hit": hit, "hits": 3}
		fs._enemy_attack(ev)
		for k in 6:
			await t.create_timer(0.1).timeout
			_shot(root, out + "/samurai_iai_%d_%d.png" % [hit, k])
		await t.create_timer(0.8).timeout
	await t.create_timer(1.0).timeout
	# the Retainer's three moves
	for k in 3:
		ret.intent = ret.def.moves[k]
		fs._refresh_all()
		await t.create_timer(0.6).timeout
		_shot(root, out + "/retainer_intent_%d.png" % k)
		fs._enemy_move_fx({"enemy": ret, "kind": ret.intent.kind, "move": ret.intent})
		for j in 4:
			await t.create_timer(0.3).timeout
			_shot(root, out + "/retainer_move_%d_%d.png" % [k, j])
		await t.create_timer(1.0).timeout
	# the throw of the bottle, one shot every 0.07 s
	ret.intent = ret.def.moves[0]
	fs._refresh_all()
	await t.create_timer(1.5).timeout
	fs._enemy_move_fx({"enemy": ret, "kind": "bottle", "move": ret.intent})
	for k in 16:
		await t.create_timer(0.07).timeout
		_shot(root, out + "/throw_%d.png" % k)
	await t.create_timer(1.5).timeout
	# the Deflect: three Essence flying at the Retainer, each cut out of the air
	var r: EnemyView = fs._views.get(ret)
	for k in 3:
		fs._deflect_comet(Vector2(700 + 60 * k, 780), r.hp_point(k), Elements.COLORS[["F", "W", "A"][k]])
		await t.create_timer(0.12).timeout
	await t.create_timer(0.3).timeout
	_shot(root, out + "/samurai_deflect.png")
	await t.create_timer(1.0).timeout
	fs._retainer_yields(ret)
	await t.create_timer(0.6).timeout
	_shot(root, out + "/retainer_yield.png")
	t.quit()
