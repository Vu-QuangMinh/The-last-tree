extends RefCounted


func _shot(t: SceneTree, out: String, name: String) -> void:
	await t.process_frame
	t.root.get_texture().get_image().save_png("%s/enc_%s.png" % [out, name])


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://stage_enc_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(4.0).timeout  # (the drapes are drawn first)
	m._overlay.chosen.emit(0)  # the keepsake
	await t.create_timer(4.6).timeout
	var run = m.run
	var col: int = run.choices()[0]
	m._overlay.node_chosen.emit(col)
	await t.create_timer(0.4).timeout
	await _shot(t, out, "1_board")
	for k in 8:  # (the enemies are let down on their ropes: row y per half second)
		await t.create_timer(0.5).timeout
		print("enemy row y ", m.current._enemy_row.position.y, " drop ", m.current._enemy_drop)
	await _shot(t, out, "1b_drop")
	await t.create_timer(2.0).timeout  # (the stage is still clearing and bringing the new set: Begin is pressed early on purpose)
	var fs = m.current
	m._overlay.confirmed.emit()
	await t.create_timer(0.4).timeout
	await _shot(t, out, "2a_early_begin")
	await t.create_timer(12.0).timeout
	print("after 8 s: current ", fs.get_class(), " hold ", fs.hold_hud, " ready ", fs._arrival_ready, " busy ", fs.busy, " hud ", fs._hud_shift, " overlay ", m._overlay)
	await _shot(t, out, "2_set_in")
	await t.create_timer(0.25).timeout
	await _shot(t, out, "3_cards_fly")
	await t.create_timer(0.35).timeout
	await _shot(t, out, "3b_cards_fly")
	await t.create_timer(1.5).timeout
	await _shot(t, out, "4_fight")
	print("fight: hud ", fs._hud_shift, " busy ", fs.busy, " cards ", fs._cards.size(), " alphas ", fs._cards.map(func(c): return c.modulate.a), " overlay ", m._overlay)
	t.quit()
