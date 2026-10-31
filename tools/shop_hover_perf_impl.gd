extends RefCounted


func _frames(t: SceneTree, secs: float) -> String:
	var n := 0
	var worst := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	while (Time.get_ticks_usec() - t0) < secs * 1e6:
		await t.process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		n += 1
	return "%d frames, avg %.1f ms, worst %.1f ms" % [n, secs * 1000.0 / n, worst]


func _cards(n: Node, out: Array) -> void:
	if n is SpellCard:
		out.append(n)
	for c in n.get_children():
		_cards(c, out)


func run(t: SceneTree) -> void:
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
	await t.create_timer(24.0).timeout
	var cards: Array = []
	_cards(m._overlay, cards)
	print("cards: ", cards.size())
	print("idle: ", await _frames(t, 2.0))
	for c in cards:
		var t0 := Time.get_ticks_usec()
		c._on_hover(true)
		print("hover call: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
		print("hovered: ", await _frames(t, 1.5))
		c._hover = true
		c.drop_zoom()
	t.quit()
