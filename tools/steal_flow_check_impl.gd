extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://steal_flow.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["veiled_eyes"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var e: EnemyState = f.enemies[0]
	e.phase = 2
	e.reset_hp(String(e.def.hp2))
	fs._sync_views()
	await t.create_timer(6.0).timeout  # (the unveiling)
	var t0 := Time.get_ticks_msec()
	var shots := t.create_timer(0.0)
	var done := [false]
	(func():
		await f._steal_spell(e)
		done[0] = true).call()
	var k := 0
	while not done[0] and Time.get_ticks_msec() - t0 < 40000:
		await t.create_timer(0.7).timeout
		root.get_texture().get_image().save_png("%s/flow_%02d.png" % [out, k])
		k += 1
	print("STEAL total sec ", (Time.get_ticks_msec() - t0) / 1000.0, " done ", done[0], " cocoons ", f.enemies.filter(func(x): return x.id == "spider_cocoon").size())
	t.quit()
