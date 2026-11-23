extends RefCounted


func _shot(t: SceneTree, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	t.root.get_texture().get_image().save_png(out + "/wg_%s.png" % name)


func _card_words(fs: FightScreen) -> String:
	var c: SpellCard = fs._card_for("water_gun")
	return String(c._rules.text) if c != null and c._rules != null else "?"


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://water_gun_shot.json")
	save.data.settings["theme"] = "puppet"
	var rs := RunState.new()
	rs.setup(root.get_node("GameData").db, [], [], 7)
	rs.loadout = ["splash", "water_gun"]
	rs.spellbook = rs.loadout.duplicate()
	var f := rs.make_fight(["iceling"]) as MarbleBridge
	# the marbles in your row: W W W W F (Splash twice over, Water Gun once)
	f.m.hand.clear()
	for k in 5:
		f.m._uid += 1
		f.m.hand.append({"c": "WWWWF"[k], "sym": "", "src": -1, "uid": f.m._uid, "frozen": false, "hidden": false})
	f._b_sync()
	var fs := FightScreen.new()
	fs.setup(rs, f)
	root.add_child(fs)
	await t.create_timer(6.0).timeout
	var t0 := Time.get_ticks_msec()
	while (fs._launching > 0 or fs._rolling_in > 0 or fs.busy) and Time.get_ticks_msec() - t0 < 8000:
		await t.process_frame
	# chant W W F (Water Gun) then W W (Splash)
	for el in ["W", "W", "F", "W", "W"]:
		for i in f.player.stock.size():
			if String(f.player.stock[i].el) == el and not (i in fs.chant_idx):
				fs._add_stock_index(i)
				break
	await t.create_timer(0.6).timeout
	await fs._on_cast()
	print("WG charges: ", f.charges)
	await t.create_timer(0.4).timeout
	print("WG before Splash: ", _card_words(fs))
	await _shot(t, out, "1_before")
	await fs._on_card_clicked(fs._card_for("splash"))
	await t.create_timer(0.6).timeout
	print("WG after Splash: ", _card_words(fs))
	await _shot(t, out, "2_after_splash")
	t.create_timer(0.6).timeout.connect(func(): if fs.aiming: fs._finish_aim(0))
	await fs._on_card_clicked(fs._card_for("water_gun"))
	print("WG after Water Gun: enemy HP ", f.enemies.map(func(e): return e.get_meta("hp")))
