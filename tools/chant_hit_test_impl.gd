extends RefCounted
## Which controls sit over each chant slot (a click on a slot that does nothing is a control in the way): godot --path . --position 6000,0 --no-focus -s tools/chant_hit_test.gd -- <enemy,ids>


func run(t: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array = Array((args[0] if args.size() > 0 else "invoker").split(","))
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://chant_hit_save.json")
	save.data.settings["theme"] = "puppet"
	var run := RunState.new()
	run.setup(root.get_node("GameData").db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var fs := FightScreen.new()
	fs.setup(run, run.make_fight(ids))
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	for k in 6:
		fs._add_stock_index(k)
		await t.create_timer(0.5).timeout
	await t.create_timer(1.0).timeout
	var slots := fs._chant_row.get_children()
	print("slots: ", slots.size(), " chant: ", fs.chant_idx)
	for i in mini(slots.size(), 6):
		var c: Control = slots[i]
		var at := c.get_global_rect().position + Vector2(26, 4)
		var over := []
		_collect(root, at, over)
		var names := []
		for n in over:
			names.append("%s(z%d)" % [str(n.get_path()).get_slice("/", -1) + ":" + n.get_class(), n.z_index])
		var extra := names.filter(func(n): return not (n.begins_with(":Control") or n.begins_with(":PanelContainer") or n.begins_with(":HBoxContainer") or n.begins_with(":Panel(")))
		print("slot ", i, " extra controls: ", extra, " all: ", names.size())
	# real clicks: press + release on each slot; the orb should leave the chant
	var c0: Control = fs._chant_row.get_child(0)
	var at0: Vector2 = t.root.get_final_transform() * c0.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = at0
	mv.global_position = at0
	t.root.push_input(mv)
	await t.process_frame
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = at0
	b.global_position = at0
	t.root.push_input(b)
	await t.process_frame
	print("after press: _press=", fs._press, " hovered=", t.root.gui_get_hovered_control())
	b = b.duplicate()
	b.pressed = false
	t.root.push_input(b)
	await t.process_frame
	print("after release: chant=", fs.chant_idx.size(), " _press=", fs._press)
	for i in 3:
		var before: int = fs.chant_idx.size()
		var c: Control = fs._chant_row.get_child(0)
		await _click(t.root, t, t.root.get_final_transform() * c.get_global_rect().get_center())
		await t.create_timer(0.8).timeout
		print("click on slot 0: chant ", before, " -> ", fs.chant_idx.size(), "  busy=", fs.busy, " phase=", fs.phase)
	t.quit()


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


func _collect(n: Node, at: Vector2, out: Array) -> void:
	if n is Control and n.is_visible_in_tree() and n.mouse_filter != Control.MOUSE_FILTER_IGNORE and n.get_global_rect().has_point(at):
		out.append(n)
	for ch in n.get_children():
		_collect(ch, at, out)
