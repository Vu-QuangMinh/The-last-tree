extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://rearrange_flow.json")
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["ashling", "iceling"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	var a: EnemyState = f.enemies[0]
	var b: EnemyState = f.enemies[1]
	print("BEFORE ", a.hp_text(), " | ", b.hp_text())
	var res := [null]
	(func():
		res[0] = await fs._mover(gd.db.get_spell("updraft"), null)).call()
	await t.create_timer(0.6).timeout
	var drags := fs.get_children().filter(func(c): return c is ChantDrag)
	print("ROWS LIVE ", drags.size())
	var d0: ChantDrag = drags[0]
	var d1: ChantDrag = drags[1]
	var from := d0.global_position + Vector2(d0.px / 2.0, 8.0 + d0.px / 2.0)
	var to := d1.global_position + Vector2(d1.px * 0.2, 8.0 + d1.px / 2.0)  # (just before its first Essence)
	_mouse(root, from, true, true)
	for k in 13:
		await t.process_frame
		await t.create_timer(0.05).timeout
		_move(root, from.lerp(to, k / 12.0))
		if k == 9:
			root.get_texture().get_image().save_png("%s/carry.png" % out)
	await t.create_timer(0.3).timeout
	root.get_texture().get_image().save_png("%s/over.png" % out)
	_mouse(root, to, false, false)
	await t.create_timer(0.8).timeout
	print("RESULT ", res[0])
	await t.create_timer(0.3).timeout
	t.quit()


func _mouse(root: Window, p: Vector2, pressed: bool, _down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	root.push_input(ev)


func _move(root: Window, p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(ev)
