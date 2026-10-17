extends RefCounted
## Drives the real Main scene: Room Test -> Fight Act 1 -> F5 -> rivets (click, drag, right click) -> Next set -> F5 again. Prints what it sees and
## saves pictures. The rope data goes to a throw-away file in user://, never to data/enemy_ropes.json.

func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://rope_shot_save.json")
	save.data.settings["theme"] = "puppet"
	EnemyRopes.file = "user://rope_shot_ropes.json"  # (never the real data)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EnemyRopes.file))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.0).timeout
	main.start_room_test()
	await t.create_timer(1.0).timeout
	main._enter_test_room({"type": "fight", "label": "Fight", "act": 1, "row": 5})
	await t.create_timer(1.5).timeout
	for kind in ["fight", "elite", "boss"]:
		for act in [1, 2, 3]:
			print("sets ", kind, " act ", act, ": ", RopeSets.build(kind, act))
	_key(root, KEY_F5)
	await t.create_timer(4.0).timeout
	var kids: Array = main.current.get_children()
	var rig_i := -1
	for k in kids.size():
		if kids[k] is RopeRig:
			rig_i = k
	print("ORDER rig ", rig_i, " enemy_row ", main.current._enemy_row.get_index(), " of ", kids.size())
	print("rope active: ", main._rope_active, " current ", main.current, " targets ", main.current.rope_targets().map(func(x): return x[0]))
	_shot(root, out + "/rope_1_set.png")
	# click on the first puppet's body: a rivet and a rope
	var targets: Array = main.current.rope_targets()
	var cr: Creature = targets[0][1]
	var at: Vector2 = cr.rope_point(Vector2(0.5, 0.45), true)
	await _click(root, t, at)
	var at2: Vector2 = targets[1][1].rope_point(Vector2(0.45, 0.4), true)
	await _click(root, t, at2)
	print("RIVETAT ", cr.rope_point(EnemyRopes.points(targets[0][0])[0]), " ", targets[1][1].rope_point(EnemyRopes.points(targets[1][0])[0]))
	print("rivets after 2 clicks: ", EnemyRopes.points(targets[0][0]), EnemyRopes.points(targets[1][0]))
	await t.create_timer(1.0).timeout
	_shot(root, out + "/rope_2_rivets.png")
	# drag the first rivet
	var from: Vector2 = cr.rope_point(EnemyRopes.points(targets[0][0])[0])
	await _drag(root, t, from, from + Vector2(40, -60))
	print("after drag: ", EnemyRopes.points(targets[0][0]))
	await t.create_timer(0.5).timeout
	_shot(root, out + "/rope_3_dragged.png")
	# right click the second rivet
	var rp: Vector2 = targets[1][1].rope_point(EnemyRopes.points(targets[1][0])[0])
	await _right_click(root, t, rp)
	print("after right click: ", EnemyRopes.points(targets[1][0]))
	# next set: a real click on the button
	var btn: Button = null
	for n in main.current.find_children("*", "Button", true, false):
		if n.text.begins_with("Next set"):
			btn = n
	var bc := btn.get_global_rect().get_center()
	await _move(root, t, bc)
	print("button at ", bc, " hovered: ", root.gui_get_hovered_control(), " rect ", btn.get_global_rect())
	await _click(root, t, bc)
	await t.create_timer(5.0).timeout
	print("set index ", main._rope_i, " targets ", main.current.rope_targets().map(func(x): return x[0]))
	_shot(root, out + "/rope_4_next.png")
	_key(root, KEY_F5)
	await t.create_timer(1.5).timeout
	print("after F5 again: rope active ", main._rope_active, " current ", main.current)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EnemyRopes.file))
	t.quit()


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)


func _key(root: Window, code: int) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	root.push_input(k)


func _mouse(root: Window, t: SceneTree, at: Vector2, button: int, down: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = button
	b.pressed = down
	b.position = at
	b.global_position = at
	root.push_input(b)
	await t.process_frame


func _move(root: Window, t: SceneTree, at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	await t.process_frame


func _click(root: Window, t: SceneTree, at: Vector2) -> void:
	await _move(root, t, at)
	await _mouse(root, t, at, MOUSE_BUTTON_LEFT, true)
	await _mouse(root, t, at, MOUSE_BUTTON_LEFT, false)


func _right_click(root: Window, t: SceneTree, at: Vector2) -> void:
	await _move(root, t, at)
	await _mouse(root, t, at, MOUSE_BUTTON_RIGHT, true)
	await _mouse(root, t, at, MOUSE_BUTTON_RIGHT, false)


func _drag(root: Window, t: SceneTree, from: Vector2, to: Vector2) -> void:
	await _move(root, t, from)
	await _mouse(root, t, from, MOUSE_BUTTON_LEFT, true)
	for k in 6:
		await _move(root, t, from.lerp(to, (k + 1) / 6.0))
	await _mouse(root, t, to, MOUSE_BUTTON_LEFT, false)
