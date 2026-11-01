extends RefCounted
## The F6 layout editor of the test room: select, move, arrows, scale, +/-, undo (real main flow, off-screen).
func _key(code: int, ctrl := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	k.ctrl_pressed = ctrl
	return k


func _click(es: EventStage, at: Vector2, down: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = down
	b.position = at
	es._gui_input(b)


func _move(es: EventStage, at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	es._gui_input(m)


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://event_edit_test.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_event("well")
	await t.create_timer(3.0).timeout
	var es: EventStage = main._overlay as EventStage
	es._input(_key(KEY_F6))
	var n: TextureRect = es._props[0].node
	var p0 := n.position
	var c := p0 + n.size / 2.0
	_click(es, c, true)
	_move(es, c + Vector2(50, 20))
	_click(es, c + Vector2(50, 20), false)
	print("moved: ", n.position - p0, " sel ", es._sel, " rot ", n.rotation)
	es._input(_key(KEY_RIGHT))
	print("arrow: ", n.position - p0)
	var s0 := n.size
	es._input(_key(KEY_EQUAL))
	print("plus ratio: ", n.size / s0, " size ", n.size)
	var corner := n.position + n.size
	_click(es, corner, true)
	_move(es, n.position + n.size / 2.0 + (corner - (n.position + n.size / 2.0)) * 1.5)
	_click(es, corner, false)
	print("corner scale ratio: ", n.size.x / n.size.y, " vs ", s0.x / s0.y, " size ", n.size)
	for i in 4:
		es._input(_key(KEY_Z, true))
	print("after undo: ", n.position - p0, " ", n.size / s0)
	root.get_texture().get_image().save_png(OS.get_environment("EDIT_OUT") + "/edit.png")
	es._input(_key(KEY_F6))
	print("EDIT DONE")
	t.quit()
