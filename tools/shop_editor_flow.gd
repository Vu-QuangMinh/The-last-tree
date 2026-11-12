extends SceneTree
## Test mode > Events > The Merchant, then the F6 shelf editor driven with real input events: select + drag the shelf, resize it, select an artifact slot, drag it, resize all artifacts, undo, save.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_editor_flow.gd -- <out folder>   (it deletes data/shop_layout_overrides.json at the end: that file is the user's)


func _init() -> void:
	await process_frame
	create_timer(90.0).timeout.connect(quit)
	var win: Window = root_window()
	var out: String = OS.get_cmdline_user_args()[0]
	var save = win.get_node("SaveManager")
	save.use_test_file("user://shop_editor_flow.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	win.add_child(main)
	await create_timer(1.5).timeout
	main._test_event("merchant")
	await create_timer(11.0).timeout
	var sh = main._overlay
	print("edit_allowed: ", sh.edit_allowed)
	_key(win, KEY_F6)
	await process_frame
	print("editing: ", sh._editing)
	var shelf_c: Vector2 = sh._shelf.get_global_rect().get_center() + Vector2(0, -150)  # (the gap between the planks' backs: empty shelf area)
	var w0: float = sh._shelf_w()
	var cx0: float = sh._shelf_cx()
	await _click_drag(win, shelf_c, Vector2(60, -10))
	print("shelf selected: ", sh._sel, " cx ", cx0, " -> ", sh._shelf_cx())
	for i in 5:
		_wheel(win, shelf_c, true)
		await process_frame
	print("shelf width ", w0, " -> ", sh._shelf_w())
	win.get_texture().get_image().save_png(out + "/editor_1.png")
	var slots: Array = sh._edit_slots()
	var a0: Control = null
	for d in slots:
		if String(d["id"]) == "art:0":
			a0 = d["box"]
	var ap: Vector2 = a0.get_global_rect().get_center() + Vector2(0, -20)
	var s0: Array = (sh._lay["art"]["slots"] as Array)[0].duplicate()
	await _click_drag(win, ap, Vector2(0, -50))
	print("slot selected: ", sh._sel, " art slot0 ", s0, " -> ", sh._lay["art"]["slots"][0])
	var px0: float = float(sh._lay["art"]["px"])
	for i in 5:
		_wheel(win, ap, true)
		await process_frame
	await create_timer(0.8).timeout
	print("art px ", px0, " -> ", sh._lay["art"]["px"], "  boxes: ", sh._boxes.size())
	win.get_texture().get_image().save_png(out + "/editor_2.png")
	_key(win, KEY_Z, true)
	await create_timer(0.8).timeout
	print("after undo art px ", sh._lay["art"]["px"])
	var amber: int = main.run.amber
	_key(win, KEY_F6)
	await process_frame
	print("saved: ", FileAccess.file_exists("res://data/shop_layout_overrides.json"), " editing ", sh._editing, " amber ", amber, " -> ", main.run.amber)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://data/shop_layout_overrides.json"))
	quit()


func root_window() -> Window:
	return root


func _key(_w: Window, code: Key, ctrl := false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.ctrl_pressed = ctrl
		e.pressed = pressed
		Input.parse_input_event(e)


func _move(w: Window, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	var wp: Vector2 = w.get_final_transform() * p  # (events come in window pixels: the stretch turns them into the game's own)
	e.position = wp
	e.global_position = wp
	Input.parse_input_event(e)


func _btn(w: Window, p: Vector2, idx: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	var wp: Vector2 = w.get_final_transform() * p  # (events come in window pixels: the stretch turns them into the game's own)
	e.position = wp
	e.global_position = wp
	e.button_index = idx
	e.pressed = pressed
	Input.parse_input_event(e)


func _wheel(w: Window, p: Vector2, up: bool) -> void:
	_move(w, p)
	_btn(w, p, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, true)
	_btn(w, p, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, false)


func _click_drag(w: Window, p: Vector2, d: Vector2) -> void:
	_move(w, p)
	await process_frame
	_btn(w, p, MOUSE_BUTTON_LEFT, true)
	await process_frame
	for i in 6:
		_move(w, p + d * (float(i + 1) / 6.0))
		await process_frame
	_btn(w, p + d, MOUSE_BUTTON_LEFT, false)
	await process_frame
