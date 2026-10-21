extends SceneTree
## Tests the F4 perspective editor: godot --headless --path . -s tools/test_puppet_edit.gd


func _key(k: int, shift := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	e.shift_pressed = shift
	return e


func _init() -> void:
	var vp := SubViewport.new()  # (the headless root window is only 64 x 64)
	vp.size = Vector2i(1920, 1080)
	root.add_child(vp)
	await process_frame
	var S = load("res://scripts/ui/puppet_stage.gd")
	S.save_path = "user://puppet_stage_verts_test.json"
	DirAccess.remove_absolute(S.save_path)
	var st = S.new()
	vp.add_child(st)
	await process_frame
	var fails := 0
	var start: Dictionary = st.verts.duplicate()
	vp.push_input(_key(KEY_F4))
	await process_frame
	for n in S.EDIT_POINTS:
		var b: Button = st._edit_btns[n]
		if not b.visible:
			print("FAIL not visible ", n)
			fails += 1
		# a real click at the button's centre
		var c: Vector2 = b.global_position + b.size / 2.0
		for pressed in [true, false]:
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_LEFT
			m.pressed = pressed
			m.position = c
			m.global_position = c
			vp.push_input(m)
			await process_frame
		if st._edit_sel != n:
			print("FAIL click did not select ", n, " got ", st._edit_sel)
			fails += 1
			continue
		var tw: String = st._twin(n)
		var l0: Vector2 = st.verts[n]
		var r0: Vector2 = st.verts[tw]
		vp.push_input(_key(KEY_RIGHT))
		vp.push_input(_key(KEY_DOWN, true))
		await process_frame
		var ok: bool = st.verts[n] == l0 + Vector2(1, 10) and st.verts[tw] == r0 + Vector2(-1, 10)
		print("%s: %s -> %s | %s -> %s  %s" % [n, l0, st.verts[n], tw, st.verts[tw], "ok" if ok else "FAIL"])
		if not ok:
			fails += 1
	# shared points: moving back_bot_l moves the floor's and wall_left's corner (same dictionary entry)
	var shared := 0
	for q in st._quads:
		if "back_bot_l" in q.names and q.corners[q.names.find("back_bot_l")] == st.verts["back_bot_l"]:
			shared += 1
	print("quads sharing back_bot_l: ", shared)
	if shared != 3:
		fails += 1
	# what was moved is saved: a fresh stage (the game started again) has the moved points
	var moved: Dictionary = st.verts.duplicate()
	var st2 = S.new()
	if st2.verts != moved or moved == start:
		print("FAIL not persisted")
		fails += 1
	st2.free()
	vp.push_input(_key(KEY_R))
	await process_frame
	if st.verts != start:  # (R: back to the points as they were when F4 was turned on)
		print("FAIL reset")
		fails += 1
	vp.push_input(_key(KEY_F4))
	await process_frame
	if st._edit_btns["top_l"].visible:
		print("FAIL hide")
		fails += 1
	if FileAccess.file_exists(S.save_path):
		print("FAIL reset left the save file")
		fails += 1
	print("RESULT: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	quit(fails)
