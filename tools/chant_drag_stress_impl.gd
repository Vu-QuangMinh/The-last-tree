extends RefCounted

var t: SceneTree
var fs: FightScreen
var fails := 0
var notes: Array = []


func _to_win(p: Vector2) -> Vector2:
	return t.root.get_final_transform() * p


func _motion(p: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = _to_win(p)
	mv.global_position = mv.position
	t.root.push_input(mv)
	await t.process_frame


func _button(p: Vector2, down: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = down
	b.position = _to_win(p)
	b.global_position = b.position
	t.root.push_input(b)
	await t.process_frame


func _drag(a: Vector2, b: Vector2, steps: int) -> void:
	await _motion(a)
	await _button(a, true)
	for k in steps:
		await _motion(a.lerp(b, (k + 1.0) / steps))
	await _button(b, false)


func _slot_center(k: int) -> Vector2:
	var slots: Array = fs._chant_row.get_children().filter(func(c): return c is Panel)
	return slots[k].get_global_rect().get_center()


func _fill(n: int, wait: float) -> void:
	fs.chant_idx.clear()
	fs._chant_changed()
	await t.create_timer(1.0).timeout
	for i in n:
		fs._add_stock_index(i)
		await t.create_timer(wait).timeout
	await t.create_timer(0.8).timeout


func _expect(label: String, want: int) -> void:
	await t.create_timer(0.9).timeout
	if fs.chant_idx.size() != want:
		fails += 1
		notes.append("%s: chant has %d, expected %d" % [label, fs.chant_idx.size(), want])


func run(p_t: SceneTree) -> void:
	t = p_t
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://chant_drag_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 5)
	var f := r.make_fight(["greenseer"])
	fs = FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	root.add_child(fs)
	await t.create_timer(7.0).timeout
	for k in 5:
		fs.fight.player.add_element(["F", "W", "A"][k % 3])
	fs._refresh_all()
	await t.create_timer(6.0).timeout
	var strip_top: float = PuppetLayout.BAG_AT.y
	await _fill(2, 0.2)
	print("chant row ", fs._chant_row.get_global_rect(), " slot0 ", _slot_center(0), " px ", fs._chant_px())
	print("bag strip top y ", strip_top, "  balls ", fs.fight.player.stock.size())
	# release heights between the chant and the Bag, on the first / last ball, slow and fast
	for y in [940.0, 960.0, 975.0, 990.0, 1010.0, 1040.0]:
		for which in ["first", "last", "middle"]:
			await _fill(4, 0.3)
			var k := 0 if which == "first" else (3 if which == "last" else 1)
			var c := _slot_center(k)
			await _drag(c, Vector2(c.x, y), 10)
			await _expect("release at y=%d, %s ball, slow" % [y, which], 4 if y < 950.0 else 3)
			await _fill(4, 0.3)
			c = _slot_center(k)
			await _drag(c, Vector2(c.x, y), 2)
			await _expect("release at y=%d, %s ball, fast (2 moves)" % [y, which], 4 if y < 950.0 else 3)
	# a ball that has only just been clicked in (still flying in)
	await _fill(0, 0.0)
	fs._add_stock_index(0)
	await t.create_timer(0.12).timeout
	var c2 := _slot_center(0)
	await _drag(c2, Vector2(c2.x, 1010.0), 6)
	await _expect("dragged while it is still flying in", 0)
	# ten balls in the chant, take the last / first down
	await _fill(10, 0.15)
	var c3 := _slot_center(9)
	await _drag(c3, Vector2(c3.x, 1010.0), 8)
	await _expect("ten balls, last one down", 9)
	c3 = _slot_center(0)
	await _drag(c3, Vector2(c3.x, 1010.0), 8)
	await _expect("ten balls, first one down", 8)
	# drag sideways and drop inside: it rearranges; drag down diagonally
	await _fill(4, 0.3)
	var c4 := _slot_center(0)
	await _drag(c4, _slot_center(3), 8)
	await _expect("rearranged inside", 4)
	c4 = _slot_center(1)
	await _drag(c4, c4 + Vector2(300, 140), 8)
	await _expect("diagonal down to the right", 3)
	print("RESULT: ", fails, " failed")
	for n in notes:
		print("  ", n)
	t.quit()
