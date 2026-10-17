extends RefCounted

var t: SceneTree


func _min_gap(icons: Array) -> float:
	var g := 1e9
	for i in icons.size():
		for k in range(i + 1, icons.size()):
			var a: Control = icons[i]
			var b: Control = icons[k]
			if absf(a.position.y - b.position.y) < 20.0:
				g = minf(g, absf(a.position.x - b.position.x))
	return g


func run(p_t: SceneTree) -> void:
	t = p_t
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://fx_test_save.json")
	save.data.settings["theme"] = "puppet"
	var run := RunState.new()
	run.setup(root.get_node("GameData").db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var fs := FightScreen.new()
	fs.setup(run, run.make_fight(["greenseer", "rolling_bear", "yin_yang_clone"]))
	fs.stage_flow = true
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var fails := 0
	# 1) an enemy with no Essence left breaks at once
	var e0 = fs.fight.enemies[0]
	e0.elements.clear()
	await fs._anim({"type": "strike", "enemy": e0, "n": 1})
	var gone: bool = not fs._views.has(e0)
	print("dead enemy view removed right after its event: ", gone, " views now ", fs._views.size())
	if not gone:
		fails += 1
	# 2) bonus orbs (like Tailwind): fly into the tube and queue without overlapping
	var from: Vector2 = fs._spell_row.global_position + Vector2(300, 60)
	var ev := {"drawn": ["F", "W", "A", "F"], "eff": {"n": 4, "el": "random", "when": "next"}}
	var wait: float = fs._stash_flight(ev, from)
	for el in ["F", "W", "A", "F"]:
		fs.fight.player.next_draw.append({"el": el, "temp": false})
	var worst := 1e9
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int((wait + 2.0) * 1000.0):
		await t.process_frame
		var rolling: Array = fs._tube_icons.filter(func(c): return is_instance_valid(c) and c.has_meta("in_tube") and float(c.position.x) < 2000.0)
		worst = minf(worst, _min_gap(rolling))
	print("bonus orbs into the tube: smallest gap between two balls ", snappedf(worst, 0.1), " px (a ball is ", FightScreen.BAG_PX, " wide)")
	if worst < FightScreen.BAG_PX - 3.0:
		fails += 1
	# 3) next turn: the batch rolls out of the tube into the bag
	fs.chant_idx.clear()
	fs._add_stock_index(0)
	await t.create_timer(0.8).timeout
	fs._on_primary()
	await t.create_timer(1.2).timeout
	fs._damage_step()
	var worst2 := 1e9
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 14000:
		await t.process_frame
		var rolling2: Array = []
		for c in fs._stock_row.get_children():
			if c is ElementIcon and is_instance_valid(c) and c.has_meta("rolling") and c.position.x < PuppetSlotMachine.PORT_C.x - PuppetLayout.BAG_AT.x:  # (the ones still inside the machine are hidden behind its front)
				rolling2.append(c)
		if rolling2.size() > 1:
			worst2 = minf(worst2, _min_gap(rolling2))
	print("launch into the bag: smallest gap between two rolling balls ", snappedf(worst2, 0.1) if worst2 < 1e8 else "(no overlap possible)", " px")
	if worst2 < FightScreen.BAG_PX - 3.0:
		fails += 1
	# 4) the player's HP blocks break when the hit lands, not before
	var p = fs.fight.player
	var marks := {}
	p.hp = 30.0
	var e = fs.fight.enemies[0] if not fs.fight.enemies.is_empty() else null
	var before_pieces: int = fs._hp_bar._pieces.size()
	var start_ms := Time.get_ticks_msec()
	fs._enemy_attack({"enemy": e, "n": 20, "blocked": false})
	var broke_ms := -1
	var impact_ms := -1
	while Time.get_ticks_msec() - start_ms < 2500:
		await t.process_frame
		if broke_ms < 0 and fs._hp_bar._pieces.size() > before_pieces:
			broke_ms = Time.get_ticks_msec() - start_ms
		if impact_ms < 0 and fs._player_panel.modulate != Color.WHITE:
			impact_ms = Time.get_ticks_msec() - start_ms
	print("HP blocks broke at ", broke_ms, " ms, the hit (player flash) at ", impact_ms, " ms")
	print("RESULT: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	t.quit()
