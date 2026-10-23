extends RefCounted


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
	var f := run.make_fight(["samurai_retainer", "samurai"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.5).timeout
	root.get_texture().get_image().save_png(out + "/samurai_stage.png")
	# his three stances (the drawn sword until the pictures come)
	var sam: EnemyState = f.enemies[1]
	for k in 3:
		sam.intent = sam.def.moves[k]
		fs._refresh_all()
		await t.create_timer(0.4).timeout
		var sv: EnemyView = fs._views.get(sam)
		var rr: Rect2 = sv.puppet_global_rect().grow(120)
		root.get_texture().get_image().get_region(Rect2i(rr)).save_png("%s/samurai_pose_%s.png" % [out, sam.intent.pose])
	# the Deflect: three Essence flying at the Retainer, each cut out of the air
	var r: EnemyView = fs._views.get(f.enemies[0])
	for k in 3:
		fs._deflect_comet(Vector2(700 + 60 * k, 780), r.hp_point(k), Elements.COLORS[["F", "W", "A"][k]])
		await t.create_timer(0.12).timeout
	await t.create_timer(0.1).timeout
	root.get_texture().get_image().save_png(out + "/samurai_deflect_a.png")
	await t.create_timer(0.15).timeout
	root.get_texture().get_image().save_png(out + "/samurai_deflect_b.png")
	await t.create_timer(0.2).timeout
	root.get_texture().get_image().save_png(out + "/samurai_deflect_c.png")
	await t.create_timer(1.0).timeout
	fs._speech(f.enemies[1], "No! Tasuke!", 2.0)
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/samurai_speech.png")
	t.quit()
