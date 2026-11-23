extends RefCounted
## Drives FightScreen on a MarbleBridge: chant the marbles, cast every awake card, end the turn; screenshots.


func _shot(t: SceneTree, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	t.root.get_texture().get_image().save_png(out + "/bf_%s.png" % name)


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://bridge_flow_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, [], [], 7)
	var ids: Array = Array(OS.get_environment("BF_ENEMIES").split(",")) if OS.get_environment("BF_ENEMIES") != "" else ["iceling", "iceling"]
	if OS.get_environment("BF_CARDS") != "":
		rs.loadout = Array(OS.get_environment("BF_CARDS").split(","))
		rs.spellbook = rs.loadout.duplicate()
	var f := rs.make_fight(ids)
	print("BF fight: ", f.get_script().get_global_name(), " cards ", f.loadout.map(func(s): return s.id), " stock ", f.player.stock.map(func(s): return s.el))
	var real_anim: Callable
	var fs := FightScreen.new()
	fs.setup(rs, f)
	root.add_child(fs)
	real_anim = f.anim
	f.anim = func(ev: Dictionary) -> void:
		print("BF   anim ", ev.type, " ts=", Engine.time_scale)
		await real_anim.call(ev)
		print("BF   anim done ", ev.type)
	await t.create_timer(6.0).timeout
	await _shot(t, out, "1_start")
	for turn in 3:
		if f.over:
			break
		var t0 := Time.get_ticks_msec()
		while (fs._launching > 0 or fs._rolling_in > 0 or fs.busy) and Time.get_ticks_msec() - t0 < 8000:
			await t.process_frame
		await t.create_timer(0.5).timeout
		print("BF turn %d ready (%.1fs wait)" % [turn, (Time.get_ticks_msec() - t0) / 1000.0])
		var st: Array = f.player.stock
		var order := []
		for el in ["F", "W", "A", "?"]:
			for i in st.size():
				if String(st[i].el) == el:
					order.append(i)
		for i in order:
			fs._add_stock_index(i)
			await t.create_timer(0.15).timeout
		await t.create_timer(0.8).timeout
		if turn == 0:
			await _shot(t, out, "2_chant_built")
		await fs._on_cast()
		print("BF charges: ", f.charges)
		await _shot(t, out, "4b_after_chant_t%d" % turn)
		var old_uids: Array = f.player.stock.map(func(x): return x.uid)
		for s in f.loadout.duplicate():
			while f.charges.get(s.id, 0) > 0 and not f.over:
				var card: SpellCard = fs._card_for(String(s.id))
				if card == null:
					break
				if String(s.effects[0].op) == "strike" and not FileAccess.file_exists(out + "/bf_4_hit.png"):
					t.create_timer(1.0).timeout.connect(func(): _shot(t, out, "3_spell_fx"))
					t.create_timer(1.45).timeout.connect(func(): _shot(t, out, "4_hit"))
				print("BF cast ", s.id)
				if String(s.id) == "tail_wind":
					t.create_timer(0.5).timeout.connect(func(): _shot(t, out, "tail_wind_%d" % turn))
					print("BF tail: next draw before ", f.m.next_draw_known().map(func(x): return x.c))
				if String(s.effects[0].target) == "target":
					t.create_timer(0.6).timeout.connect(func(): if fs.aiming: fs._finish_aim(f.target_candidates()[0]))
				await fs._on_card_clicked(card)
				if String(s.id) == "tail_wind":
					print("BF tail: next draw after ", f.m.next_draw_known().map(func(x): return x.c), " tray ", fs._pending.map(func(x): return x.el))
				for s2 in f.loadout:
					if String(s2.id) == "water_gun" and is_instance_valid(fs._card_for("water_gun")):
						print("BF   water gun card says: ", String(fs._card_for("water_gun")._rules.text).left(60))
				print("BF cast done ", s.id, " foes ", f.enemies.map(func(e): return e.get_meta("hp")))
				await t.create_timer(0.3).timeout
		print("BF after casts: hp ", f.enemies.map(func(e): return e.get_meta("hp")))
		if f.over:
			break
		if turn == 0:
			t.create_timer(1.2).timeout.connect(func(): _shot(t, out, "5_enemy_turn"))
		if fs.phase == "spells":
			await fs._on_end_turn()  # (Pass; when every card was cast the turn has ended by itself)
		else:
			await t.create_timer(3.0).timeout
		var came: Array = f.player.stock.filter(func(x): return not (x.uid in old_uids)).map(func(x): return x.el)
		print("BF turn ended (by itself or Pass), new marbles ", came)
		await t.create_timer(2.5).timeout
		if turn == 0:
			await _shot(t, out, "6_next_turn")
		print("BF   machine shows ", f.player.next_draw.map(func(d): return d.el))
		print("BF   your Weakened %d, intents %s" % [f.player.weak, f.enemies.map(func(e): return [e.id, e.intent.get("kind", ""), e.intent.get("n", 0)])])
		print("BF turn %d done: you %d, foes %s, stock %s" % [turn, f.player.hp, f.enemies.map(func(e): return e.get_meta("hp")), f.player.stock.map(func(s): return s.el)])
	await _shot(t, out, "7_end")
