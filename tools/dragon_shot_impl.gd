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
	var f := run.make_fight(["wyvern_head", "wyvern_tail"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var head: EnemyState = f.enemies[0]
	var tail: EnemyState = f.enemies[1]
	_shot(root, out + "/wyvern_idle.png")
	# the wing over the head, then over the tail
	for who in [head, tail]:
		f.wing_fold = who.def.dragon
		head.winged = who == head
		tail.winged = who == tail
		fs._sync_views()
		await t.create_timer(1.2).timeout
		_shot(root, out + "/wyvern_wing_%s.png" % who.def.dragon)
	head.winged = false
	tail.winged = false
	await t.create_timer(1.0).timeout
	# every move of each part: the intent shown, then the move acted out
	for who in [head, tail]:
		var moves: Array = who.def.moves
		for i in moves.size():
			who.intent = moves[i]
			fs._sync_views()
			fs._refresh_all()
			await t.create_timer(1.2).timeout
			_shot(root, out + "/wyvern_%s_%d.png" % [who.def.dragon, i])
			fs._views[who].creature.dragon_fx()
			for k in 3:
				await t.create_timer(0.3).timeout
				_shot(root, out + "/wyvern_%s_%d_fx%d.png" % [who.def.dragon, i, k])
			await t.create_timer(1.0).timeout
	# the Fireball between them
	f._do_move(head, head.def.moves[2])
	fs._sync_views()
	await t.create_timer(1.5).timeout
	_shot(root, out + "/wyvern_fireball.png")
	print("done")


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)
