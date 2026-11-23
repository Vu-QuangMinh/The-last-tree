extends RefCounted
## The main game with the new rules (2026-11-22): a run starts, the first room is entered, the loadout board, then the
## main game's own fight screen (FightScreen) on a MarbleBridge; the bot chants and casts until it is over, the rewards
## come, the run goes on. Screenshots to the out dir. FLOW_WIN=1: the enemies drop to 1 HP after the first chant.


func _shot(t: SceneTree, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	t.root.get_texture().get_image().save_png(out + "/mf_%s.png" % name)


func _settle(t: SceneTree, fs: FightScreen) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(fs) and (fs._launching > 0 or fs._rolling_in > 0 or fs.busy) and Time.get_ticks_msec() - t0 < 8000:
		await t.process_frame
	await t.create_timer(0.4).timeout


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://main_marbles_flow.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m._overlay.chosen.emit(0)
	await t.create_timer(4.6).timeout
	await _shot(t, out, "1_map")
	var rs = m.run
	print("FLOW cards: ", rs.loadout, " bag: ", rs.marble_bag.size())
	m._overlay.node_chosen.emit(rs.choices()[0])
	await t.create_timer(3.0).timeout
	await _shot(t, out, "2_before")
	if m._overlay != null and m._overlay.has_signal("confirmed"):
		m._overlay.confirmed.emit()
	await t.create_timer(5.0).timeout
	var fs = m.current
	print("FLOW screen: ", fs, " fight: ", fs.fight.get_script().get_global_name() if fs is FightScreen else "-")
	await _shot(t, out, "3_fight")
	if fs is FightScreen and fs.fight is MarbleBridge:
		var f: MarbleBridge = fs.fight
		for turn in 30:
			if f.over or not is_instance_valid(fs):
				break
			await _settle(t, fs)
			print("FLOW turn %d: phase %s, busy %s, you %d, foes %s, stock %d" % [turn, fs.phase, fs.busy, f.player.hp, f.enemies.map(func(e): return e.get_meta("hp")), f.player.stock.size()])
			var st: Array = f.player.stock
			for el in ["F", "W", "A", "?"]:
				for i in st.size():
					if String(st[i].el) == el and fs.chant_idx.size() < 10:
						fs._add_stock_index(i)
			await t.create_timer(0.6).timeout
			await fs._on_cast()
			if turn == 0 and OS.get_environment("FLOW_WIN") != "":
				for foe in f.m.foes:
					foe.hp = 1
			for s in f.loadout.duplicate():
				while f.charges.get(s.id, 0) > 0 and not f.over and is_instance_valid(fs):
					var card: SpellCard = fs._card_for(String(s.id))
					if card == null:
						break
					if String(s.effects[0].target) == "target":
						t.create_timer(0.6).timeout.connect(func(): if is_instance_valid(fs) and fs.aiming: fs._finish_aim(f.target_candidates()[0]))
					await fs._on_card_clicked(card)
			if turn == 0:
				await _shot(t, out, "4_cast")
			if f.over or not is_instance_valid(fs):
				break
			await _settle(t, fs)
			if fs.phase == "spells":
				await fs._on_end_turn()  # (Pass; when every card was cast the turn has ended by itself)
		print("FLOW fight over: ", f.over, " won: ", f.won, " turns ", f.turn, " hp ", rs.player.hp)
		await t.create_timer(4.0).timeout
		await _shot(t, out, "5a_after")
	await t.create_timer(3.0).timeout
	await _shot(t, out, "5_reward")
	print("FLOW after: hp ", rs.player.hp, " amber ", rs.amber, " bag ", rs.marble_bag.size(), " current ", m.current, " overlay ", m._overlay)
