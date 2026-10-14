extends RefCounted


func _shot(t: SceneTree, name: String) -> void:
	await t.process_frame
	t.root.get_texture().get_image().save_png("C:/temp/sf_%s.png" % name)


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://stage_flow_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m.current.chosen.emit(0)  # the keepsake
	await t.create_timer(4.6).timeout
	await _shot(t, "1_map")
	print("current: ", m.current, " overlay: ", m._overlay)
	var run = m.run
	var col: int = run.choices()[0]
	m._overlay.node_chosen.emit(col)
	await t.create_timer(0.3).timeout
	await _shot(t, "2a_encounter")
	await t.create_timer(2.2).timeout
	await _shot(t, "2b_clearing")
	var st = m.current.get_stage()
	print("clearing: ", st.is_clearing(), " clear: ", st.is_clear())
	await t.create_timer(0.5).timeout
	print("after node: current ", m.current, " overlay ", m._overlay, " kind ", run.current_kind())
	m._overlay.confirmed.emit()  # begun at ~3 s: too early, the stage is still being cleared
	await t.create_timer(1.0).timeout
	var fs0 = m.current
	print("early begin: new screen ", fs0, " stage clearing ", fs0.get_stage().is_clearing(), " clear ", fs0.get_stage().is_clear(), " busy ", fs0.busy)
	await _shot(t, "3a_after_begin")
	await t.create_timer(2.0).timeout
	print("t+6: clearing ", fs0.get_stage().is_clearing(), " clear ", fs0.get_stage().is_clear(), " hud ", fs0._hud_shift)
	await _shot(t, "3b_bringing")
	await t.create_timer(2.0).timeout
	await _shot(t, "3c_bringing")
	await t.create_timer(3.0).timeout
	await _shot(t, "4_fight")
	var fs = m.current
	print("fight screen: ", fs, " hud shift ", fs._hud_shift, " busy ", fs.busy)
	# win it
	for e in fs.fight.enemies:
		e.elements.clear()
	fs.fight.over = true
	fs.fight.won = true
	fs._finish()
	await t.create_timer(1.5).timeout
	await _shot(t, "5_victory_sign")
	await t.create_timer(2.5).timeout
	await _shot(t, "6_hud_down")
	await t.create_timer(1.5).timeout
	await _shot(t, "7_rewards")
	print("after win: current ", m.current, " overlay ", m._overlay)
	var ch = m._overlay
	if ch is ChoiceScreen:
		ch.chosen.emit(-1)
	await t.create_timer(1.0).timeout
	m._open_spellbook()
	await t.create_timer(0.6).timeout
	await _shot(t, "7b_spellbook")
	m._book_overlay.closed.emit()
	await t.create_timer(1.8).timeout
	await _shot(t, "8_map_again")
	print("after rewards: overlay ", m._overlay)
	t.quit()
