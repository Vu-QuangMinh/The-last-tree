extends RefCounted


func _shot(t: SceneTree, out: String, name: String) -> void:
	await t.process_frame
	t.root.get_texture().get_image().save_png("%s/cart_%s.png" % [out, name])


var _sh: ShopScreen


func _find(n: Node) -> Node:
	if n is ShopScreen:
		return n
	for c in n.get_children():
		var r := _find(c)
		if r != null:
			return r
	return null


func _mouse(t: SceneTree, vp: Vector2, press := false) -> void:
	if _sh != null:
		_sh.test_mouse = vp
	var p: Vector2 = t.root.get_final_transform() * vp  # (viewport px -> window px)
	t.root.warp_mouse(p)
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	Input.parse_input_event(mv)
	await t.process_frame
	if press:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = p
		ev.global_position = p
		ev.pressed = true
		Input.parse_input_event(ev)
		await t.process_frame
		ev = ev.duplicate()
		ev.pressed = false
		Input.parse_input_event(ev)
		await t.process_frame


func _key(t: SceneTree, code: Key, ctrl := false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.ctrl_pressed = ctrl
		e.pressed = pressed
		Input.parse_input_event(e)
		await t.process_frame


func _wheel(t: SceneTree, vp: Vector2) -> void:
	var e := InputEventMouseButton.new()
	var p: Vector2 = t.root.get_final_transform() * vp
	e.position = p
	e.global_position = p
	e.button_index = MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	Input.parse_input_event(e)
	await t.process_frame


## screen point of a point of the cart picture (picture px)
func _at(sh: ShopScreen, p: Vector2) -> Vector2:
	return sh._cart_items.get_global_transform() * p


func run(t: SceneTree) -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	t.create_timer(170.0).timeout.connect(t.quit)
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://shop_stage_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	for _i in 60:
		await t.create_timer(0.25).timeout
		if m._overlay != null:
			break
	m._overlay.chosen.emit(0)
	await t.create_timer(4.6).timeout
	m.run.amber = 300
	var col: int = m.run.choices()[0]
	m.run.map[m.run.row + 1][col].type = "shop"
	m._overlay.node_chosen.emit(col)
	var sh: ShopScreen = null
	for _i in 40:
		await t.create_timer(0.1).timeout
		sh = _find(root) as ShopScreen
		if sh != null:
			break
	await t.create_timer(1.2).timeout
	_sh = sh
	print("shop found: ", sh != null, " true_cart ", sh._true_cart, " intro_done ", sh._intro_done, " boxes ", sh._boxes.size())
	await _shot(t, out, "00_rolling_in")
	await t.create_timer(8.5).timeout
	print("arrived ", sh._arrived)
	await _shot(t, out, "0_overview")
	# hover the cart
	await _mouse(t, _at(sh, Vector2(1300.0, 1300.0)))
	await t.create_timer(0.6).timeout
	await _shot(t, out, "1_hover")
	print("glow ", sh._cart.modulate, " mouse ", sh.get_global_mouse_position(), " want ", _at(sh, Vector2(1300.0, 1300.0)), " hot ", sh._cart_hot(sh.get_global_mouse_position()), " dlg ", sh._dlg, " busy ", sh._cam_busy)
	# click it: the camera zooms in
	await _mouse(t, _at(sh, Vector2(1300.0, 1300.0)), true)
	await t.create_timer(0.3).timeout
	await _shot(t, out, "2_mid")
	await t.create_timer(1.4).timeout
	print("view ", sh._view, " zoomed ", sh._zoomed)
	for b in sh._boxes:
		if is_instance_valid(b) and String(b.get_meta("kind", "")) in ["spell", "artifact"]:
			var bt: Control = b.get_meta("btn")
			var card: Control = b.get_child(1) if String(b.get_meta("kind")) == "spell" else b.get_child(0)
			print(b.get_meta("kind"), " box ", b.position, b.size, " child0 ", b.get_child(0).size, " card ", card.position, card.size, " btn ", bt.position, bt.size, " parent ", bt.get_parent().position, bt.get_parent().size)
	await _mouse(t, Vector2(900.0, 500.0))
	await t.create_timer(0.4).timeout
	await _shot(t, out, "3_zoomed")
	# F6: resize the artifacts (+10%), look, undo, leave the editor
	sh.edit_allowed = true
	await _key(t, KEY_F6)
	print("editing ", sh._c_editing)
	var art: Control = null
	for bx in sh._boxes:
		if is_instance_valid(bx) and String(bx.get_meta("kind", "")) == "artifact":
			art = bx
			break
	await _mouse(t, (art.get_meta("pic") as Control).get_global_rect().get_center(), true)
	print("selected ", sh._c_sel)
	for _i in 2:
		await _wheel(t, (art.get_meta("pic") as Control).get_global_rect().get_center())
	await t.create_timer(0.6).timeout
	print("artifact mult ", sh._mult["artifact"])
	await _shot(t, out, "3b_edit")
	for _i in 2:
		await _key(t, KEY_Z, true)
	await t.create_timer(0.5).timeout
	print("after undo ", sh._mult["artifact"])
	await _key(t, KEY_F6)
	print("editing ", sh._c_editing)
	# hover a bottle, an artifact, the soup, a card
	for k in [["bottle", Vector2(1017.0, 860.0)], ["artifact", Vector2(1403.0, 1130.0)], ["heal", Vector2(1647.0, 880.0)], ["card", Vector2(622.0, 946.0)], ["tag", Vector2(430.0, 900.0)]]:
		await _mouse(t, _at(sh, k[1]))
		await t.create_timer(0.7).timeout
		await _shot(t, out, "4_hover_" + k[0])
	# a click on a bottle only shows its board; the green price box buys
	var amber0: int = m.run.amber
	await _mouse(t, _at(sh, Vector2(1017.0, 860.0)), true)
	await t.create_timer(0.5).timeout
	print("after click on item: amber ", amber0, " -> ", m.run.amber, " (must be equal)")
	var bottle: Control = null
	for bx in sh._boxes:
		if is_instance_valid(bx) and String(bx.get_meta("kind", "")) == "bottle":
			bottle = bx
			break
	var tagc: Vector2 = (bottle.get_meta("btn") as Control).get_global_rect().get_center()
	await _mouse(t, tagc, true)
	await t.create_timer(0.8).timeout
	print("after click on the green box: amber ", amber0, " -> ", m.run.amber)
	await _mouse(t, Vector2(900.0, 500.0))
	await t.create_timer(0.5).timeout
	await _shot(t, out, "5_after_buy")
	# Back
	await _mouse(t, sh._back_btn.get_global_rect().get_center(), true)
	await t.create_timer(1.6).timeout
	print("view ", sh._view, " zoomed ", sh._zoomed, " stage scale ", sh._stage.scale)
	await _shot(t, out, "6_back")
	t.quit()
