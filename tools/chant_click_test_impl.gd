extends RefCounted

var t: SceneTree


func _to_win(p: Vector2) -> Vector2:
	return t.root.get_final_transform() * p


func _motion(p: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = _to_win(p)
	mv.global_position = mv.position
	t.root.push_input(mv)
	await t.process_frame


func _click(p: Vector2) -> void:
	await _motion(p)
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.position = _to_win(p)
		b.global_position = b.position
		t.root.push_input(b)
		await t.process_frame
		await t.process_frame


func _drag(a: Vector2, b: Vector2) -> void:
	await _motion(a)
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = _to_win(a)
	d.global_position = d.position
	t.root.push_input(d)
	await t.process_frame
	for k in 12:
		await _motion(a.lerp(b, (k + 1) / 12.0))
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = _to_win(b)
	u.global_position = u.position
	t.root.push_input(u)
	await t.process_frame
	await t.process_frame


func _check(fs, label: String) -> int:
	var fails := 0
	fs.chant_idx.clear()
	fs._chant_changed()
	await t.create_timer(1.0).timeout
	# 1) click bag balls into the chant
	for k in 3:
		var uid: int = fs.fight.player.stock[k].uid
		await _click(fs._bag_icons[uid].get_global_rect().get_center())
		await t.create_timer(0.7).timeout
	print(label, ": after 3 bag clicks, chant ", fs.chant_idx)
	if fs.chant_idx.size() != 3:
		fails += 1
	# 2) what is under each of the 3 filled slots?
	var slots: Array = fs._chant_row.get_children().filter(func(c): return c is Panel)
	for k in 3:
		await _motion(slots[k].get_global_rect().get_center())
		var hc = t.root.gui_get_hovered_control()
		print(label, ": slot ", k, " hovered ", hc, " is slot/child: ", hc == slots[k] or (hc != null and slots[k].is_ancestor_of(hc)))
	for k in slots.size():
		await _motion(slots[k].get_global_rect().get_center())
		var hk = t.root.gui_get_hovered_control()
		var okk: bool = hk == slots[k] or (hk != null and slots[k].is_ancestor_of(hk))
		if not okk:
			print(label, ": SLOT ", k, " of ", slots.size(), " is covered by ", hk, " ", hk.get_path() if hk != null else "")
			fails += 1
	# 3) click a filled slot: the ball goes back to the bag
	await _click(slots[0].get_global_rect().get_center())
	await t.create_timer(0.7).timeout
	print(label, ": after clicking slot 0, chant ", fs.chant_idx)
	if fs.chant_idx.size() != 2:
		fails += 1
	# 4) drag the last chant ball down to the bag
	slots = fs._chant_row.get_children().filter(func(c): return c is Panel)
	var from: Vector2 = slots[1].get_global_rect().get_center()
	await _drag(from, Vector2(from.x, 1010.0))
	await t.create_timer(0.8).timeout
	print(label, ": after dragging slot 1 to the bag, chant ", fs.chant_idx)
	if fs.chant_idx.size() != 1:
		fails += 1
	return fails


func run(p_t: SceneTree) -> void:
	t = p_t
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://chant_click_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.4).timeout
	m.start_run()
	await t.create_timer(0.4).timeout
	m.current.chosen.emit(0)
	await t.create_timer(4.6).timeout
	var fails := 0
	m._overlay.node_chosen.emit(m.run.choices()[0])
	await t.create_timer(1.5).timeout
	m._overlay.confirmed.emit()
	await t.create_timer(10.5).timeout  # (the stage is cleared, the set is brought in)
	var fs = m.current
	print("fight screen after arrival: hud ", fs._hud_shift, " busy ", fs.busy)
	fails += await _check(fs, "stage-flow fight")
	# play a whole turn (chant two balls, speak them, Release), then try again in turn 2
	fs.chant_idx.clear()
	fs._add_stock_index(0)
	fs._add_stock_index(1)
	await t.create_timer(0.8).timeout
	fs._on_primary()  # Chant
	var w0 := 0.0
	while (fs.busy or fs.phase != "spells") and w0 < 15.0:
		await t.create_timer(0.25).timeout
		w0 += 0.25
	print("phase ", fs.phase, " busy ", fs.busy)
	fs._damage_step()  # Release
	await t.create_timer(1.0).timeout
	w0 = 0.0
	while (fs.busy or fs.phase != "build") and w0 < 40.0:
		await t.create_timer(0.5).timeout
		w0 += 0.5
	print("turn ", fs.fight.turn, " phase ", fs.phase, " busy ", fs.busy, " over ", fs.fight.over)
	fails += await _check(fs, "turn 2")
	# a fight on a fresh stage (no walk): Continue / event fights
	var run2 := RunState.new()
	run2.setup(root.get_node("GameData").db, save.unlocked_spells(), save.unlocked_artifacts(), 7)
	var fs2 := FightScreen.new()
	fs2.setup(run2, run2.make_fight(["greenseer", "rolling_bear", "yin_yang_clone"]))
	fs2.stage_flow = true
	m.current.queue_free()
	root.add_child(fs2)
	await t.create_timer(3.0).timeout
	fails += await _check(fs2, "fresh-stage fight")
	print("RESULT: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	t.quit()
