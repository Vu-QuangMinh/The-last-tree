extends RefCounted
## Two fights in a row on the Puppet Stage (the real flow: map, encounter board, Begin, fight, win, rewards, map, encounter board, Begin, fight):
## after each one the HP text, the HP bar, the spell cards and the artifacts' frame must stand where they stand in a first fight; the Leaves counter stays hidden.

var t: SceneTree
var out := ""
var fails := 0


func _shot(name: String) -> void:
	await t.process_frame
	t.root.get_texture().get_image().save_png("%s/cyc_%s.png" % [out, name])


func _report(fs, label: String) -> Dictionary:
	var d := {"hp_label": fs._hp_label.global_position, "hp_bar": fs._hp_bar.global_position, "heart": fs._heart.global_position,
		"cards": fs._spell_row.get_global_rect().position.x if fs._spell_row.get_child_count() > 0 else -1.0,
		"card0": (fs._cards[0].global_position if fs._cards.size() > 0 else Vector2.ZERO), "chant": fs._chant_panel.global_position,
		"arts": fs._arts_frame.global_position, "menu": Vector2.ZERO, "amber": []}
	for n in t.get_nodes_in_group("amber_counter"):
		d.amber.append(n.visible)
	print(label, ": ", d)
	return d


func _same(a: Dictionary, b: Dictionary, label: String) -> void:
	for k in ["hp_label", "hp_bar", "heart", "chant", "arts"]:
		if a[k].distance_to(b[k]) > 2.0:
			fails += 1
			print("  MISMATCH ", label, " ", k, ": ", a[k], " vs ", b[k])
	if d_visible(b):
		fails += 1
		print("  MISMATCH ", label, ": the Leaves counter is visible ", b.amber)


func d_visible(d: Dictionary) -> bool:
	return d.amber.any(func(v): return v)


func _to_fight(m, n: int) -> void:
	var run = m.run
	m._overlay.node_chosen.emit(run.choices()[0])
	await t.create_timer(1.0).timeout
	await _shot("enc%d_board" % n)
	await t.create_timer(11.0).timeout
	m._overlay.confirmed.emit()
	await t.create_timer(3.0).timeout


func run(p_t: SceneTree) -> void:
	t = p_t
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://fight_cycle_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m.current.chosen.emit(0)
	await t.create_timer(4.6).timeout
	await _to_fight(m, 1)
	var fs = m.current
	var first := _report(fs, "fight 1")
	await _shot("fight1")
	for e in fs.fight.enemies:
		e.elements.clear()
	fs.fight.over = true
	fs.fight.won = true
	fs._finish()
	await t.create_timer(5.0).timeout
	var mid := _report(fs, "fight 1 after the win (HUD sunk)")
	await _shot("after_win")
	for k in 8:
		var ov = m._overlay
		print("  overlay: ", ov, " ", ov.get_class() if ov != null else "-")
		await _shot("overlay_%d" % k)
		if ov is MapScreen:
			break
		if ov is ChoiceScreen:
			ov.chosen.emit(-1)
		elif ov is MessageScreen:
			ov.pressed.emit(0)
		await t.create_timer(2.5).timeout
	for id in ["meteor", "hurricane"]:
		if not (id in m.run.loadout) and m.run.loadout.size() < m.run.active_slots():
			m.run.spellbook.append(id)
			m.run.loadout.append(id)
	await _to_fight(m, 2)
	var fs2 = m.current
	var second := _report(fs2, "fight 2")
	await _shot("fight2")
	print("spell row: ", fs2._spell_row.get_global_rect(), " children ", fs2._spell_row.get_children().map(func(c): return c.get_global_rect()), " scales ", fs2._cards.map(func(c): return c.scale))
	_same(first, second, "fight 2 vs fight 1")
	print("RESULT: ", "OK" if fails == 0 else "%d MISMATCHES" % fails)
	t.quit()
