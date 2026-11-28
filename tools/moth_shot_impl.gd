extends RefCounted
## See tools/moth_shot.gd.


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://moth_shot.json")
	save.data.settings["theme"] = "puppet"
	var m: Main = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	var ids: Array = Array(OS.get_environment("SHOT_ENEMIES").split(",")) if OS.get_environment("SHOT_ENEMIES") != "" else ["hush_moth", "iceling"]
	m._start_fight(ids)
	if ids[0] != "hush_moth":
		await t.create_timer(6.0).timeout
		root.get_texture().get_image().save_png(out + "/e1_%s.png" % ids[0])
		if ids[0] == "bramble_matron":  # (both hedges cut down: her bar shows, she will call them back)
			var br0: MarbleBridge = m.current.fight
			for x in br0.m.foes:
				if x.id == "briar_hedge":
					br0.m._hit(x, 99)
			await br0._b_play(br0._b_take(), false)
			for x in br0.m.foes:
				if x.id == "bramble_matron":
					br0.m._plan(x)
			br0._b_sync()
			m.current._h_hud._sync_views()
			m.current._h_hud._refresh_all()
			await t.create_timer(2.0).timeout
			root.get_texture().get_image().save_png(out + "/e2_%s_exposed.png" % ids[0])
			for x in br0.m.foes:  # (she calls them back: let down on their ropes)
				if x.id == "bramble_matron":
					br0.m._act(x, x.intent)
			br0._b_play(br0._b_take(), true)
			await t.create_timer(0.5).timeout
			root.get_texture().get_image().save_png(out + "/e3_%s_lowering.png" % ids[0])
			await t.create_timer(2.0).timeout
			root.get_texture().get_image().save_png(out + "/e4_%s_back.png" % ids[0])
		return
	await t.create_timer(6.0).timeout
	var br: MarbleBridge = m.current.fight
	print("moth: hp ", br.m.foes[0].hp, "/", br.m.foes[0].max_hp, " flying ", br.m.foes[0].es.flying)
	root.get_texture().get_image().save_png(out + "/m1_flying.png")
	for k in StageFight.FLY_HITS:
		br.m._hit(br.m.foes[0], 1)
	await br._b_play(br._b_take(), false)
	await t.create_timer(1.5).timeout
	print("moth: hp ", br.m.foes[0].hp, " flying ", br.m.foes[0].es.flying, " stun ", br.m.foes[0].stun)
	root.get_texture().get_image().save_png(out + "/m2_fallen.png")
