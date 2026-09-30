extends RefCounted
## Drives the real game screens like a player would, at high speed, and snapshots key moments.

var tree: SceneTree
var out := ""
var main: Node
var shots := 0
var log_lines: Array = []
var fights := 0
var last_screen := ""


func run(t: SceneTree, p_out: String) -> void:
	tree = t
	out = p_out
	DirAccess.make_dir_recursive_absolute(out)
	tree.root.get_node("SaveManager").use_test_file("user://ui_playtest_save.json")
	Engine.time_scale = 12.0
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	var steps := 0
	var ended := false
	while steps < 20000 and not ended:
		steps += 1
		await tree.process_frame
		var cur: Control = main.current
		var overlay: Node = main.overlay_layer
		if not is_instance_valid(cur):
			continue
		var name: String = cur.get_script().get_global_name()
		if name != last_screen:
			log_lines.append("-> " + name)
			last_screen = name
		match name:
			"MenuScreen":
				if fights > 0:
					ended = true
				else:
					await _snap("menu")
					cur.play.emit()
			"ChoiceScreen":
				await _wait_frames(3)
				if shots < 30:
					await _snap("choice_" + cur.title.to_snake_case())
				cur.chosen.emit(0)
			"MapScreen":
				await _wait_frames(3)
				var run: RunState = main.run
				if run.row == -1:
					await _snap("map_act%d" % run.act)
				cur.node_chosen.emit(_pick_col(run))
			"LoadoutScreen":
				await _wait_frames(3)
				if main.run.current_node().type == "boss":
					await _snap("loadout_boss_act%d" % main.run.act)
				cur.confirmed.emit()
			"FightScreen":
				await _play_fight(cur)
			"ShopScreen":
				await _wait_frames(3)
				await _snap("shop")
				for i in cur.stock.size():
					if cur.stock[i].kind == "spell" and run_amber_ok(cur, i):
						cur._buy(i)
						break
				cur.leave.emit()
			"MessageScreen":
				await _wait_frames(3)
				await _snap("message_" + cur.title.to_snake_case().left(30))
				log_lines.append("   " + cur.title + " | " + cur.body.replace("\n", " "))
				if cur.title.begins_with("The last tree"):
					ended = true
				else:
					cur.pressed.emit(0)
	print("\n".join(log_lines))
	print("UI playtest done: %d fights, %d screenshots" % [fights, shots])
	Engine.time_scale = 1.0
	tree.quit()


func run_amber_ok(shop, i: int) -> bool:
	return shop.run.amber >= shop.stock[i].price


func _pick_col(run: RunState) -> int:
	var opts := run.choices()
	var low := run.player.hp < run.player.max_hp * 0.5
	var best: int = opts[0]
	var best_s := -99.0
	for c in opts:
		var ty: String = run.map[run.row + 1][c].type
		var s: float = {"fight": 2.0, "elite": -2.0 if low else 1.5, "rest": 3.0 if low else 0.0, "treasure": 2.5, "boss": 0.0, "event": 2.2, "shop": 2.4}[ty]
		if s > best_s:
			best_s = s
			best = c
	return best


func _play_fight(fs: FightScreen) -> void:
	fights += 1
	var f := fs.fight
	var hp0: float = f.player.hp
	var label: String = ", ".join(f.enemies.map(func(e): return e.name))
	var snaps := 0
	var frames := 0
	while is_instance_valid(fs) and not f.over:
		await tree.process_frame
		frames += 1
		if frames % 3000 == 0:
			print("STALL? fight %d turn %d busy=%s phase=%s aiming=%s mode=%s pick=%s move=%s charges=%s released=%s step=%d" % [fights, f.turn, fs.busy, fs.phase, fs.aiming, fs.chant_mode, fs.pick_view != null, fs.move_view != null, f.charges, fs._released, fs._step_pos])
			print("   log: ", f.lines.slice(-6))
		if frames > 30000:
			print("GIVING UP on fight %d" % fights)
			tree.quit()
			return
		if fs.aiming:
			if snaps < 2 and fights <= 3:
				snaps += 1
				await _snap("fight%d_arrow" % fights)
			fs._finish_aim(fs.aim_cands[0])
			continue
		if fs.move_view != null:
			fs._cancel()
			continue
		if fs.chant_mode != "":
			if snaps < 3 and fights <= 4:
				snaps += 1
				await _snap("fight%d_chant_%s" % [fights, fs.chant_mode])
			fs._chant_done.emit(fs.chant_i)
			continue
		if fs.pick_view != null:
			fs._pick_done.emit(fs.pick_view.pick_i)
			continue
		if fs.busy:
			continue
		if fs.phase == "build":
			var chant := _best_chant(f)
			if chant == "":
				fs._on_end_turn()
				continue
			for ch in chant:
				fs._add_element(ch)
			await _wait_frames(2)
			if fights <= 2 or f.enemies.any(func(e): return e.is_boss):
				await _snap("fight%d_t%d_preview" % [fights, f.turn])
			fs._on_cast()
			continue
		# spells phase: cast every living spell, then end the turn
		var live := fs._cards.filter(func(c): return c.charges > 0)
		if live.is_empty():
			continue  # the damage step runs by itself
		if fights <= 2 and f.turn == 1 and snaps == 0:
			await _wait_frames(6)
			await _snap("fight%d_alive" % fights)
		fs._on_card_clicked(live[0])
	log_lines.append("   fight %d vs %s: %s, HP %d -> %d, %d turns" % [fights, label, "won" if f.won else "LOST", hp0, f.player.hp, f.turn])
	for i in 400:
		await tree.process_frame
		if main.current != fs:
			break


## Greedy + random search over chants using the game's own preview.
func _best_chant(f: Fight) -> String:
	var pool := ""
	for s in f.player.stock:
		if not s.frozen:
			pool += s.el
	if pool == "":
		return ""
	var slots := mini(f.player.chant_slots(), pool.length())
	var best := ""
	var best_s := 0.0
	var rng := RandomNumberGenerator.new()
	for i in 300:
		var arr := Array(pool.split(""))
		arr.shuffle()
		var n := rng.randi_range(1, slots)
		var c := "".join(arr.slice(0, n))
		var p := f.preview(c)
		var sc := 0.0
		for e in p.removed:
			sc += p.removed[e]
		sc += p.dies.size() * 3.0
		for id in p.spells:
			sc += p.spells[id] * 1.5
		sc -= n * 0.05
		if sc > best_s:
			best_s = sc
			best = c
	return best


func _wait_frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _snap(name: String) -> void:
	if shots >= 40:
		return
	await _wait_frames(4)
	shots += 1
	var img := tree.root.get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out, shots, name])
