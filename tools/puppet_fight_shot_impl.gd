extends RefCounted

func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://puppet_fight.png"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://puppet_shot_save.json")
	save.data.settings["theme"] = OS.get_environment("SHOT_THEME") if OS.get_environment("SHOT_THEME") != "" else "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var ids: Array = Array(OS.get_environment("SHOT_ENEMIES").split(",")) if OS.get_environment("SHOT_ENEMIES") != "" else ["greenseer", "yin_yang_clone", "rolling_bear"]
	var f := run.make_fight(ids)
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(6.0 if OS.get_environment("SHOT_THEME") == "" else 3.0).timeout
	if OS.get_environment("SHOT_PICK") != "":  # which control is under each chant slot?
		fs._add_stock_index(0)
		await t.create_timer(1.5).timeout
		print("chant at start: ", fs.chant_idx)
		fs.chant_idx.clear()
		fs._chant_changed()
		await t.create_timer(1.0).timeout
		for round in 3:
			var uid: int = fs.fight.player.stock[round].uid
			var bi: Control = fs._bag_icons[uid]
			var bc := bi.get_global_rect().get_center()
			await _click(root, t, bc)
			await t.create_timer(1.2).timeout
			print("after bag click ", round, ": chant ", fs.chant_idx)
		var s0: Control = fs._chant_row.get_child(0)
		await _click(root, t, s0.get_global_rect().get_center())
		await t.create_timer(1.0).timeout
		print("after clicking slot 0 (3 orbs): chant ", fs.chant_idx)
		s0 = fs._chant_row.get_child(0)
		await _click(root, t, s0.get_global_rect().get_center())
		await t.create_timer(1.0).timeout
		print("again slot 0: chant ", fs.chant_idx)
		s0 = fs._chant_row.get_child(0)
		await _click(root, t, s0.get_global_rect().get_center())
		await t.create_timer(1.0).timeout
		print("again slot 0 (last orb): chant ", fs.chant_idx)
		for k in 2:  # drag the first orb down onto the Bag, as a player does
			await _click(root, t, fs._bag_icons[fs.fight.player.stock[3 + k].uid].get_global_rect().get_center())
			await t.create_timer(1.2).timeout
		for k in 2:
			var sl: Control = fs._chant_row.get_child(0)
			var from := sl.get_global_rect().get_center()
			var goal := Vector2(from.x, 1012.0)
			await _drag(root, t, from, goal)
			await t.create_timer(1.0).timeout
			print("drag slot 0 onto the bag: chant ", fs.chant_idx)
		t.quit()
		return
		var r0: Rect2 = fs._chant_row.get_child(0).get_global_rect()
		print("slot0 rect ", r0, " slot1 rect ", fs._chant_row.get_child(1).get_global_rect())
		for gy in 5:
			var line := ""
			for gx in 7:
				var pt := r0.position + Vector2(r0.size.x * (gx + 0.5) / 7.0, r0.size.y * (gy + 0.5) / 5.0)
				var mv0 := InputEventMouseMotion.new()
				mv0.position = pt
				mv0.global_position = pt
				root.push_input(mv0)
				await t.process_frame
				var hc := root.gui_get_hovered_control()
				line += (str(hc.get_class()) + ":" + str(hc.name).left(12) if hc != null else "none") + " | "
			print("grid ", gy, ": ", line)
		for i in [0, 0]:
			var slot: Control = fs._chant_row.get_child(i)
			var c := slot.get_global_rect().get_center()
			var ev := InputEventMouseMotion.new()
			ev.position = c
			ev.global_position = c
			root.push_input(ev)
			await t.process_frame
			var dn := InputEventMouseButton.new()
			dn.button_index = MOUSE_BUTTON_LEFT
			dn.pressed = true
			dn.position = c
			dn.global_position = c
			root.push_input(dn)
			await t.process_frame
			print("slot ", i, " after press: _press=", fs._press, " busy=", fs.busy, " phase=", fs.phase, " row children=", fs._chant_row.get_child_count(), " slot valid=", is_instance_valid(slot))
			for step in (0 if i == 0 and fs.chant_idx.size() == 1 else 4):
				var mv := InputEventMouseMotion.new()
				mv.position = c + Vector2(0, -60.0 * (step + 1))
				mv.global_position = mv.position
				root.push_input(mv)
				await t.process_frame
			print("  dragging: ", is_instance_valid(fs._bdrag))
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.pressed = false
			up.position = c + Vector2(0, -240)
			up.global_position = up.position
			root.push_input(up)
			await t.create_timer(1.0).timeout
			print("  chant now: ", fs.chant_idx)
			if fs.chant_idx.size() < 2:
				fs._add_stock_index(fs.fight.player.stock.size() - 1 - fs.chant_idx.size())
				await t.create_timer(1.0).timeout
		t.quit()
		return
	if OS.get_environment("SHOT_KILL") != "":  # the first enemy is defeated: it breaks into pieces
		f.enemies[0].elements.clear()
		fs._sync_views()
		for k in 6:
			await t.create_timer(0.18).timeout
			_shot(root, out.replace(".png", "_k%d.png" % k))
		t.quit()
		return
	if OS.get_environment("SHOT_HOVER") != "":  # the hint over the first enemy's intent bubble
		fs.set_process(false)
		var chip: Control = fs._views[f.enemies[0]].intent_chip()
		fs._update_hover_info(1.0, chip.get_global_rect().get_center())
		fs._update_hover_info(1.0, chip.get_global_rect().get_center())
		await t.create_timer(0.5).timeout
	if OS.get_environment("SHOT_THEME") != "":
		_shot(root, out)
		t.quit()
		return
	_shot(root, out)
	# a spell's Essence for next turn: card -> pipe -> box
	var ev := {"drawn": ["A", "F"], "eff": {"temp": false}}
	fs._stash_flight(ev, Vector2(900, 700))
	for k in 3:
		await t.create_timer(0.45).timeout
		_shot(root, out.replace(".png", "_stash%d.png" % k))
	await t.create_timer(2.0).timeout
	# end the turn: the globe's balls fall into the box and everything rolls out into the bag
	fs._on_end_turn()
	await t.create_timer(7.6).timeout
	for k in 24:
		await t.create_timer(0.22).timeout
		_shot(root, out.replace(".png", "_turn%02d.png" % k))
	t.quit()


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)



func _click(root: Window, t: SceneTree, at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	await t.process_frame
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.position = at
		b.global_position = at
		root.push_input(b)
		await t.process_frame


func _drag(root: Window, t: SceneTree, from: Vector2, to: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = from
	mv.global_position = from
	root.push_input(mv)
	await t.process_frame
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = from
	b.global_position = from
	root.push_input(b)
	await t.process_frame
	for i in 10:
		var m := InputEventMouseMotion.new()
		m.position = from.lerp(to, (i + 1) / 10.0)
		m.global_position = m.position
		root.push_input(m)
		await t.process_frame
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = to
	u.global_position = to
	root.push_input(u)
	await t.process_frame
